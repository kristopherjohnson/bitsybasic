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

// Syntax accepted by FinchBasic is based upon the charts here:
//
//     http://en.wikipedia.org/wiki/Tiny_BASIC
//
// and in Appendix B of
//
//     http://www.ittybittycomputers.com/IttyBitty/TinyBasic/TBuserMan.htm


/// There are 26 variables with names 'A'...'Z'
public typealias VariableName = Char

/// A Finch numeric value is a signed integer
///
/// Note: Traditionally, Tiny Basic uses 16-bit integers, but we'll
/// relax that restriction and use whatever native integer type
/// the platform provides.
public typealias Number = Int

/// Result of parsing a statement
public enum Statement {
    /// "PRINT" printlist
    ///
    /// "PR" printlist
    case Print(ExprList)

    /// "INPUT" varlist
    case Input(VarList)

    /// "LET" var "=" expression
    case Let(VariableName, Expression)

    /// "GOTO" expression
    case Goto(Expression)

    /// "GOSUB" expression
    case Gosub(Expression)

    /// "RETURN"
    case Return

    /// "IF" expression relop expression "THEN" statement
    case If(Expression, Relop, Expression, Box<Statement>)

    /// "REM" commentstring
    case Rem(String)

    /// "CLEAR"
    case Clear

    /// "RUN"
    case Run

    /// "END"
    case End

    /// "LIST"
    case List

    /// Unable to parse input as statement
    case Error(String)
}

/// Result of parsing a varlist
public enum VarList {
    /// "A" | "B" | ... | "Y" | "Z"
    case Var(VariableName)

    /// var "," varlist
    case Vars(VariableName, Box<VarList>)

    /// Error occurred when expecting a varlist
    case Error(String)
}

/// Result of parsing an exprlist
public enum ExprList {
    /// expression
    case Expr(Expression)

    /// '"' string '"'
    case Str([Char])

    /// expression "," exprlist
    case Exprs(Expression, Box<ExprList>)

    /// Error occurred when expecting an exprlist
    case Error(String)
}

/// Result of parsing an expression
public enum Expression {
    /// unsignedexpression
    case UnsignedExpr(UnsignedExpression)

    /// "+" unsignedexpression
    case Plus(UnsignedExpression)

    /// "-" unsignedexpression
    case Minus(UnsignedExpression)


    /// Return the value of the expression
    var value: Number {
        switch self {
        case .UnsignedExpr(let uexpr): return uexpr.value
        default:                       return 0
        }
    }
}

/// Result of parsing an unsigned expression
public enum UnsignedExpression {
    /// term
    case Value(Term)

    /// term + unsignedexpression
    case Add(Term, Box<UnsignedExpression>)

    /// term - unsignedexpression
    case Subtract(Term, Box<UnsignedExpression>)


    /// Return the value of this UnsignedExpression
    var value: Number {
        switch self {
        case .Value(let term): return term.value
        default:               return 0
        }
    }
}

/// Result of parsing a term
public enum Term {
    /// factor
    case Value(Factor)

    /// factor * term
    case Product(Factor, Box<Term>)

    /// factor / term
    case Quotient(Factor, Box<Term>)


    /// Return the value of this Term
    var value: Number {
        switch self {
        case .Value(let factor): return factor.value
        default:                 return 0
        }
    }
}

/// Result of parsing a factor
public enum Factor {
    /// var
    case Var(VariableName)

    /// number
    case Num(Number)

    /// "(" expression ")"
    case Expr(Box<Expression>)


    /// Return the value of this Term
    var value: Number {
        switch self {
        case .Num(let number): return number
        default:               return 0
        }
    }
}

/// Result of parsing a relational operator
public enum Relop {
    /// "<"
    case LessThan

    /// ">"
    case GreaterThan

    /// "="
    case EqualTo

    /// "<="
    case LessThanOrEqualTo

    /// ">="
    case GreaterThanOrEqualTo

    /// "<>" or "><"
    case NotEqualTo


    /// Determine whether the relation is true for specified values
    public func isTrueForNumbers(lhs: Number, _ rhs: Number) -> Bool {
        switch self {
        case .LessThan:             return lhs < rhs
        case .GreaterThan:          return lhs > rhs
        case .EqualTo:              return lhs == rhs
        case .LessThanOrEqualTo:    return lhs <= rhs
        case .GreaterThanOrEqualTo: return lhs >= rhs
        case .NotEqualTo:           return lhs != rhs
        }
    }
}

/// A program is a sequence of numbered statements
public typealias Program = [(Number, Statement)]

/// An input line is parsed to be a statement preceded by a line number,
/// which will be inserted into the program, or a statement without a preceding
/// line number, which will be executed immediately.
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
