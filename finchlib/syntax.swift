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


let Token_Asterisk       = "*"
let Token_Comma          = ","
let Token_Equal          = "="
let Token_LParen         = "("
let Token_Minus          = "-"
let Token_Plus           = "+"
let Token_QuestionMark   = "?"
let Token_RParen         = ")"
let Token_Semicolon      = ";"
let Token_Slash          = "/"
let Token_Tick           = "'"

let Token_Greater        = ">"
let Token_GreaterOrEqual = ">="
let Token_Less           = "<"
let Token_LessOrEqual    = "<="
let Token_NotEqual       = "<>"
let Token_NotEqualAlt    = "><"

let Token_BYE            = "BYE"
let Token_CLEAR          = "CLEAR"
let Token_END            = "END"
let Token_GOSUB          = "GOSUB"
let Token_GOTO           = "GOTO"
let Token_HELP           = "HELP"
let Token_IF             = "IF"
let Token_IN             = "IN"
let Token_INPUT          = "INPUT"
let Token_LET            = "LET"
let Token_LIST           = "LIST"
let Token_LOAD           = "LOAD"
let Token_PR             = "PR"
let Token_PRINT          = "PRINT"
let Token_REM            = "REM"
let Token_RETURN         = "RETURN"
let Token_RND            = "RND"
let Token_RUN            = "RUN"
let Token_SAVE           = "SAVE"
let Token_THEN           = "THEN"
let Token_TROFF          = "TROFF"
let Token_TRON           = "TRON"


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
    case If(Expression, RelOp, Expression, Box<Statement>)

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

    /// "HELP"
    case Help

    /// Unable to parse input as statement
    case Error(String)


    /// Return pretty-printed statement
    var listText: String {
        switch self {

        case let .Print(printList):
            return "\(Token_PRINT) \(printList.listText)"

        case .PrintNewline:
            return Token_PRINT

        case let .Input(varlist):
            return "\(Token_INPUT) \(varlist.listText)"

        case let .Let(varname, expr):
            return "\(Token_LET) \(stringFromChar(varname)) \(Token_Equal) \(expr.listText)"

        case let .Goto(expr):
            return "\(Token_GOTO) \(expr.listText)"

        case let .Gosub(expr):
            return "\(Token_GOSUB) \(expr.listText)"

        case .Return:
            return Token_RETURN

        case let .If(lhs, relop, rhs, box):
            return "\(Token_IF) \(lhs.listText) \(relop.listText) \(rhs.listText) \(Token_THEN) \(box.value.listText)"

        case let .Rem(comment):
            return "\(Token_REM)\(comment)"

        case .Clear:
            return Token_CLEAR

        case .End:
            return Token_END

        case .Run:
            return Token_RUN

        case let .List(range):
            return "\(Token_LIST)\(range.listText)"

        case let .Save(filename):
            return "\(Token_SAVE) \"\(filename)\""

        case let .Load(filename):
            return "\(Token_LOAD) \"\(filename)\""

        case .Tron:
            return Token_TRON

        case .Troff:
            return Token_TROFF

        case .Bye:
            return Token_BYE

        case .Help:
            return Token_HELP

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


    /// Return program text
    var listText: String {
        switch self {
        case let .UnsignedExpr(uexpr):
            return uexpr.listText

        case let .Plus(uexpr):
            return "\(Token_Plus)\(uexpr.listText)"

        case let .Minus(uexpr):
            return "\(Token_Minus)\(uexpr.listText)"
        }
    }

    /// Return the value of the expression
    func evaluate(v: VariableBindings) -> Number {
        switch self {

        case let .UnsignedExpr(uexpr):
            return uexpr.evaluate(v)

        case let .Plus(uexpr):
            return uexpr.evaluate(v)

        case let .Minus(uexpr):
            switch uexpr {

            case .Value(_):
                return -(uexpr.evaluate(v))

            case let .Compound(term, op, remainder):
                // Construct a new Expression with the first term negated, and evaluate that
                let termValue = term.evaluate(v)
                let negatedFactor = Factor.Num(-termValue)
                let negatedTerm = Term.Value(negatedFactor)
                let newExpr = Expression.UnsignedExpr(UnsignedExpression.Compound(negatedTerm, op, remainder))
                return newExpr.evaluate(v)
            }
        }
    }
}

/// Binary operator for Numbers
struct ArithOp {

    let fn: (Number, Number) -> Number
    let listText: String

    func apply(lhs: Number, _ rhs: Number) -> Number {
        return fn(lhs, rhs)
    }

    static let Add      = ArithOp(fn: &+, listText: Token_Plus)
    static let Subtract = ArithOp(fn: &-, listText: Token_Minus)
    static let Multiply = ArithOp(fn: &*, listText: Token_Asterisk)
    static let Divide   = ArithOp(fn: &/, listText: Token_Slash)
}

/// Result of parsing an unsigned expression
///
/// Note that "unsigned" means "does not have a leading + or - sign".
/// It does not mean that the value is non-negative.
enum UnsignedExpression {
    /// term
    case Value(Term)

    /// term "+" unsignedexpression
    /// term "-" unsignedexpression
    case Compound(Term, ArithOp, Box<UnsignedExpression>)


    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Value(term):
            return term.listText

        case let .Compound(term, op, boxedExpr):
            return "\(term.listText) \(op.listText) \(boxedExpr.value.listText)"
        }
    }

    /// Evaluate the expression using the specified bindings
    func evaluate(v: VariableBindings) -> Number {

        switch self {
        case let .Value(t):
            return t.evaluate(v)

        case let .Compound(t, op, uexpr):
            var accumulator = t.evaluate(v)
            var lastOp = op

            var next = uexpr.value
            while true {
                switch next {
                case let .Value(lastTerm):
                    return lastOp.apply(accumulator, lastTerm.evaluate(v))

                case let .Compound(nextTerm, op, tail):
                    accumulator = lastOp.apply(accumulator, nextTerm.evaluate(v))
                    lastOp = op
                    next = tail.value
                }
            }
        }
    }
}

