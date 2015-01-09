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

#include "syntax.h"
#include "InterpreterEngine.h"

#include <sstream>

using namespace finchlib_cpp;

#pragma mark - Lvalue

std::string Lvalue::listText() const
{
    return subtype->listText();
}

void Lvalue::setValue(Number n, InterpreterEngine &engine) const
{
    subtype->setValue(n, engine);
}

void Lvalue::setValue(const Expression &expr, InterpreterEngine &engine) const
{
    const auto number = engine.evaluate(expr);
    subtype->setValue(number, engine);
}

std::string Lvalue::Var::listText() const
{
    return std::string(1, static_cast<char>(variableName));
}

void Lvalue::Var::setValue(Number n, InterpreterEngine &engine) const
{
    engine.setVariableValue(variableName, n);
}

std::string Lvalue::ArrayElement::listText() const
{
    return "@(" + subscript.listText() + ")";
}

void Lvalue::ArrayElement::setValue(Number n, InterpreterEngine &engine) const
{
    engine.setArrayElementValue(subscript, n);
}

#pragma mark - ArithOp

// Our division operator returns 0 on an attempt
// to divide by zero.
//
// This is better than letting the interpreter crash
// if the user attempts to divide something by zero
// in a BASIC program.  A better solution might be
// to let the interpreter report an error and abort
// execution, returning to command mode, but we
// don't have a way for expression evaluation to
// signal such a condition.  (In C++, we could do this
// with exceptions, but we can't port that over to
// the Swift implementation.)
struct SafeDivides
{
    Number operator()(Number lhs, Number rhs)
    {
        if (rhs == 0)
        {
            return 0;
        }
        return lhs / rhs;
    }
};

const ArithOp ArithOp::Add{std::plus<Number>{}, "+"};
const ArithOp ArithOp::Subtract{std::minus<Number>{}, "-"};
const ArithOp ArithOp::Multiply{std::multiplies<Number>{}, "*"};
const ArithOp ArithOp::Divide{SafeDivides{}, "/"};

#pragma mark - RelOp

const RelOp RelOp::Less{std::less<Number>{}, "<"};
const RelOp RelOp::Greater{std::greater<Number>{}, ">"};
const RelOp RelOp::Equal{std::equal_to<Number>{}, "="};
const RelOp RelOp::LessOrEqual{std::less_equal<Number>{}, "<="};
const RelOp RelOp::GreaterOrEqual{std::greater_equal<Number>{}, ">="};
const RelOp RelOp::NotEqual{std::not_equal_to<Number>{}, "<>"};

#pragma mark - Factor

/// Return the value of the factor
Number Factor::evaluate(const VariableBindings &v, const Numbers &a) const
{
    return subtype->evaluate(v, a);
}

std::string Factor::listText() const { return subtype->listText(); }

Number Factor::Num::evaluate(const VariableBindings &v,
                             const Numbers &a) const
{
    return number;
}

std::string Factor::Num::listText() const
{
    std::ostringstream s;
    s << number;
    return s.str();
}

Factor::ParenExpr::ParenExpr(const Expression &expr)
    : expression{std::shared_ptr<Expression>{new Expression{expr}}} {}

Number Factor::ParenExpr::evaluate(const VariableBindings &v,
                                   const Numbers &a) const
{
    return expression->evaluate(v, a);
}

std::string Factor::ParenExpr::listText() const
{
    return "(" + expression->listText() + ")";
}

Number Factor::Var::evaluate(const VariableBindings &v,
                             const Numbers &a) const
{
    const auto it = v.find(variableName);
    return it == v.end() ? 0 : it->second;
}

std::string Factor::Var::listText() const
{
    return std::string(1, static_cast<char>(variableName));
}

Factor::ArrayElement::ArrayElement(const Expression &e)
    : expression{std::shared_ptr<Expression>{new Expression{e}}} {}

Number Factor::ArrayElement::evaluate(const VariableBindings &v,
                                      const Numbers &a) const
{
    const auto index = expression->evaluate(v, a);
    if (index >= 0)
    {
        return a[index % a.size()];
    }
    else
    {
        const auto fromEnd = -index % a.size();
        return a[a.size() - fromEnd];
    }
}

std::string Factor::ArrayElement::listText() const
{
    return "@(" + expression->listText() + ")";
}

