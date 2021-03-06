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

#ifndef __finchbasic__syntax__
#define __finchbasic__syntax__

#include "Interpreter.h"

#include "cppdefs.h"

namespace finchlib_cpp
{
class InterpreterEngine;

using VariableName = Char;

using VariableBindings = map<VariableName, Number>;
using Numbers = vec<Number>;
using ReturnStack = vec<size_t>;

class Expression;

/// Binary operator for Numbers
class ArithOp
{
private:
    function<Number(Number, Number)> fn;
    string text;

public:
    ArithOp(function<Number(Number, Number)> f, string listText)
        : fn{f}, text{listText} {}

    Number apply(Number lhs, Number rhs) const { return fn(lhs, rhs); }

    string listText() const { return text; }

    static const ArithOp Add;
    static const ArithOp Subtract;
    static const ArithOp Multiply;
    static const ArithOp Divide;
};

/// Relational operator
class RelOp
{
private:
    function<bool(Number, Number)> fn;
    string text;

public:
    RelOp(function<bool(Number, Number)> f, string listText)
        : fn{f}, text{listText} {}

    bool isTrueForNumbers(Number lhs, Number rhs) const { return fn(lhs, rhs); }

    string listText() const { return text; }

    static const RelOp Less;
    static const RelOp Greater;
    static const RelOp Equal;
    static const RelOp LessOrEqual;
    static const RelOp GreaterOrEqual;
    static const RelOp NotEqual;
};

/// Result of parsing a factor
class Factor
{
private:
    struct Subtype
    {
        virtual Number evaluate(const VariableBindings &v,
                                const Numbers &a) const = 0;
        virtual string listText() const = 0;
    };

    /// number
    struct Num : public Subtype
    {
        Number number;

        Num(Number n) : number(n) {}

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    /// "(" expression ")"
    struct ParenExpr : public Subtype
    {
        sptr<Expression> expression;

        ParenExpr(const Expression &e);

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    /// variable
    struct Var : public Subtype
    {
        VariableName variableName;

        Var(VariableName v) : variableName{v} {}

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    /// "@(" expression ")"
    struct ArrayElement : public Subtype
    {
        sptr<Expression> expression;

        ArrayElement(const Expression &e);

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    /// "RND(" expression ")"
    struct Rnd : public Subtype
    {
        sptr<Expression> expression;

        Rnd(const Expression &e);

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    sptr<Subtype> subtype;

    Factor(sptr<Subtype> s) : subtype(s) {}

public:
    /// Construct a Factor from a Number
    static Factor number(Number n)
    {
        return {make_shared<Num>(n)};
    }

    /// Construct a Factor from a parenthesized expression
    static Factor parenExpr(const Expression &expr)
    {
        return {make_shared<ParenExpr>(expr)};
    }

    /// Construct a Factor from a variable name
    static Factor var(VariableName v)
    {
        return {make_shared<Var>(v)};
    }

    /// Construct a Factor for an array element
    static Factor arrayElement(const Expression &expr)
    {
        return {make_shared<ArrayElement>(expr)};
    }

    /// Construct a Factor for a RND() function call
    static Factor rnd(const Expression &expr)
    {
        return {make_shared<Rnd>(expr)};
    }

    /// Return the value of the factor
    Number evaluate(const VariableBindings &v, const Numbers &a) const;

    /// Return pretty-printed text
    string listText() const;
};

/// Result of parsing a term
class Term
{
private:
    struct Subtype
    {
        virtual Number evaluate(const VariableBindings &v,
                                const Numbers &a) const = 0;
        virtual string listText() const = 0;
        virtual bool isCompound() const = 0;
    };

    /// factor
    struct Value : public Subtype
    {
        Factor factor;

        Value(Factor f) : factor{f} {}

        virtual bool isCompound() const { return false; }

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    /// factor "*" term
    /// factor "/" term
    struct Compound : public Subtype
    {
        Factor factor;
        ArithOp arithOp;
        sptr<Term> term;

        Compound(Factor f, ArithOp op, const Term &t);

        virtual bool isCompound() const { return true; }

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    sptr<Subtype> subtype;

    Term(sptr<Subtype> s) : subtype{s} {}

public:
    /// Construct a Term from a Factor
    static Term factor(Factor f)
    {
        return {make_shared<Value>(f)};
    }

    /// Construct a Term from a Factor, ArithOp, and another Term
    static Term compound(Factor f, ArithOp op, const Term &t)
    {
        return {make_shared<Compound>(f, op, t)};
    }

    /// Return the value of the term
    Number evaluate(const VariableBindings &v, const Numbers &a) const;

