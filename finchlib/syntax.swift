/*
Copyright (c) 2014 Kristopher Johnson

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

import Foundation

// Note: Syntax accepted by FinchBasic is based upon Appendix B of
// http://www.ittybittycomputers.com/IttyBitty/TinyBasic/TBuserMan.htm

/// There are 26 variables with names 'A'...'Z'
public typealias VariableName = UInt8

/// A Finch numeric value is a 16-bit signed integer
public typealias Number = Int16

/// A program is a sequence of lines
///
/// All elements of a Program are of the Line.NumberedStatement enum case
public typealias Program = [Line]

/// An input line is parsed to be a statement preceded by a line number,
/// or a statement without a preceding line number.
///
/// Also possible are empty input lines, which are ignored, or unparseable
/// input lines, which generate an error message.
public enum Line {
    // Parsed statement with a line number
    case NumberedStatement(Number, Statement)

    // Parsed statement without a preceding line number
    case UnnumberedStatement(Statement)

    // Empty input line
    case Empty

    // Error occurred while parsing the line, resulting in error message
    case Error(String)
}

// Result of parsing a statement
public enum Statement {
    /// "PRINT" printlist
    ///
    /// "PR" printlist
    case Print(PrintList)

    /// "INPUT" varlist
    case Input(VarList)

    /// "LET" var "=" expression
    ///
    /// var "=" expression
    case Let(VariableName, Expression)

    /// "GOTO" expression
    case Goto(Expression)

    /// "GOSUB" expression
    case Gosub(Expression)

    /// "RETURN"
    case Return

    /// "IF" expression relop expression "THEN" statement
    ///
    /// "IF" expression relop expression statement
    case If(Expression, Relop, Expression, Box<Statement>)

    /// "REM" commentstring
    case Rem(String)

    /// "CLEAR"
    case Clear

    /// "RUN"
    ///
    /// "RUN" exprlist
    case Run(ExprList?)

    /// "LIST"
    ///
    /// "LIST" exprlist
    case List(ExprList?)

    /// Unable to parse input as statement
    case Error(String)
}

// Result of parsing a printlist
public enum PrintList {
    case Item(PrintItem)
    case Items(PrintItem, Box<PrintList>)
    case Error(String)
}

// Result of parsing an item in a printlist
public enum PrintItem {
    /// expression
    case Expr(Expression)

    /// '"' string '"'
    case Str([Char])

    /// Error occurred while trying to parse expression
    case Error(String)
}

// Result of parsing a var-list
public enum VarList {
    /// "A", "B", ..., "Y", or "Z"
    case Var(VariableName)

    /// var "," varlist
    case Vars(VariableName, Box<VarList>)

    /// Error occurred when expecting a varlist
    case Error(String)
}

// Result of parsing an expr-list
public enum ExprList {
    /// expression
    case Expr(Expression)

    /// expression "," exprlist
    case Exprs(Expression, Box<ExprList>)

    /// Error occurred when expecting an exprlist
    case Error(String)
}

// Result of parsing an expression
public enum Expression {
    /// unsignedexpression
    case UnsignedExpr(UnsignedExpression)

    /// "+" unsignedexpression
    case Plus(UnsignedExpression)

    /// "-" unsignedexpression
    case Minus(UnsignedExpression)

    /// Error occurred when expecting an expression
    case Error(String)
}

// Result of parsing an unsigned expression
public enum UnsignedExpression {
    case SingleTerm(Term)
    case Add(Term, Box<UnsignedExpression>)
    case Subtract(Term, Box<UnsignedExpression>)
    case Error(String)
}

// Result of parsing a term
public enum Term {
    case SingleFactor(Factor)
    case Product(Factor, Box<Term>)
    case Quotient(Factor, Box<Term>)
    case Error(String)
}

/// Result of parsing a factor
public enum Factor {
    case Var(VariableName)
    case Num(Number)
    case Expr(Box<Expression>)
    case Fun(Function)
    case Error(String)
}

/// Result of parsing a function call
public enum Function {
    case Rnd(Box<Expression>)
    case Usr(Box<ExprList>)
    case Error(String)
}

/// Result of parsing a relational operator
public enum Relop {
    /// "<"
    case LessThan

    /// ">"
    case GreaterThan

    /// "="
    case Equal

    /// "<="
    case LessThanOrEqual

    /// ">="
    case GreaterThanOrEqual

    /// "<>" or "><"
    case NotEqual


    /// Determine whether the relation is true for specified values
    public func isTrueForNumbers(lhs: Number, _ rhs: Number) -> Bool {
        switch self {
        case .LessThan:           return lhs < rhs
        case .GreaterThan:        return lhs > rhs
        case .Equal:              return lhs == rhs
        case .LessThanOrEqual:    return lhs <= rhs
        case .GreaterThanOrEqual: return lhs >= rhs
        case .NotEqual:           return lhs != rhs
        }
    }
}