Factor::Rnd::Rnd(const Expression &e)
    : expression{std::shared_ptr<Expression>{new Expression{e}}} {}

Number Factor::Rnd::evaluate(const VariableBindings &v,
                             const Numbers &a) const
{
    const auto n = expression->evaluate(v, a);
    if (n < 1)
    {
        // TODO: signal a runtime error?
        return 0;
    }
    return Number(arc4random_uniform(n));
}

std::string Factor::Rnd::listText() const
{
    return "RND(" + expression->listText() + ")";
}

#pragma mark - Term

/// Return the value of the term
Number Term::evaluate(const VariableBindings &v, const Numbers &a) const
{
    return subtype->evaluate(v, a);
}

/// Return pretty-printed text
std::string Term::listText() const { return subtype->listText(); }

bool Term::isCompound() const { return subtype->isCompound(); }

Number Term::Value::evaluate(const VariableBindings &v,
                             const Numbers &a) const
{
    return factor.evaluate(v, a);
}

std::string Term::Value::listText() const { return factor.listText(); }

Term::Compound::Compound(Factor f, ArithOp op, const Term &t)
    : factor{f}, arithOp{op}, term{std::shared_ptr<Term>{new Term{t}}} {}

Number Term::Compound::evaluate(const VariableBindings &v,
                                const Numbers &a) const
{
    auto accumulator = factor.evaluate(v, a);
    auto lastOp = arithOp;
    std::shared_ptr<Term> next = term;
    for (;;)
    {
        if (next->isCompound())
        {
            // Pull out the components of the compound term, apply
            // the previous operator to the accumulator and new factor,
            // then go on to next term.
            auto compound = static_cast<const Term::Compound *>(next->subtype.get());
            accumulator = lastOp.apply(accumulator, compound->factor.evaluate(v, a));
            lastOp = compound->arithOp;
            next = compound->term;
        }
        else
        {
            // Reached the final non-compound term, so we can return result
            return lastOp.apply(accumulator, next->evaluate(v, a));
        }
    }
}

std::string Term::Compound::listText() const
{
    return factor.listText() + " " + arithOp.listText() + " " + term->listText();
}

#pragma mark - UnsignedExpression

/// Return the value of the expression
Number UnsignedExpression::evaluate(const VariableBindings &v,
                                    const Numbers &a) const
{
    return subtype->evaluate(v, a);
}

Number
UnsignedExpression::evaluateWithNegatedFirstTerm(const VariableBindings &v,
                                                 const Numbers &a) const
{
    if (isCompound())
    {
        // Pull out the components of the compound term, create
        // a new expression with the first term negated, and evaluate
        // that.
        auto compound = static_cast<const UnsignedExpression::Compound *>(subtype.get());
        const auto termValue = compound->term.evaluate(v, a);
        const auto negatedFactor = Factor::number(-termValue);
        const auto negatedTerm = Term::factor(negatedFactor);
        const auto newUExpr = UnsignedExpression::compound(
            negatedTerm, compound->arithOp, *compound->tail);
        const auto newExpr = Expression::unsignedExpr(newUExpr);
        return newExpr.evaluate(v, a);
    }
    else
    {
        return -evaluate(v, a);
    }
}

std::string UnsignedExpression::listText() const { return subtype->listText(); }

bool UnsignedExpression::isCompound() const { return subtype->isCompound(); }

Number UnsignedExpression::Value::evaluate(const VariableBindings &v,
                                           const Numbers &a) const
{
    return term.evaluate(v, a);
}

std::string UnsignedExpression::Value::listText() const
{
    return term.listText();
}

UnsignedExpression::Compound::Compound(Term t, ArithOp op,
                                       const UnsignedExpression &u)
    : term{t}, arithOp{op}, tail{std::shared_ptr<UnsignedExpression>{new UnsignedExpression{u}}} {}

Number UnsignedExpression::Compound::evaluate(const VariableBindings &v,
                                              const Numbers &a) const
{
    auto accumulator = term.evaluate(v, a);
    auto lastOp = arithOp;
    std::shared_ptr<UnsignedExpression> next = tail;
    for (;;)
    {
        if (next->isCompound())
        {
            // Pull out the components of the compound term, apply
            // the previous operator to the accumulator and new factor,
            // then go on to next term.
            auto compound = static_cast<const UnsignedExpression::Compound *>(
                next->subtype.get());
            accumulator = lastOp.apply(accumulator, compound->term.evaluate(v, a));
            lastOp = compound->arithOp;
            next = compound->tail;
        }
        else
        {
            // Reached the final non-compound term, so we can return result
            return lastOp.apply(accumulator, next->evaluate(v, a));
        }
    }
}

