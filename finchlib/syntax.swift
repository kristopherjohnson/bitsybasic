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

// Tokens

let T_Asterisk       = "*"
let T_At             = "@"
let T_Comma          = ","
let T_Equal          = "="
let T_LParen         = "("
let T_Minus          = "-"
let T_Plus           = "+"
let T_QuestionMark   = "?"
let T_RParen         = ")"
let T_Semicolon      = ";"
let T_Slash          = "/"
let T_Tick           = "'"

let T_Greater        = ">"
let T_GreaterOrEqual = ">="
let T_Less           = "<"
let T_LessOrEqual    = "<="
let T_NotEqual       = "<>"
let T_NotEqualAlt    = "><"

let T_BYE            = "BYE"
let T_CLEAR          = "CLEAR"
let T_DIM            = "DIM"
let T_END            = "END"
let T_GOSUB          = "GOSUB"
let T_GOTO           = "GOTO"
let T_HELP           = "HELP"
let T_IF             = "IF"
let T_IN             = "IN"
let T_INPUT          = "INPUT"
let T_LET            = "LET"
let T_LIST           = "LIST"
let T_LOAD           = "LOAD"
let T_LS             = "LS"
let T_PR             = "PR"
let T_PRINT          = "PRINT"
let T_REM            = "REM"
let T_RETURN         = "RETURN"
let T_RND            = "RND"
let T_RUN            = "RUN"
let T_SAVE           = "SAVE"
let T_THEN           = "THEN"
let T_TROFF          = "TROFF"
let T_TRON           = "TRON"


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
    case Input(LvalueList)

    /// "LET" lvalue "=" expression
    case Let(Lvalue, Expression)

    /// "DIM @(" expression ")"
    case DimArray(Expression)

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


    /// Return pretty-printed statement
    var listText: String {
        switch self {

        case let .Print(printList):
            return "\(T_PRINT) \(printList.listText)"

        case .PrintNewline:
            return T_PRINT

        case let .Input(varlist):
            return "\(T_INPUT) \(varlist.listText)"

        case let .Let(lvalue, expr):
            return "\(T_LET) \(lvalue.listText) \(T_Equal) \(expr.listText)"

        case let .DimArray(expr):
            return "\(T_DIM) \(T_At)\(T_LParen)\(expr.listText)\(T_RParen)"
            
        case let .Goto(expr):
            return "\(T_GOTO) \(expr.listText)"

        case let .Gosub(expr):
            return "\(T_GOSUB) \(expr.listText)"

        case .Return:
            return T_RETURN

        case let .If(lhs, relop, rhs, box):
            return "\(T_IF) \(lhs.listText) \(relop.listText) \(rhs.listText) \(T_THEN) \(box.value.listText)"

        case let .Rem(comment):
            return "\(T_REM)\(comment)"

        case .Clear:
            return T_CLEAR

        case .End:
            return T_END

        case .Run:
            return T_RUN

        case let .List(range):
            return "\(T_LIST)\(range.listText)"

        case let .Save(filename):
            return "\(T_SAVE) \"\(filename)\""

        case let .Load(filename):
            return "\(T_LOAD) \"\(filename)\""

        case .Tron:
            return T_TRON

        case .Troff:
            return T_TROFF

        case .Bye:
            return T_BYE

        case .Help:
            return T_HELP
        }
    }
}

/// An element that can be assigned a value with LET or INPUT
enum Lvalue {
    case Var(VariableName)
    case ArrayElement(Expression)

    var listText: String {
        switch self {
        case let Var(varname):       return stringFromChar(varname)
        case let ArrayElement(expr): return "@(\(expr.listText))"
        }
    }
}

/// Result of parsing a varlist
enum LvalueList {
    /// lvalue
    case Item(Lvalue)

    /// lvalue "," lvaluelist
    case Items(Lvalue, Box<LvalueList>)


    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Item(lvalue):
            return lvalue.listText

        case let .Items(firstLvalue, items):
            var result = firstLvalue.listText

            var next = items.value
            loop: while true {
                switch next {
                case let .Item(lastVarName):
                    result.extend(", \(lastVarName.listText)")
                    break loop
                case let .Items(lvalue, box):
                    result.extend(", \(lvalue.listText)")
                    next = box.value
                }
            }

            return result
        }
    }

    /// Return the lvalues as an array
    var asArray: [Lvalue] {
        switch self {
        case let .Item(lvalue):
            return [lvalue]

        case let .Items(firstLvalue, items):
            var result = [firstLvalue]

            var next = items.value
            loop: while true {
                switch next {
                case let .Item(lastLvalue):
                    result.append(lastLvalue)
                    break loop
                case let .Items(lvalue, tail):
                    result.append(lvalue)
                    next = tail.value
                }
            }

            return result
        }
    }
}

