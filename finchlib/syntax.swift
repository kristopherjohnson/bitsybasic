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

    /// "PRINT"
    /// "PR"
    /// "?"
    case PrintNewline

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

    /// "LIST" [ expression, [ expression ] ]
    case List(ListRange)

    /// "SAVE" filenamestring
    case Save(String)

    /// "LOAD" filenamestring
    case Load(String)

    /// "TRON"
    case Tron

    /// "TROFF"
    case Troff

    /// "BYE"
    case Bye
    
    /// Unable to parse input as statement
    case Error(String)


    /// Return pretty-printed statement
    var listText: String {
        switch self {

        case let .Print(printList):
            return "PRINT \(printList.listText)"

        case .PrintNewline:
            return "PRINT"

        case let .Input(varlist):
            return "INPUT \(varlist.listText)"

        case let .Let(varname, expr):
            return "LET \(stringFromChar(varname)) = \(expr.listText)"

        case let .Goto(expr):
            return "GOTO \(expr.listText)"

        case let .Gosub(expr):
            return "GOSUB \(expr.listText)"
            
        case .Return:
            return "RETURN"
            
        case let .If(lhs, relop, rhs, box):
            return "IF \(lhs.listText) \(relop.listText) \(rhs.listText) THEN \(box.value.listText)"

        case let .Rem(comment):
            return "REM\(comment)"

        case .Clear:
            return "CLEAR"

        case .End:
            return "END"

        case .Run:
            return "RUN"

        case let .List(range):
            return "LIST\(range.listText)"

        case let .Save(filename):
            return "SAVE \"\(filename)\""

        case let .Load(filename):
            return "LOAD \"\(filename)\""

        case .Tron:
            return "TRON"

        case .Troff:
            return "TROFF"

        case .Bye:
            return "BYE"
            
        case let .Error(message):
            return "statement error: \(message)"
        }
    }
}

/// Result of parsing a varlist
enum VarList {
    /// "A" | "B" | ... | "Y" | "Z"
    case Item(VariableName)

    /// var "," varlist
    case Items(VariableName, Box<VarList>)


    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Item(variableName):
            return stringFromChar(variableName)

        case let .Items(firstVarName, items):
            var result = stringFromChar(firstVarName)

            var x = items.value
            var done = false
            loop: while true {
                switch x {
                case let .Item(lastVarName):
                    result.extend(", \(stringFromChar(lastVarName))")
                    break loop
                case let .Items(variableName, box):
                    result.extend(", \(stringFromChar(variableName))")
                    x = box.value
                }
            }

            return result
        }
    }

    /// Return the variable names as an array
    var asArray: [VariableName] {
        switch self {
        case let .Item(variableName):
            return [variableName]

        case let .Items(firstVarName, items):
            var result = [firstVarName]

            var x = items.value
            var done = false
            loop: while true {
                switch x {
                case let .Item(lastVarName):
                    result.append(lastVarName)
                    break loop
                case let .Items(variableName, tail):
                    result.append(variableName)
                    x = tail.value
                }
            }

            return result
        }
    }
}

/// Protocol supported by elements that provide text for the PRINT statement
protocol PrintTextProvider {
    /// Return output text associated with this element
    func printText(v: VariableBindings) -> String
}

/// Result of parsing a printlist
enum PrintList {
    /// expression
    case Item(PrintItem, PrintListTerminator)

    /// expression "," exprlist
    case Items(PrintItem, PrintListSeparator, Box<PrintList>)


    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Item(printItem, terminator):
            return "\(printItem.listText)\(terminator.listText)"

        case let .Items(printItem, sep, printItems):
            var result = "\(printItem.listText)\(sep.listText) "

            var x = printItems.value
            loop: while true {
                switch x {
                case let .Item(item, terminator):
                    result.extend("\(item.listText)\(terminator.listText)")
                    break loop
                case let .Items(item, sep, box):
                    result.extend("\(item.listText)\(sep.listText) ")
                    x = box.value
                }
            }

            return result
        }
    }
}

/// Items in a PrintList can be separated by a comma, which causes a tab
/// character to be output between each character, or a semicolon, which
/// causes items to be printed with no separator.
enum PrintListSeparator: PrintTextProvider {
    case Tab
    case Empty

    /// Return text that should be included in output for this element
    func printText(v: VariableBindings) -> String {
        switch self {
        case .Tab:   return "\t"
        case .Empty: return ""
        }
    }

    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case .Tab:   return ","
        case .Empty: return ";"
        }
    }
}

/// A PrintList can end with a semicolon, indicating that there should
/// be no separation from subsequent PRINT output, with a comma,
/// indicating that a tab character should be the separator, or
/// with nothing, indicating that a newline character should terminate
/// the output.
enum PrintListTerminator: PrintTextProvider {
    case Newline
    case Tab
    case Empty

