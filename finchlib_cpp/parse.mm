/*
Copyright (c) 2015 Kristopher Johnson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include "parse.h"
#include "syntax.h"

using std::function;
using std::get;
using std::pair;
using std::tuple;
using std::shared_ptr;
using std::string;
using std::vector;

namespace finchlib_cpp
{

static Parse<Expression> expression(const InputPos &pos);

/// Determine whether the remainder of the line starts with a specified sequence
/// of characters.
///
/// If true, returns position of the character following the matched string. If
/// false, returns nil.
///
/// Matching is case-insensitive. Spaces in the input are ignored.
Parse<string> literal(string s, const InputPos &pos)
{
    size_t matchCount{0};
    const size_t matchGoal{s.length()};

    auto i = pos;
    while ((matchCount < matchGoal) && !i.isAtEndOfLine())
    {
        auto c = i.at();
        i = i.next();

        if (c == ' ')
        {
            continue;
        }
        else if (std::toupper(c) == std::toupper(s[matchCount]))
        {
            ++matchCount;
        }
        else
        {
            return failedParse<string>();
        }
    }

    if (matchCount == matchGoal)
    {
        return successfulParse(s, i);
    }

    return failedParse<string>();
}

/// Callable object that tries to parse a literal
class lit
{
private:
    string s;

public:
    lit(string literalString) : s{literalString} {}

    Parse<string> operator()(const InputPos &pos) { return literal(s, pos); }
};

/// Try to parse one of a set of literals
///
/// Returns first match, or nil if there are no matches
static Parse<string> oneOfLiteral(vector<string> strings, const InputPos &pos)
{
    for (auto s : strings)
    {
        const auto match = literal(s, pos);
        if (match.wasParsed())
        {
            return match;
        }
    }

    return failedParse<string>();
}

/// Callable object that tries to parse one of a set of literals
class oneOfLit
{
private:
    vector<string> strings;

public:
    oneOfLit(std::initializer_list<string> initList) : strings(initList) {}

    Parse<string> operator()(const InputPos &pos)
    {
        return oneOfLiteral(strings, pos);
    }
};

/// Check for a literal at the specified position.
///
/// If the literal is present, then return it and the following position.
///
/// If the literal is not present, then just return it and the original
/// position.
///
/// This is used in situations where a statement allows an optional keyword,
/// such as LET or THEN, that can be ignored if present.
static Parse<string> optLiteral(string s, const InputPos &pos)
{
    const auto lit = literal(s, pos);
    if (lit.wasParsed())
    {
        return successfulParse(s, lit.nextPos());
    }

    return successfulParse(s, pos);
}

/// Callable object that tries to parse an optional literal
class optLit
{
private:
    string s;

public:
    optLit(string literal) : s(literal) {}

    Parse<string> operator()(const InputPos &pos) { return optLiteral(s, pos); }
};

/// Attempt to read an unsigned number from input.  If successful, returns
/// parsed number and position of next input character.  If not, returns nil.
Parse<Number> numberLiteral(const InputPos &pos)
{
    auto i = pos.afterSpaces();

    if (i.isAtEndOfLine())
    {
        return failedParse<Number>();
    }

    if (!isDigitChar(i.at()))
    {
        return failedParse<Number>();
    }

    Number num{i.at() - '0'};
    i = i.next();
    while (!i.isAtEndOfLine())
    {
        const auto c = i.at();
        if (isDigitChar(c))
        {
            num = (num * 10) + (c - '0');
        }
        else if (c != ' ')
        {
            break;
        }
        i = i.next();
    }

    return successfulParse(num, i);
}

/// Attempt to parse a string literal
///
/// Returns characters and position of next character if successful.
/// Returns nil otherwise.
Parse<vector<Char>> stringLiteral(const InputPos &pos)
{
    auto i = pos.afterSpaces();
    if (!i.isAtEndOfLine())
    {
        if (i.at() == '"')
        {
            i = i.next();
            vector<Char> stringChars;
            bool foundTrailingDelim{false};

            while (!i.isAtEndOfLine())
            {
                const auto c = i.at();
                i = i.next();
                if (c == '"')
                {
                    foundTrailingDelim = true;
                    break;
                }
                else
                {
                    stringChars.push_back(c);
                }
            }

            if (foundTrailingDelim)
            {
                return successfulParse(stringChars, i);
            }
        }
    }
    return failedParse<vector<Char>>();
}

/// Attempt to read a variable name.
///
/// Returns variable name and position of next input character on success, or
/// nil otherwise.
static Parse<VariableName> variableName(const InputPos &pos)
{
    const auto i = pos.afterSpaces();
    if (!i.isAtEndOfLine())
    {
        const auto c = i.at();
        if (std::isalpha(c))
        {
            const auto result = VariableName(std::toupper(c));
            return successfulParse(result, i.next());
        }
    }

    return failedParse<VariableName>();
}

/// Attempt to parse an Lvalue (variable name or array element reference)
///
/// Returns Lvalue and position of next input character on success, or nil
/// otherwise.
static Parse<Lvalue> lvalue(const InputPos &pos)
{
    const auto v = variableName(pos);
    if (v.wasParsed())
    {
        const auto result = Lvalue::var(v.value());
        return successfulParse(result, v.nextPos());
    }

    const auto aelem = pos.parse<string, Expression, string>(lit("@("), expression, lit(")"));
    if (aelem != nullptr)
    {
        const auto &expr = get<1>(*aelem);
        const auto &nextPos = get<3>(*aelem);
        const auto result = Lvalue::arrayElement(expr);
        return successfulParse(result, nextPos);
    }

    return failedParse<Lvalue>();
}

/// Attempt to parse a Factor.  Returns Factor and position of next character if
/// successful.  Returns nil if not.
static Parse<Factor> factor(const InputPos &pos)
{
    // number
    const auto num = numberLiteral(pos);
    if (num.wasParsed())
    {
        const auto result = Factor::number(num.value());
        return successfulParse(result, num.nextPos());
    }

    // "RND(" expression ")"
    const auto rnd = pos.parse<string, Expression, string>(lit("RND("), expression, lit(")"));
    if (rnd != nullptr)
    {
        const auto &expr = get<1>(*rnd);
        const auto &nextPos = get<3>(*rnd);
        const auto result = Factor::rnd(expr);
        return successfulParse(result, nextPos);
    }

    // "(" expression ")"
    const auto parenExpr = pos.parse<string, Expression, string>(lit("("), expression, lit(")"));
    if (parenExpr != nullptr)
    {
        const auto &expr = get<1>(*parenExpr);
        const auto &nextPos = get<3>(*parenExpr);
        const auto result = Factor::parenExpr(expr);
        return successfulParse(result, nextPos);
    }

    // "@(" expression ")"
    const auto aelem = pos.parse<string, Expression, string>(lit("@("), expression, lit(")"));
    if (aelem != nullptr)
    {
        const auto &expr = get<1>(*aelem);
        const auto &nextPos = get<3>(*aelem);
        const auto result = Factor::arrayElement(expr);
        return successfulParse(result, nextPos);
    }

    // variable
    const auto v = variableName(pos);
    if (v.wasParsed())
    {
        const auto result = Factor::var(v.value());
        return successfulParse(result, v.nextPos());
    }

    return failedParse<Factor>();
}

/// Attempt to parse a Term.
///
/// Returns Term and position of next character if successful.  Returns nil if
/// not.
static Parse<Term> term(const InputPos &pos)
{
    const auto fact = factor(pos);
    if (fact.wasParsed())
    {
        // If followed by "*", then it's a product
        const auto mult = fact.nextPos().parse<string, Term>(lit("*"), term);
        if (mult != nullptr)
        {
            const Term &t = get<1>(*mult);
            const InputPos &nextPos = get<2>(*mult);
            const auto result = Term::compound(fact.value(), ArithOp::Multiply, t);
            return successfulParse(result, nextPos);
        }

        // If followed by "/", then it's a quotient
        const auto div = fact.nextPos().parse<string, Term>(lit("/"), term);
        if (div != nullptr)
        {
            const Term &t = get<1>(*div);
            const InputPos &nextPos = get<2>(*div);
            const auto result = Term::compound(fact.value(), ArithOp::Divide, t);
            return successfulParse(result, nextPos);
        }

        const auto result = Term::factor(fact.value());
        return successfulParse(result, fact.nextPos());
    }

    return failedParse<Term>();
}

/// Attempt to parse an UnsignedExpression.
///
/// Returns UnsignedExpression and position of next character if successful.
/// Returns nil if not.
static Parse<UnsignedExpression> unsignedExpression(const InputPos &pos)
{
    const auto t = term(pos);
    if (t.wasParsed())
    {
        // If followed by "+", then it's addition
        const auto add = t.nextPos().parse<string, UnsignedExpression>(
            lit("+"), unsignedExpression);
        if (add != nullptr)
        {
            const auto &uexpr = get<1>(*add);
            const auto &nextPos = get<2>(*add);
            const auto result = UnsignedExpression::compound(t.value(), ArithOp::Add, uexpr);
            return successfulParse(result, nextPos);
        }

        // If followed by "+", then it's addition
        const auto sub = t.nextPos().parse<string, UnsignedExpression>(
            lit("-"), unsignedExpression);
        if (sub != nullptr)
        {
            const auto &uexpr = get<1>(*sub);
            const auto &nextPos = get<2>(*sub);
            const auto result = UnsignedExpression::compound(t.value(), ArithOp::Subtract, uexpr);
            return successfulParse(result, nextPos);
        }

        // Otherwise, just a simple term
        const auto result = UnsignedExpression::term(t.value());
        return successfulParse(result, t.nextPos());
    }

    return failedParse<UnsignedExpression>();
}

/// Attempt to parse an Expression.
///
/// Returns Expression and position of next character if successful.  Returns
/// nil if not.
static Parse<Expression> expression(const InputPos &pos)
{
    const auto leadingPlus = pos.parse<string, UnsignedExpression>(lit("+"), unsignedExpression);
    if (leadingPlus != nullptr)
    {
        const auto &uexpr = get<1>(*leadingPlus);
        const auto &nextPos = get<2>(*leadingPlus);
        const auto result = Expression::plus(uexpr);
        return successfulParse(result, nextPos);
    }

    const auto leadingMinus = pos.parse<string, UnsignedExpression>(lit("-"), unsignedExpression);
    if (leadingMinus != nullptr)
    {
        const auto &uexpr = get<1>(*leadingMinus);
        const auto &nextPos = get<2>(*leadingMinus);
        const auto result = Expression::minus(uexpr);
        return successfulParse(result, nextPos);
    }

    const auto uexpr = unsignedExpression(pos);
    if (uexpr.wasParsed())
    {
        const auto result = Expression::unsignedExpr(uexpr.value());
        return successfulParse(result, uexpr.nextPos());
    }

    return failedParse<Expression>();
}

/// Attempt to parse a PrintItem.
///
/// Returns PrintItem and position of next character if successful.  Returns nil
/// otherwise.
static Parse<PrintItem> printItem(const InputPos &pos)
{
    const auto s = stringLiteral(pos);
    if (s.wasParsed())
    {
        const auto item = PrintItem::stringLiteral(s.value());
        return successfulParse(item, s.nextPos());
    }

    const auto expr = expression(pos);
    if (expr.wasParsed())
    {
        const auto result = PrintItem::expression(expr.value());
        return successfulParse(result, expr.nextPos());
    }

    return failedParse<PrintItem>();
}

/// Attempt to parse a PrintList.
///
/// Returns PrintList and position of next character if successful.  Returns nil
/// otherwise.
static Parse<PrintList> printList(const InputPos &pos)
{
    const auto item = printItem(pos);
    if (item.wasParsed())
    {
        const auto comma = literal(",", item.nextPos());
        if (comma.wasParsed())
        {
            // "," printList
            // "," (trailing at end of line)

            const auto tail = printList(comma.nextPos());
            if (tail.wasParsed())
            {
                const auto pTail = shared_ptr<PrintList>(new PrintList(tail.value()));
                PrintList result{item.value(), PrintSeparatorTab, pTail};
                return successfulParse(result, tail.nextPos());
            }
            else if (comma.nextPos().isRemainingLineEmpty())
            {
                PrintList result{item.value(), PrintSeparatorTab, nullptr};
                return successfulParse(result, comma.nextPos());
            }
        }
        else
        {
            const auto semicolon = literal(";", item.nextPos());
            if (semicolon.wasParsed())
            {
                // ";" printList
                // ";" (trailing at end of line)

                const auto tail = printList(semicolon.nextPos());
                if (tail.wasParsed())
                {
                    const auto pTail = shared_ptr<PrintList>(new PrintList(tail.value()));
                    PrintList result{item.value(), PrintSeparatorEmpty, pTail};
                    return successfulParse(result, tail.nextPos());
                }
                else if (semicolon.nextPos().isRemainingLineEmpty())
                {
                    PrintList result{item.value(), PrintSeparatorEmpty, nullptr};
                    return successfulParse(result, semicolon.nextPos());
                }
            }
        }

        PrintList result{item.value(), PrintSeparatorNewline, nullptr};
        return successfulParse(result, item.nextPos());
    }

    return failedParse<PrintList>();
}

/// Attempt to parse a relational operator
static Parse<RelOp> relOp(const InputPos &pos)
{
    // Note: We need to test the longer sequences before the shorter
    static const vector<tuple<string, RelOp>> opTable = {
        {"<=", RelOp::LessOrEqual},
        {">=", RelOp::GreaterOrEqual},
        {"<>", RelOp::NotEqual},
        {"><", RelOp::NotEqual},
        {"=", RelOp::Equal},
        {"<", RelOp::Less},
        {">", RelOp::Greater}};

    for (const auto &item : opTable)
    {
        const auto op = literal(get<0>(item), pos);
        if (op.wasParsed())
        {
            return successfulParse(get<1>(item), op.nextPos());
        }
    }

    return failedParse<RelOp>();
}

/// Attempt to parse a PRINT statement.
///
/// Returns statement and position of next character if successful.  Returns nil
/// otherwise.
static Parse<Statement> printStatement(const InputPos &pos)
{
    // "PRINT" printList
    // "PR" printList
    // "?" printList
    const auto keyword = oneOfLit{"PRINT", "PR", "?"}(pos);
    if (keyword.wasParsed())
    {
        const auto plist = printList(keyword.nextPos());
        if (plist.wasParsed())
        {
            const auto stmt = Statement::print(plist.value());
            return successfulParse(stmt, plist.nextPos());
        }
        else
        {
            const auto stmt = Statement::printNewline();
            return successfulParse(stmt, keyword.nextPos());
        }
    }

    return failedParse<Statement>();
}

/// Attempt to parse a LIST statement.
///
/// Returns statement and position of next character if successful.  Returns nil
/// otherwise.
static Parse<Statement> listStatement(const InputPos &pos)
{
    // "LIST" [expression ["," expression]]
    // "LS" [expression ["," expression]]
    const auto keyword = oneOfLiteral({"LIST", "LS"}, pos);
    if (keyword.wasParsed())
    {
        const auto lowExpr = expression(keyword.nextPos());
        if (lowExpr.wasParsed())
        {
            const auto commaExpr = lowExpr.nextPos().parse<string, Expression>(lit(","), expression);
            if (commaExpr != nullptr)
            {
                const auto &highExpr = get<1>(*commaExpr);
                const auto &nextPos = get<2>(*commaExpr);
                const auto stmt = Statement::list(lowExpr.value(), highExpr);
                return successfulParse(stmt, nextPos);
            }
            const auto stmt = Statement::list(lowExpr.value());
            return successfulParse(stmt, lowExpr.nextPos());
        }

        const auto stmt = Statement::list();
        return successfulParse(stmt, keyword.nextPos());
    }

    return failedParse<Statement>();
}

/// Attempt to parse a LET statement.
///
/// Returns statement and position of next character if successful.
static Parse<Statement> letStatement(const InputPos &pos)
{
    const auto let = pos.parse<string, Lvalue, string, Expression>(
        optLit("LET"), lvalue, lit("="), expression);
    if (let != nullptr)
    {
        const auto &lv = get<1>(*let);
        const auto &expr = get<3>(*let);
        const auto &nextPos = get<4>(*let);
        const auto stmt = Statement::let(lv, expr);
        return successfulParse(stmt, nextPos);
    }

    return failedParse<Statement>();
}

static Parse<Lvalues> lvalueList(const InputPos &pos)
{
    const auto firstItem = lvalue(pos);
    if (firstItem.wasParsed())
    {
        Lvalues lvalues{firstItem.value()};
        auto nextPos = firstItem.nextPos();

        auto more = nextPos.parse<string, Lvalue>(lit(","), lvalue);
        while (more != nullptr)
        {
            lvalues.push_back(get<1>(*more));
            nextPos = get<2>(*more);
            more = nextPos.parse<string, Lvalue>(lit(","), lvalue);
        }

        return successfulParse(lvalues, nextPos);
    }

    return failedParse<Lvalues>();
}

/// Attempt to parse an INPUT statement
///
/// Returns statement and position of next character if successful.
static Parse<Statement> inputStatement(const InputPos &pos)
{
    const auto parsed = pos.parse<string, Lvalues>(oneOfLit{"INPUT", "IN"}, lvalueList);
    if (parsed != nullptr)
    {
        const auto &lvalues = get<1>(*parsed);
        const auto &nextPos = get<2>(*parsed);
        const auto result = Statement::input(lvalues);
        return successfulParse(result, nextPos);
    }

    return failedParse<Statement>();
}

/// Attempt to parse an IF statement
///
/// Returns statement and position of next character if successful.
static Parse<Statement> ifStatement(const InputPos &pos)
{
    const auto ifThen = pos.parse<string, Expression, RelOp, Expression, string, Statement>(
        lit("IF"), expression, relOp, expression, optLit("THEN"), statement);
    if (ifThen != nullptr)
    {
        const auto &lhs = get<1>(*ifThen);
        const auto &op = get<2>(*ifThen);
        const auto &rhs = get<3>(*ifThen);
        const auto &stmt = get<5>(*ifThen);
        const auto &nextPos = get<6>(*ifThen);
        const auto result = Statement::ifThen(lhs, op, rhs, stmt);
        return successfulParse(result, nextPos);
    }

    return failedParse<Statement>();
}

/// Attempt to parse a GOTO statement
///
/// Returns statement and position of next character if successful.
static Parse<Statement> gotoStatement(const InputPos &pos)
{
    const auto s = pos.parse<string, Expression>(oneOfLit{"GOTO", "GT"}, expression);
    if (s != nullptr)
    {
        const auto &expr = get<1>(*s);
        const auto &nextPos = get<2>(*s);
        const auto result = Statement::gotoStatement(expr);
        return successfulParse(result, nextPos);
    }

    return failedParse<Statement>();
}

/// Attempt to parse a GOSUB statement
///
/// Returns statement and position of next character if successful.
static Parse<Statement> gosubStatement(const InputPos &pos)
{
    const auto s = pos.parse<string, Expression>(oneOfLit{"GOSUB", "GS"}, expression);
    if (s != nullptr)
    {
        const auto &expr = get<1>(*s);
        const auto &nextPos = get<2>(*s);
        const auto result = Statement::gosub(expr);
        return successfulParse(result, nextPos);
    }

    return failedParse<Statement>();
}

/// Attempt to parse a REM statement
///
/// Returns statement and position of next character if successful.
static Parse<Statement> remStatement(const InputPos &pos)
{
    const auto rem = oneOfLiteral({"REM", "'"}, pos);
    if (rem.wasParsed())
    {
        const auto commentChars = rem.nextPos().remainingChars();
        string commentString{};
        for (auto c : commentChars)
        {
            commentString.push_back(c);
        }
        const auto result = Statement::rem(commentString);
        return successfulParse(result, pos.endOfLine());
    }

    return failedParse<Statement>();
}

/// Attempt to parse a DIM statement
///
/// Returns statement and position of next character if successful.
static Parse<Statement> dimStatement(const InputPos &pos)
{
    const auto parsed = pos.parse<string, Expression, string>(lit("DIM@("), expression, lit(")"));
    if (parsed != nullptr)
    {
        const auto result = Statement::dim(get<1>(*parsed));
        const auto &nextPos = get<3>(*parsed);
        return successfulParse(result, nextPos);
    }

    return failedParse<Statement>();
}

/// Attempt to parse a SAVE statement
///
/// Return statement and position of next character if successful.
static Parse<Statement> saveStatement(const InputPos &pos)
{
    const auto parsed = pos.parse<string, vector<Char>>(oneOfLit{"SAVE", "SV"}, stringLiteral);
    if (parsed != nullptr)
    {
        const auto &chars = get<1>(*parsed);
        const auto &nextPos = get<2>(*parsed);
        const string filename{chars.cbegin(), chars.cend()};
        const auto result = Statement::save(filename);
        return successfulParse(result, nextPos);
    }

    return failedParse<Statement>();
}

/// Attempt to parse a LOAD statement
///
/// Return statement and position of next character if successful.
static Parse<Statement> loadStatement(const InputPos &pos)
{
    const auto parsed = pos.parse<string, vector<Char>>(oneOfLit{"LOAD", "LD"}, stringLiteral);
    if (parsed != nullptr)
    {
        const auto &chars = get<1>(*parsed);
        const auto &nextPos = get<2>(*parsed);
        const string filename{chars.cbegin(), chars.cend()};
        const auto result = Statement::load(filename);
        return successfulParse(result, nextPos);
    }

    return failedParse<Statement>();
}

/// Parse a statement
///
/// Returns a parsed statement and position of character
/// following the end of the parsed statement, or nil
/// if there is no valid statement.
Parse<Statement> statement(const InputPos &pos)
{
    // List of parsing functions to try
    static const vector<function<Parse<Statement>(const InputPos &pos)>>
    functions{printStatement, letStatement, inputStatement, dimStatement,
              ifStatement, gotoStatement, gosubStatement, remStatement,
              listStatement, saveStatement, loadStatement};
    for (auto f : functions)
    {
        const auto stmt = f(pos);
        if (stmt.wasParsed())
        {
            return stmt;
        }
    }

    // For simple single-word statements, we use this table
    static const vector<pair<string, function<Statement()>>> statements{
        {"RETURN", Statement::returnStatement},
        {"RT", Statement::returnStatement},
        {"RUN", Statement::run},
        {"END", Statement::end},
        {"CLEAR", Statement::clear},
        {"BYE", Statement::bye},
        {"FILES", Statement::files},
        {"FL", Statement::files},
        {"TRON", Statement::tron},
        {"TROFF", Statement::troff},
        {"HELP", Statement::help}};
    for (auto s : statements)
    {
        const auto keyword = literal(s.first, pos);
        if (keyword.wasParsed())
        {
            return successfulParse(s.second(), keyword.nextPos());
        }
    }

    return failedParse<Statement>();
}

/// Parse user entry for INPUT
///
/// Return parsed number and following position if successful.
///
/// Accepts entry of a number with optional leading sign (+|-), or a variable
/// name.
Parse<Number> inputExpression(const InputPos &pos, InterpreterEngine &engine)
{
    // number
    const auto num = numberLiteral(pos);
    if (num.wasParsed())
    {
        return successfulParse(num.value(), num.nextPos());
    }

    // "+" number
    const auto plusNum = pos.parse<string, Number>(lit("+"), numberLiteral);
    if (plusNum != nullptr)
    {
        return successfulParse(get<1>(*plusNum), get<2>(*plusNum));
    }

    // "-" number
    const auto minusNum = pos.parse<string, Number>(lit("-"), numberLiteral);
    if (minusNum != nullptr)
    {
        return successfulParse(-get<1>(*minusNum), get<2>(*minusNum));
    }

    // variable
    const auto varname = variableName(pos);
    if (varname.wasParsed())
    {
        const auto value = engine.getVariableValue(varname.value());
        return successfulParse(value, varname.nextPos());
    }

    return failedParse<Number>();
}

}  // namespace finchlib_cpp