/// Result of parsing a term
enum Term {
    /// factor
    case Value(Factor)

    /// factor "*" term
    /// factor "/" term
    case Compound(Factor, ArithOp, Box<Term>)


    /// Return pretty-printed program text
    var listText: String {
        switch self {

        case let .Value(factor):
            return factor.listText

        case let .Compound(factor, op, boxedTerm):
            return "\(factor.listText) \(op.listText) \(boxedTerm.value.listText)"
        }
    }

    /// Evaluate the expression using the specified bindings
    func evaluate(v: VariableBindings) -> Number {

        switch self {
        case let .Value(fact):
            return fact.evaluate(v)

        case let .Compound(fact, op, trm):
            var accumulator = fact.evaluate(v)
            var lastOp = op

            var next = trm.value
            while true {
                switch next {
                case let .Value(lastFact):
                    return lastOp.apply(accumulator, lastFact.evaluate(v))

                case let .Compound(fact, op, tail):
                    accumulator = lastOp.apply(accumulator, fact.evaluate(v))
                    lastOp = op
                    next = tail.value
                }
            }
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


    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Var(varname):    return stringFromChar(varname)
        case let .Num(number):     return "\(number)"
        case let .ParenExpr(expr): return "(\(expr.value.listText))"
        case let .Rnd(expr):       return "\(Token_RND)(\(expr.value.listText))"
        }
    }

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
}

/// Result of parsing a relational operator
enum RelOp {
    /// "<"
    case Less

    /// ">"
    case Greater

    /// "="
    case Equal

    /// "<="
    case LessOrEqual

    /// ">="
    case GreaterOrEqual

    /// "<>" or "><"
    case NotEqual


    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case .Less:           return Token_Less
        case .Greater:        return Token_Greater
        case .Equal:          return Token_Equal
        case .LessOrEqual:    return Token_LessOrEqual
        case .GreaterOrEqual: return Token_GreaterOrEqual
        case .NotEqual:       return Token_NotEqual
        }
    }

    /// Determine whether the relation is true for specified values
    func isTrueForNumbers(lhs: Number, _ rhs: Number) -> Bool {
        switch self {
        case .Less:           return lhs < rhs
        case .Greater:        return lhs > rhs
        case .Equal:          return lhs == rhs
        case .LessOrEqual:    return lhs <= rhs
        case .GreaterOrEqual: return lhs >= rhs
        case .NotEqual:       return lhs != rhs
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