    /// Return text that should be included in output for this element
    func printText(v: VariableBindings) -> String {
        switch self {
        case .Newline: return "\n"
        case .Tab:     return "\t"
        case .Empty:   return ""
        }
    }

    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case .Newline: return ""
        case .Tab:     return ","
        case .Empty:   return ";"
        }
    }
}

/// Result of parsing an exprlist
enum PrintItem: PrintTextProvider {
    /// expression
    case Expr(Expression)

    /// '"' string '"'
    case Str([Char])

    /// Return text that should be included in output for this element
    func printText(v: VariableBindings) -> String {
        switch self {
        case let .Str(chars):       return stringFromChars(chars)
        case let .Expr(expression): return "\(expression.evaluate(v))"
        }
    }

    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Expr(expression): return expression.listText
        case let .Str(chars):       return "\"\(stringFromChars(chars))\""
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
    func evaluate(v: VariableBindings) -> Number {
        switch self {

        case let .UnsignedExpr(uexpr):
            return uexpr.evaluate(v)

        case let .Plus(uexpr):
            return uexpr.evaluate(v)

        case let .Minus(uexpr):
            // The leading minus sign must be applied to the
            // first term in the expression (not to the entire expression)
            switch uexpr {

            case .Value(_):
                return -(uexpr.evaluate(v))

            case let .Sum(term, remainder):
                let termValue = term.evaluate(v)
                return -termValue &+ remainder.value.evaluate(v)

            case let .Diff(term, remainder):
                let termValue = term.evaluate(v)
                return -termValue &- remainder.value.evaluate(v)
            }
        }
    }

    /// Return program text
    var listText: String {
        switch self {
        case let .UnsignedExpr(uexpr):
            return uexpr.listText

        case let .Plus(uexpr):
            return "+\(uexpr.listText)"

        case let .Minus(uexpr):
            return "-\(uexpr.listText)"
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
    func evaluate(v: VariableBindings) -> Number {
        switch self {

        case let .Value(term):
            return term.evaluate(v)

        case let .Sum(term, boxedExpr):
            let expr = boxedExpr.value
            return term.evaluate(v) &+ expr.evaluate(v)

        case let .Diff(term, boxedExpr):
            let expr = boxedExpr.value
            return term.evaluate(v) &- expr.evaluate(v)
        }
    }

    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Value(term):
            return term.listText

        case let .Sum(term, boxedExpr):
            return "\(term.listText) + \(boxedExpr.value.listText)"

        case let .Diff(term, boxedExpr):
            return "\(term.listText) - \(boxedExpr.value.listText)"
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
    func evaluate(v: VariableBindings) -> Number {
        switch self {

        case let .Value(factor):
            return factor.evaluate(v)

        case let .Product(factor, boxedTerm):
            let term = boxedTerm.value
            return factor.evaluate(v) &* term.evaluate(v)

        case let .Quotient(factor, boxedTerm):
            let term = boxedTerm.value
            let divisor = term.evaluate(v)
            if divisor == 0 {
                // TODO: signal a divide-by-zero error
                return 0
            }
            return factor.evaluate(v) &/ divisor
        }
    }

    /// Return pretty-printed program text
    var listText: String {
        switch self {

        case let .Value(factor):
            return factor.listText

        case let .Product(factor, boxedTerm):
            return "\(factor.listText) * \(boxedTerm.value.listText)"

        case let .Quotient(factor, boxedTerm):
            return "\(factor.listText) / \(boxedTerm.value.listText)"
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

    /// "RND(" expression ")"
    case Rnd(Box<Expression>)


    /// Return the value of this Term
    func evaluate(v: VariableBindings) -> Number {
        switch self {
        case let .Var(varname):    return v[varname] ?? 0
        case let .Num(number):     return number
        case let .ParenExpr(expr): return expr.value.evaluate(v)

        case let .Rnd(expr):
            let n = expr.value.evaluate(v)
            if n < 1 {
                // TODO: signal a runtime error?
                return 0
            }
            return Number(arc4random_uniform(UInt32(n)))
        }
    }

    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Var(varname):    return stringFromChar(varname)
        case let .Num(number):     return "\(number)"
        case let .ParenExpr(expr): return "(\(expr.value.listText))"
        case let .Rnd(expr):       return "RND(\(expr.value.listText))"
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
    var listText: String {
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

/// Range of lines for a LIST operation
enum ListRange {
    /// List all lines
    case All

    /// List a single line
    case SingleLine(Expression)

    /// List all lines within an inclusive range
    case Range(Expression, Expression)

    /// Return pretty-printed representation
    var listText: String {
        switch self {
        case .All:                  return ""
        case let .SingleLine(expr): return " \(expr.listText)"
        case let .Range(from, to):  return " \(from.listText), \(to.listText)"
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

    // Input line with only a line number
    case EmptyNumberedLine(Number)

    // Error occurred while parsing the line, resulting in error message
    case Error(String)
}