std::string UnsignedExpression::Compound::listText() const
{
    return term.listText() + " " + arithOp.listText() + " " + tail->listText();
}

#pragma mark - Expression

/// Construct an expression from a numeric constant
Expression Expression::number(Number n)
{
    const auto factor = Factor::number(n);
    const auto term = Term::factor(factor);
    const auto uexpr = UnsignedExpression::term(term);
    return Expression::unsignedExpr(uexpr);
}

/// Return the value of the expression
Number Expression::evaluate(const VariableBindings &v, const Numbers &a) const
{
    return subtype->evaluate(v, a);
}

std::string Expression::listText() const { return subtype->listText(); }

Number Expression::UnsignedExpr::evaluate(const VariableBindings &v,
                                          const Numbers &a) const
{
    return unsignedExpression.evaluate(v, a);
}

std::string Expression::UnsignedExpr::listText() const
{
    return unsignedExpression.listText();
}

Number Expression::Plus::evaluate(const VariableBindings &v,
                                  const Numbers &a) const
{
    return unsignedExpression.evaluate(v, a);
}

std::string Expression::Plus::listText() const
{
    return std::string("+") + unsignedExpression.listText();
}

Number Expression::Minus::evaluate(const VariableBindings &v,
                                   const Numbers &a) const
{
    return unsignedExpression.evaluateWithNegatedFirstTerm(v, a);
}

std::string Expression::Minus::listText() const
{
    return std::string("-") + unsignedExpression.listText();
}

#pragma mark - PrintItem

std::vector<Char> PrintItem::printText(const VariableBindings &v,
                                       const Numbers &a) const
{
    return subtype->printText(v, a);
}

std::string PrintItem::listText() const { return subtype->listText(); }

std::vector<Char> PrintItem::Expr::printText(const VariableBindings &v,
                                             const Numbers &a) const
{
    Number n = expression.evaluate(v, a);

    std::ostringstream s;
    s << n;

    std::vector<Char> result;
    for (auto c : s.str())
        result.push_back(c);
    return result;
}

std::string PrintItem::Expr::listText() const { return expression.listText(); }

std::vector<Char> PrintItem::StringLiteral::printText(const VariableBindings &v,
                                                      const Numbers &a) const
{
    return chars;
}

std::string PrintItem::StringLiteral::listText() const
{
    std::string str;
    str.push_back('"');
    for (auto c : chars)
    {
        str.push_back(c);
    }
    str.push_back('"');
    return str;
}

#pragma mark - PrintList

std::vector<Char> PrintList::printText(const VariableBindings &v,
                                       const Numbers &a) const
{
    auto chars = item.printText(v, a);

    switch (separator)
    {
        case PrintSeparatorNewline:
            chars.push_back('\n');
            break;
        case PrintSeparatorTab:
            chars.push_back('\t');
            break;
        case PrintSeparatorEmpty:
            // nothing
            break;
        default:
            // should be no other cases
            assert(false);
            break;
    }

    if (tail != nullptr)
    {
        const auto tailChars = tail->printText(v, a);
        chars.insert(chars.end(), tailChars.cbegin(), tailChars.cend());
    }

    return chars;
}

std::string PrintList::listText() const
{
    std::ostringstream s;
    s << item.listText();

    switch (separator)
    {
        case PrintSeparatorNewline:
            // nothing
            break;
        case PrintSeparatorTab:
            s << ",";
            break;
        case PrintSeparatorEmpty:
            s << ";";
            break;
        default:
            // should be no other cases
            assert(false);
            break;
    }

    if (tail != nullptr)
    {
        s << " " << tail->listText();
    }

    return s.str();
}

#pragma mark - Statement

void Statement::execute(InterpreterEngine &engine) const
{
    subtype->execute(engine);
}

std::string Statement::listText() const { return subtype->listText(); }

void Statement::Print::execute(InterpreterEngine &engine) const
{
    engine.PRINT(printList);
}

std::string Statement::Print::listText() const
{
    return "PRINT " + printList.listText();
}

