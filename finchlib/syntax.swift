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


/// A Finch numeric value is a signed integer
///
/// Note: Traditionally, Tiny Basic uses 16-bit integers, but we'll
/// relax that restriction and use whatever native integer type
/// the platform provides.
typealias Number = Int

/// There are 26 variables with names 'A'...'Z'
///
/// Note that the names are uppercase. Any lowercase characters read
/// by the interpreter must be converted to uppercase before
/// using them as variable names.
typealias VariableName = Char

/// Each variable is bound to a numeric value
typealias VariableBindings = [VariableName : Number]

/// Result of parsing a statement
enum Statement {
    /// "PRINT" printlist
    ///
    /// "PR" printlist
    ///
    /// "?" printlist
    case Print(PrintList)

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


    /// Return pretty-printed statement
    var text: String {
        switch self {

        case let .Print(printList):
            return "PRINT \(printList.text)"

        case let .Input(varlist):
            return "INPUT (varlist)" // TODO

        case let .Let(varname, expression):
            return "LET \(stringFromChar(varname)) = \(expression.text)"

        case let .Goto(expression):
            return "GOTO \(expression.text)"

        case let .Gosub(expression):
            return "GOSUB \(expression.text)"
            
        case .Return:
            return "RETURN"
            
        case let .If(lhs, relop, rhs, box):
            return "IF \(lhs.text) \(relop.text) \(rhs.text) THEN \(box.boxedValue.text)"

        case let .Rem(comment):
            return "REM\(comment)"

        case .Clear:
            return "CLEAR"

        case .End:
            return "END"

        case .Run:
            return "RUN"

        case .List:
            return "LIST"

        case let .Error(message):
            return "statement error: \(message)"
        }
    }
}

/// Result of parsing a varlist
enum VarList {
    /// "A" | "B" | ... | "Y" | "Z"
    case Var(VariableName)

    /// var "," varlist
    case Vars(VariableName, Box<VarList>)
}

/// Result of parsing a printlist
enum PrintList {
    /// expression
    case Item(PrintItem)

    /// expression "," exprlist
    case Items(PrintItem, Box<PrintList>)


    /// Return pretty-printed program text
    var text: String {
        switch self {
        case let .Item(printItem):
            return printItem.text

        case let .Items(printItem, printItems):
            var result = printItem.text

            var x = printItems.boxedValue
            var done = false
            while !done {
                switch x {
                case let .Item(item):
                    result.extend(", \(item.text)")
                    done = true
                case let .Items(item, box):
                    result.extend(", \(item.text)")
                    x = box.boxedValue
                }
            }

            return result
        }
    }
}

/// Result of parsing an exprlist
enum PrintItem {
    /// expression
    case Expr(Expression)

    /// '"' string '"'
    case Str([Char])


    /// Return pretty-printed program text
    var text: String {
        switch self {
        case let .Expr(expression):
            return expression.text

        case let .Str(chars):
            return "\"\(stringFromChars(chars))\""
        }
    }
}

/// Result of parsing an expression
enum Expression {
    /// unsignedexpression
    case UnsignedExpr(UnsignedExpression)

    /// "+" unsignedexpression
    case Plus(UnsignedExpression)

    /// "-" unsignedexpression
    case Minus(UnsignedExpression)


    /// Return the value of the expression
    func getValue(v: VariableBindings) -> Number {
        switch self {
        case let .UnsignedExpr(uexpr):
            return uexpr.getValue(v)

        case let .Plus(uexpr):
            return uexpr.getValue(v)

        case let .Minus(uexpr):
            // The leading minus sign must be applied to the
            // first term in the expression (not to the entire expression)
            switch uexpr {
            case .Value(_):
                return -(uexpr.getValue(v))
            case let .Sum(term, remainder):
                let termValue = term.getValue(v)
                return -termValue &+ remainder.boxedValue.getValue(v)
            case let .Diff(term, remainder):
                let termValue = term.getValue(v)
                return -termValue &- remainder.boxedValue.getValue(v)
            }
        }
    }

    /// Return program text
    var text: String {
        switch self {
        case let .UnsignedExpr(uexpr):
            return uexpr.text

        case let .Plus(uexpr):
            return "+\(uexpr.text)"

        case let .Minus(uexpr):
            return "-\(uexpr.text)"
        }
    }
}
/// Result of parsing an unsigned expression
///
/// Note that "unsigned" means "does not have a leading + or - sign".
/// It does not mean that the value is non-negative.
enum UnsignedExpression {
    /// term
    case Value(Term)