/// Protocol supported by elements that provide text for the PRINT statement
protocol PrintTextProvider {
    /// Return output text associated with this element
    func printText(v: VariableBindings, _ a: [Number]) -> String
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
    func printText(v: VariableBindings, _ a: [Number]) -> String {
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
    func printText(v: VariableBindings, _ a: [Number]) -> String {
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
    func printText(v: VariableBindings, _ a: [Number]) -> String {
        switch self {
        case let .Str(chars):       return stringFromChars(chars)
        case let .Expr(expression): return "\(expression.evaluate(v, a))"
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
            return "\(T_Plus)\(uexpr.listText)"

        case let .Minus(uexpr):
            return "\(T_Minus)\(uexpr.listText)"
        }
    }

    /// Return the value of the expression
    func evaluate(v: VariableBindings, _ a: [Number]) -> Number {
        switch self {

        case let .UnsignedExpr(uexpr):
            return uexpr.evaluate(v, a)

        case let .Plus(uexpr):
            return uexpr.evaluate(v, a)

        case let .Minus(uexpr):
            switch uexpr {

            case .Value(_):
                return -(uexpr.evaluate(v, a))

            case let .Compound(term, op, remainder):
                // Construct a new Expression with the first term negated, and evaluate that
                let termValue = term.evaluate(v, a)
                let negatedFactor = Factor.Num(-termValue)
                let negatedTerm = Term.Value(negatedFactor)
                let newExpr = Expression.UnsignedExpr(UnsignedExpression.Compound(negatedTerm, op, remainder))
                return newExpr.evaluate(v, a)
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

    static let Add      = ArithOp(fn: &+, listText: T_Plus)
    static let Subtract = ArithOp(fn: &-, listText: T_Minus)
    static let Multiply = ArithOp(fn: &*, listText: T_Asterisk)
    static let Divide   = ArithOp(fn: &/, listText: T_Slash)
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
    func evaluate(v: VariableBindings, _ a: [Number]) -> Number {

        switch self {
        case let .Value(t):
            return t.evaluate(v, a)

        case let .Compound(t, op, uexpr):
            var accumulator = t.evaluate(v, a)
            var lastOp = op

            var next = uexpr.value
            while true {
                switch next {
                case let .Value(lastTerm):
                    return lastOp.apply(accumulator, lastTerm.evaluate(v, a))

                case let .Compound(nextTerm, op, tail):
                    accumulator = lastOp.apply(accumulator, nextTerm.evaluate(v, a))
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
    func evaluate(v: VariableBindings, _ a: [Number]) -> Number {

        switch self {
        case let .Value(fact):
            return fact.evaluate(v, a)

        case let .Compound(fact, op, trm):
            var accumulator = fact.evaluate(v, a)
            var lastOp = op

            var next = trm.value
            while true {
                switch next {
                case let .Value(lastFact):
                    return lastOp.apply(accumulator, lastFact.evaluate(v, a))

                case let .Compound(fact, op, tail):
                    accumulator = lastOp.apply(accumulator, fact.evaluate(v, a))
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

    /// "@(" expression ")"
    case ArrayElement(Box<Expression>)

    /// number
    case Num(Number)

    /// "(" expression ")"
    case ParenExpr(Box<Expression>)

    /// "RND(" expression ")"
    case Rnd(Box<Expression>)


    /// Return pretty-printed program text
    var listText: String {
        switch self {
        case let .Var(varname):       return stringFromChar(varname)
        case let .ArrayElement(expr): return "@(\(expr.value.listText))"
        case let .Num(number):        return "\(number)"
        case let .ParenExpr(expr):    return "(\(expr.value.listText))"
        case let .Rnd(expr):          return "\(T_RND)(\(expr.value.listText))"
        }
    }

    /// Return the value of this Term
    func evaluate(v: VariableBindings, _ a: [Number]) -> Number {
        switch self {
        case let .Var(varname):       return v[varname] ?? 0
        case let .Num(number):        return number
        case let .ParenExpr(expr):    return expr.value.evaluate(v, a)

        case let .ArrayElement(expr):
            let index = expr.value.evaluate(v, a)
            let remainderIndex = index % a.count
            if remainderIndex < 0 {
                return a[a.count + remainderIndex]
            }
            else {
                return a[remainderIndex]
            }

        case let .Rnd(expr):
            let n = expr.value.evaluate(v, a)
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
        case .Less:           return T_Less
        case .Greater:        return T_Greater
        case .Equal:          return T_Equal
        case .LessOrEqual:    return T_LessOrEqual
        case .GreaterOrEqual: return T_GreaterOrEqual
        case .NotEqual:       return T_NotEqual
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