void Statement::PrintNewline::execute(InterpreterEngine &engine) const
{
    engine.PRINT();
}

std::string Statement::PrintNewline::listText() const { return "PRINT"; }

void Statement::List::execute(InterpreterEngine &engine) const
{
    engine.LIST(lowLineNumber, highLineNumber);
}

std::string Statement::List::listText() const { return "LIST"; }

void Statement::Let::execute(InterpreterEngine &engine) const
{
    lvalue.setValue(expression, engine);
}

std::string Statement::Let::listText() const
{
    return "LET " + lvalue.listText() + " = " + expression.listText();
}

void Statement::Input::execute(InterpreterEngine &engine) const
{
    engine.INPUT(lvalues);
}

static std::string listTextFor(const Lvalues &lvalues)
{
    if (lvalues.size() == 0)
    {
        return "";
    }

    std::ostringstream s;
    s << lvalues[0].listText();
    for (auto it = lvalues.cbegin() + 1; it != lvalues.cend(); ++it)
    {
        s << ", " << it->listText();
    }
    return s.str();
}

std::string Statement::Input::listText() const
{
    return "INPUT " + listTextFor(lvalues);
}

Statement::IfThen::IfThen(const Expression &left, const RelOp &relop,
                          const Expression &right,
                          const Statement &thenStatement)
    : lhs{left}, op{relop}, rhs{right}, consequent{std::shared_ptr<Statement>{new Statement{thenStatement}}} {}

void Statement::IfThen::execute(InterpreterEngine &engine) const
{
    engine.IF(lhs, op, rhs, *consequent);
}

std::string Statement::IfThen::listText() const
{
    return "IF " + lhs.listText() + " " + op.listText() + " " + rhs.listText() + " THEN " + consequent->listText();
}

void Statement::Run::execute(InterpreterEngine &engine) const { engine.RUN(); }

std::string Statement::Run::listText() const { return "RUN"; }

void Statement::End::execute(InterpreterEngine &engine) const { engine.END(); }

std::string Statement::End::listText() const { return "END"; }

void Statement::Goto::execute(InterpreterEngine &engine) const
{
    engine.GOTO(lineNumber);
}

std::string Statement::Goto::listText() const
{
    return "GOTO " + lineNumber.listText();
}

void Statement::Gosub::execute(InterpreterEngine &engine) const
{
    engine.GOSUB(lineNumber);
}

std::string Statement::Gosub::listText() const
{
    return "GOSUB " + lineNumber.listText();
}

void Statement::Return::execute(InterpreterEngine &engine) const
{
    engine.RETURN();
}

std::string Statement::Return::listText() const { return "RETURN"; }

void Statement::Rem::execute(InterpreterEngine &engine) const
{
    // does nothing
}

std::string Statement::Rem::listText() const { return "REM" + text; }

void Statement::Clear::execute(InterpreterEngine &engine) const
{
    engine.CLEAR();
}

std::string Statement::Clear::listText() const { return "CLEAR"; }

void Statement::Bye::execute(InterpreterEngine &engine) const { engine.BYE(); }

std::string Statement::Bye::listText() const { return "BYE"; }

void Statement::Help::execute(InterpreterEngine &engine) const
{
    engine.HELP();
}

std::string Statement::Help::listText() const { return "HELP"; }

void Statement::Dim::execute(InterpreterEngine &engine) const
{
    engine.DIM(expression);
}

std::string Statement::Dim::listText() const
{
    return "DIM @(" + expression.listText() + ")";
}

void Statement::Save::execute(InterpreterEngine &engine) const
{
    engine.SAVE(filename);
}

std::string Statement::Save::listText() const
{
    return "SAVE \"" + filename + "\"";
}

void Statement::Load::execute(InterpreterEngine &engine) const
{
    engine.LOAD(filename);
}

std::string Statement::Load::listText() const
{
    return "LOAD \"" + filename + "\"";
}

void Statement::Files::execute(InterpreterEngine &engine) const
{
    engine.FILES();
}

std::string Statement::Files::listText() const { return "FILES"; }

void Statement::Tron::execute(InterpreterEngine &engine) const
{
    engine.TRON();
}

std::string Statement::Tron::listText() const { return "TRON"; }

void Statement::Troff::execute(InterpreterEngine &engine) const
{
    engine.TROFF();
}

std::string Statement::Troff::listText() const { return "TROFF"; }