    /// term "+" unsignedexpression
    case Sum(Term, Box<UnsignedExpression>)

    /// term "-" unsignedexpression
    case Diff(Term, Box<UnsignedExpression>)


    /// Return the value of this UnsignedExpression
    func getValue(v: VariableBindings) -> Number {
        switch self {

        case let .Value(term):
            return term.getValue(v)

        case let .Sum(term, boxedExpr):
            let expr = boxedExpr.boxedValue
            return term.getValue(v) &+ expr.getValue(v)

        case let .Diff(term, boxedExpr):
            let expr = boxedExpr.boxedValue
            return term.getValue(v) &- expr.getValue(v)
        }
    }

    /// Return pretty-printed program text
    var text: String {
        switch self {
        case let .Value(term):
            return term.text

        case let .Sum(term, boxedExpr):
            return "\(term.text) + \(boxedExpr.boxedValue.text)"

        case let .Diff(term, boxedExpr):
            return "\(term.text) - \(boxedExpr.boxedValue.text)"
        }
    }
}

/// Result of parsing a term
enum Term {
    /// factor
    case Value(Factor)

    /// factor "*" term
    case Product(Factor, Box<Term>)

    /// factor "/" term
    case Quotient(Factor, Box<Term>)


    /// Return the value of this Term
    func getValue(v: VariableBindings) -> Number {
        switch self {

        case let .Value(factor):
            return factor.getValue(v)

        case let .Product(factor, boxedTerm):
            let term = boxedTerm.boxedValue
            return factor.getValue(v) &* term.getValue(v)

        case let .Quotient(factor, boxedTerm):
            let term = boxedTerm.boxedValue
            let divisor = term.getValue(v)
            if divisor == 0 {
                // TODO: signal a divide-by-zero error
                return 0
            }
            return factor.getValue(v) &/ divisor
        }
    }

    /// Return pretty-printed program text
    var text: String {
        switch self {

        case let .Value(factor):
            return factor.text

        case let .Product(factor, boxedTerm):
            return "\(factor.text) * \(boxedTerm.boxedValue.text)"

        case let .Quotient(factor, boxedTerm):
            return "\(factor.text) / \(boxedTerm.boxedValue.text)"
        }
    }
}

/// Result of parsing a factor
enum Factor {
    /// var
    case Var(VariableName)

    /// number
    case Num(Number)

    /// "(" expression ")"
    case ParenExpr(Box<Expression>)


    /// Return the value of this Term
    func getValue(v: VariableBindings) -> Number {
        switch self {
        case let .Var(varname):   return v[varname] ?? 0
        case let .Num(number):    return number
        case let .ParenExpr(box): return box.boxedValue.getValue(v)
        }
    }

    /// Return pretty-printed program text
    var text: String {
        switch self {
        case let .Var(varname):   return stringFromChar(varname)
        case let .Num(number):    return "\(number)"
        case let .ParenExpr(box): return "(\(box.boxedValue.text))"
        }
    }
}

/// Result of parsing a relational operator
enum Relop {
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
    func isTrueForNumbers(lhs: Number, _ rhs: Number) -> Bool {
        switch self {
        case .LessThan:             return lhs < rhs
        case .GreaterThan:          return lhs > rhs
        case .EqualTo:              return lhs == rhs
        case .LessThanOrEqualTo:    return lhs <= rhs
        case .GreaterThanOrEqualTo: return lhs >= rhs
        case .NotEqualTo:           return lhs != rhs
        }
    }

    /// Return pretty-printed program text
    var text: String {
        switch self {
        case .LessThan:             return "<"
        case .GreaterThan:          return ">"
        case .EqualTo:              return "="
        case .LessThanOrEqualTo:    return "<="
        case .GreaterThanOrEqualTo: return ">="
        case .NotEqualTo:           return "<>"
        }
    }
}

/// A program is a sequence of numbered statements
typealias Program = [(Number, Statement)]

/// An input line is parsed to be a statement preceded by a line number,
/// which will be inserted into the program, or a statement without a preceding
/// line number, which will be executed immediately.
///
/// Also possible are empty input lines, which are ignored, or unparseable
/// input lines, which generate an error message.
enum Line {
    // Parsed statement with a line number
    case NumberedStatement(Number, Statement)

    // Parsed statement without a preceding line number
    case UnnumberedStatement(Statement)

    // Empty input line
    case Empty

    // Error occurred while parsing the line, resulting in error message
    case Error(String)
}