    /// Return true if this is a Compound
    bool isCompound() const;

    /// Return pretty-printed text
    string listText() const;
};

/// Result of parsing an expression with no leading sign
class UnsignedExpression
{
private:
    struct Subtype
    {
        virtual Number evaluate(const VariableBindings &v,
                                const Numbers &a) const = 0;
        virtual string listText() const = 0;
        virtual bool isCompound() const = 0;
    };

    /// term
    struct Value : public Subtype
    {
        Term term;

        Value(Term t) : term(t) {}

        virtual bool isCompound() const { return false; }

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    /// term "+" unsignedexpression
    /// term "-" unsignedexpression
    struct Compound : public Subtype
    {
        Term term;
        ArithOp arithOp;
        sptr<UnsignedExpression> tail;

        Compound(Term t, ArithOp op, const UnsignedExpression &u);

        virtual bool isCompound() const { return true; }

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    sptr<Subtype> subtype;

    UnsignedExpression(sptr<Subtype> s) : subtype(s) {}

public:
    /// Construct an UnsignedExpression from a Term
    static UnsignedExpression term(Term t)
    {
        return {make_shared<Value>(t)};
    }

    /// Construct an UnsignedExpression from a term, an operation, and successive
    /// expression
    static UnsignedExpression compound(Term t, ArithOp op,
                                       const UnsignedExpression &u)
    {
        return {make_shared<Compound>(t, op, u)};
    }

    /// Return the value of the expression
    Number evaluate(const VariableBindings &v, const Numbers &a) const;

    /// Return the value of the expression, negating the value of the first term
    Number evaluateWithNegatedFirstTerm(const VariableBindings &v,
                                        const Numbers &a) const;

    /// Return true if this is a Compound
    bool isCompound() const;

    /// Return pretty-printed text
    string listText() const;
};

/// Result of parsing an expression
class Expression
{
private:
    struct Subtype
    {
        UnsignedExpression unsignedExpression;

        Subtype(UnsignedExpression uexpr) : unsignedExpression{uexpr} {}

        virtual Number evaluate(const VariableBindings &v,
                                const Numbers &a) const = 0;
        virtual string listText() const = 0;
    };

    /// expression with no leading sign
    struct UnsignedExpr : public Subtype
    {
        UnsignedExpr(UnsignedExpression uexpr) : Subtype{uexpr} {}

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    /// expression with explicit "+" prefix
    struct Plus : public Subtype
    {
        Plus(UnsignedExpression uexpr) : Subtype{uexpr} {}

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    /// expression with explicit "-" prefix
    struct Minus : public Subtype
    {
        Minus(UnsignedExpression uexpr) : Subtype{uexpr} {}

        virtual Number evaluate(const VariableBindings &v, const Numbers &a) const;
        virtual string listText() const;
    };

    sptr<Subtype> subtype;

    Expression(sptr<Subtype> s) : subtype{s} {}

public:
    /// Construct an expression from an UnsignedExpression
    static Expression unsignedExpr(UnsignedExpression uexpr)
    {
        return {make_shared<UnsignedExpr>(uexpr)};
    }

    /// Construct an expression from an UnsignedExpression
    static Expression plus(UnsignedExpression uexpr)
    {
        return {make_shared<Plus>(uexpr)};
    }

    /// Construct an expression from an UnsignedExpression
    static Expression minus(UnsignedExpression uexpr)
    {
        return {make_shared<Minus>(uexpr)};
    }

    /// Construct an expression from a numeric constant
    static Expression number(Number n);

    /// Return the value of the expression
    Number evaluate(const VariableBindings &v, const Numbers &a) const;

    /// Return pretty-printed text
    string listText() const;
};

/// Abstract interface for objects that provide text for PRINT output
class PrintTextProvider
{
public:
    /// Return characters to be output by PRINT statement for this element
    virtual vec<Char> printText(const VariableBindings &v,
                                const Numbers &a) const = 0;
};

/// Result of parsing an item in a printList
class PrintItem : public PrintTextProvider
{
private:
    struct Subtype
    {
        virtual vec<Char> printText(const VariableBindings &v,
                                    const Numbers &a) const = 0;

        /// Return pretty-printed statement text
        virtual string listText() const = 0;
    };

    /// expression
    struct Expr : public Subtype
    {
        Expression expression;

        Expr(Expression e) : expression(e) {}

        virtual vec<Char> printText(const VariableBindings &v,
                                    const Numbers &a) const;
        virtual string listText() const;
    };

    /// "string"
    struct StringLiteral : public Subtype
    {
        vec<Char> chars;

        StringLiteral(const vec<Char> characters) : chars(characters) {}

        virtual vec<Char> printText(const VariableBindings &v,
                                    const Numbers &a) const;
        virtual string listText() const;
    };

    sptr<Subtype> subtype;

    PrintItem(sptr<Subtype> sub) : subtype{sub} {}

public:
    /// Construct a PrintItem from an expression
    static PrintItem expression(Expression expr)
    {
        return {make_shared<Expr>(expr)};
    }

    /// Construct a PrintItem from a string literal
    static PrintItem stringLiteral(const vec<Char> &value)
    {
        return {make_shared<StringLiteral>(value)};
    }

    virtual vec<Char> printText(const VariableBindings &v,
                                const Numbers &a) const;

    /// Return pretty-printed statement text
    string listText() const;
};

/// Specification of text to be output between PrintItems
typedef NS_ENUM(int, PrintSeparator)
{
    PrintSeparatorNewline,
    PrintSeparatorTab,
    PrintSeparatorEmpty
};

/// Result of parsing a printList
class PrintList : public PrintTextProvider
{
private:
    /// First item
    PrintItem item;

    /// Text to be output after item
    PrintSeparator separator;

    /// Remaining in list.  Null if no more items.
    sptr<PrintList> tail;

public:
    PrintList(const PrintItem &firstItem, PrintSeparator sep,
              sptr<PrintList> otherItems)
        : item(firstItem), separator(sep), tail(otherItems) {}

    /// Return characters to be output by PRINT statement for this element
    vec<Char> printText(const VariableBindings &v,
                        const Numbers &a) const;

    /// Return pretty-printed statement text
    string listText() const;
};

/// A variable or array element reference
class Lvalue
{
private:
    struct Subtype
    {
        virtual string listText() const = 0;
        virtual void setValue(Number n, InterpreterEngine &engine) const = 0;
    };

    struct Var : public Subtype
    {
        VariableName variableName;

        Var(VariableName v) : variableName{v} {}

        virtual string listText() const;
        virtual void setValue(Number n, InterpreterEngine &engine) const;
    };

    struct ArrayElement : public Subtype
    {
        Expression subscript;

        ArrayElement(const Expression &sub) : subscript{sub} {}

        virtual string listText() const;
        virtual void setValue(Number n, InterpreterEngine &engine) const;
    };

    sptr<Subtype> subtype;

    Lvalue(sptr<Subtype> s) : subtype{s} {}

public:
    /// Return an Lvalue for a variable
    static Lvalue var(VariableName v)
    {
        return {make_shared<Var>(v)};
    }

    /// Return an Lvalue for an array element
    static Lvalue arrayElement(const Expression &expr)
    {
        return {make_shared<ArrayElement>(expr)};
    }

    /// Return pretty-printed text
    string listText() const;

    /// Set the value
    void setValue(Number n, InterpreterEngine &engine) const;

    /// Evaluate expression and set value
    void setValue(const Expression &expr, InterpreterEngine &engine) const;
};

using Lvalues = vec<Lvalue>;

/// BASIC statement that can be parsed and executed
class Statement
{
private:
    struct Subtype
    {
        virtual void execute(InterpreterEngine &engine) const = 0;

        virtual string listText() const = 0;
    };

    struct Print : public Subtype
    {
        PrintList printList;

        Print(const PrintList &plist) : printList(plist) {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct PrintNewline : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct List : public Subtype
    {
        Expression lowLineNumber;
        Expression highLineNumber;

        List(const Expression &low, const Expression &high)
            : lowLineNumber{low}, highLineNumber{high} {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Let : public Subtype
    {
        Lvalue lvalue;
        Expression expression;

        Let(const Lvalue &lv, const Expression &expr)
            : lvalue(lv), expression(expr) {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Input : public Subtype
    {
        Lvalues lvalues;

        Input(const Lvalues &lv) : lvalues(lv) {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct IfThen : public Subtype
    {
        Expression lhs;
        RelOp op;
        Expression rhs;
        sptr<Statement> consequent;

        IfThen(const Expression &left, const RelOp &relop, const Expression &right,
               const Statement &thenStatement);

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Run : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct End : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Goto : public Subtype
    {
        Expression lineNumber;

        Goto(const Expression &expr) : lineNumber{expr} {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Gosub : public Subtype
    {
        Expression lineNumber;

        Gosub(const Expression &expr) : lineNumber{expr} {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Return : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Rem : public Subtype
    {
        string text;

        Rem(const string &s) : text{s} {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Clear : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Bye : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Help : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Dim : public Subtype
    {
        Expression expression;

        Dim(const Expression &expr) : expression{expr} {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Save : public Subtype
    {
        string filename;

        Save(string s) : filename{s} {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Load : public Subtype
    {
        string filename;

        Load(string s) : filename{s} {}

        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Files : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct ClipSave : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct ClipLoad : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Tron : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    struct Troff : public Subtype
    {
        virtual void execute(InterpreterEngine &engine) const;
        virtual string listText() const;
    };

    sptr<Subtype> subtype;

    Statement(sptr<Subtype> sub) : subtype(sub) {}

    Statement() : subtype(nullptr) {}

public:
    /// Execute the statement
    void execute(InterpreterEngine &engine) const;

    /// Return pretty-printed statement text
    string listText() const;

    /// Return a PRINT statement that has arguments
    static Statement print(const PrintList &printList)
    {
        return {make_shared<Print>(printList)};
    }

    /// Return a PRINT statement with no arguments
    static Statement printNewline()
    {
        return {make_shared<PrintNewline>()};
    }

    /// Return a LIST statement
    static Statement list(const Expression &lowLineNumber = Expression::number(0),
                          const Expression &highLineNumber = Expression::number(
                              numeric_limits<Number>::max()))
    {
        return {make_shared<List>(lowLineNumber, highLineNumber)};
    }

    /// Return a LET statement
    static Statement let(const Lvalue &lv, const Expression &expr)
    {
        return {make_shared<Let>(lv, expr)};
    }

    /// Return an INPUT statement
    static Statement input(const Lvalues &lv)
    {
        return {make_shared<Input>(lv)};
    }

    /// Return an IF statement
    static Statement ifThen(const Expression &left,
                            const RelOp &relop,
                            const Expression &right,
                            const Statement &thenStatement)
    {
        return {make_shared<IfThen>(left, relop, right, thenStatement)};
    }

    /// Return a RUN statement
    static Statement run()
    {
        return {make_shared<Run>()};
    }

    /// Return a END statement
    static Statement end()
    {
        return {make_shared<End>()};
    }

    /// Return a GOTO statement
    static Statement gotoStatement(const Expression &expr)
    {
        return {make_shared<Goto>(expr)};
    }

    /// Return a GOSUB statement
    static Statement gosub(const Expression &expr)
    {
        return {make_shared<Gosub>(expr)};
    }

    /// Return a RETURN statement
    static Statement returnStatement()
    {
        return {make_shared<Return>()};
    }

    /// Return a REM statement
    static Statement rem(const string &s)
    {
        return {make_shared<Rem>(s)};
    }

    /// Return a CLEAR statement
    static Statement clear()
    {
        return {make_shared<Clear>()};
    }

    /// Return a BYE statement
    static Statement bye()
    {
        return {make_shared<Bye>()};
    }

    /// Return a HELP statement
    static Statement help()
    {
        return {make_shared<Help>()};
    }

    /// Return a DIM statement
    static Statement dim(const Expression &expr)
    {
        return {make_shared<Dim>(expr)};
    }

    /// Return a SAVE stateent
    static Statement save(string filename)
    {
        return {make_shared<Save>(filename)};
    }

    /// Return a LOAD stateent
    static Statement load(string filename)
    {
        return {make_shared<Load>(filename)};
    }

    /// Return a FILES stateent
    static Statement files()
    {
        return {make_shared<Files>()};
    }

    /// Return a CLIPSAVE stateent
    static Statement clipSave()
    {
        return {make_shared<ClipSave>()};
    }

    /// Return a CLIPLOAD stateent
    static Statement clipLoad()
    {
        return {make_shared<ClipLoad>()};
    }

    /// Return a TRON stateent
    static Statement tron()
    {
        return {make_shared<Tron>()};
    }

    /// Return a TROFF stateent
    static Statement troff()
    {
        return {make_shared<Troff>()};
    }

    /// Return an invalid Statement
    ///
    /// This is used only for cases where a default constructor is needed.
    /// Any attempt to use this Statement will result in an access violation.
    static Statement invalid() { return {}; }
};

struct NumberedStatement
{
    Number lineNumber;
    Statement statement;

    // No-arg constructor, provided so that NumberedStatement can be
    // used in vec.
    NumberedStatement() : lineNumber(0), statement(Statement::invalid()) {}

    NumberedStatement(Number n, Statement s) : lineNumber(n), statement(s) {}

    NumberedStatement(const NumberedStatement &copy) = default;

    NumberedStatement &operator=(const NumberedStatement &copy) = default;
};

using Program = vec<NumberedStatement>;

}  // namespace finchlib_cpp

#endif /* defined(__finchbasic__syntax__) */
