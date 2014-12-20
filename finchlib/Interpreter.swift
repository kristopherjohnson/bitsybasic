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

/// Input is a "line" consisting of bytes
public typealias InputLine = [Char]


// MARK: - System I/O

/// Protocol implemented by object that provides I/O operations for a BasicInterpreter
public protocol InterpreterIO {
    /// Return next input character, or nil if at end-of-file or an error occurs
    func getInputChar(interpreter: Interpreter) -> Char?

    /// Write specified output character
    func putOutputChar(interpreter: Interpreter, _ c: Char)

    /// Display the input prompt to the user
    func showPrompt(interpreter: Interpreter)

    /// Display error message to user
    func showError(interpreter: Interpreter, message: String)
}

/// Default implementation of InterpreterIO that reads from stdin,
/// writes to stdout, and sends error messages to stderr.
public final class StandardIO: InterpreterIO {
    public func getInputChar(interpreter: Interpreter) -> Char? {
        let c = getchar()
        return c == EOF ? nil : Char(c)
    }

    public func putOutputChar(interpreter: Interpreter, _ c: Char) {
        putchar(Int32(c))
        fflush(stdin)
    }

    public func showPrompt(interpreter: Interpreter) {
        putchar(Int32(Char_Colon))
        fflush(stdin)
    }

    public func showError(interpreter: Interpreter, message: String) {
        var chars = charsFromString(message)
        chars.append(Char_Linefeed)
        fwrite(chars, 1, UInt(chars.count), stderr)
        fflush(stderr)
    }
}


// MARK: - Interpreter

/// Tiny Basic interpreter
public final class Interpreter {
    /// Variable values
    var v: VariableBindings = [:]

    /// Low-level I/O interface
    var io: InterpreterIO

    /// Set true while RUN is executing
    var isRunning = false

    /// Array of program lines
    var program: Program = []

    /// Index of currently executing line in program
    var programIndex: Int = 0

    /// Return stack
    var returnStack: [Int] = []


    /// Initialize, optionally passing in a custom BasicInterpreterIO handler
    public init(interpreterIO: InterpreterIO = StandardIO()) {
        io = interpreterIO
        clearVariables()
    }

    /// Set values of all variables to zero
    func clearVariables() {
        for varname in Char_A...Char_Z {
            v[varname] = 0
        }
    }


    // MARK: - Top-level loop

    /// Display prompt and read input lines and interpret them until end of input
    public func interpretInput() {
        while true {
            io.showPrompt(self)

            if let input = readInputLine() {
                processInput(input)
            }
            else {
                break
            }
        }
    }

    /// Parse an input line and execute it or add it to the program
    func processInput(input: InputLine) {
        let line = parseInputLine(input)

        switch line {
        case let .UnnumberedStatement(statement):       execute(statement)
        case let .NumberedStatement(number, statement): insertLineIntoProgram(number, statement)
        case .Empty:                                    break
        case let .Error(message):                       showError(message)
        }
    }


    // MARK: - Parsing

    // Most of the parsing functions take an InputLine argument, containing
    // the entire current line of input, and an index argument specifying the
    // current position in the line.
    //
    // The parsing functions generally have an Optional pair return type which
    // contains the parsed element and the index of the character following
    // whatever was parsed.  These functions return nil if unable to parse the
    // requested element.  This makes it easy for a parsing function to try
    // parsing different kinds of elements without consuming anything until
    // it succeeds.

    func parseInputLine(input: InputLine) -> Line {
        let count = input.count
        let i = skipSpaces(input, 0)

        // If there are no non-space characters, skip this line
        if i == count {
            return .Empty
        }

        // If line starts with a number, add the statement to the program
        if let (number, nextIndex) = parseNumber(input, i) {
            let statement = parseStatement(input, nextIndex)
            switch statement {
            case .Error(let message): return .Error(message)
            default:                  return .NumberedStatement(number, statement)
            }

        }

        // Otherwise, try to execute statement immediately
        let statement = parseStatement(input, i)
        switch statement {
        case .Error(let message): return .Error(message)
        default:                  return .UnnumberedStatement(statement)
        }
    }

    /// Parse a statement
    ///
    /// Looks for a keyword at the start of the line, and then delegates
    /// to a keyword-specific function to parse whatever arguments belong
    /// with the keyword.
    func parseStatement(input: InputLine, _ index: Int) -> Statement {
        // "PRINT"
        if let nextIndex = parseLiteral("PRINT", input, index) {
            return parsePrintArguments(input, nextIndex)
        }

        // "PR" is an abbreviation for "PRINT"
        if let nextIndex = parseLiteral("PR", input, index) {
            return parsePrintArguments(input, nextIndex)
        }

        // "?" is a synonym for "PRINT"
        if let nextIndex = parseLiteral("?", input, index) {
            return parsePrintArguments(input, nextIndex)
        }

        // "LET"
        if let nextIndex = parseLiteral("LET", input, index) {
            return parseLetArguments(input, nextIndex)
        }

        // "IF"
        if let nextIndex = parseLiteral("IF", input, index) {
            return parseIfArguments(input, nextIndex)
        }

        // "LIST"
        if let nextIndex = parseLiteral("LIST", input, index) {
            return .List
        }

        // "RUN"
        if let nextIndex = parseLiteral("RUN", input, index) {
            return .Run
        }

        // "END"
        if let nextIndex = parseLiteral("END", input, index) {
            return .End
        }

        return .Error("error: not a valid statement")
    }

    /// Parse the arguments for a PRINT statement
    func parsePrintArguments(input: InputLine, _ index: Int) -> Statement {
        if let (exprList, nextIndex) = parsePrintList(input, index) {
            return .Print(exprList)
        }

        return .Error("error: invalid syntax for PRINT")
    }

    /// Parse the arguments for a LET statement
    ///
    /// "LET" var "=" expression
    func parseLetArguments(input: InputLine, _ index: Int) -> Statement {

        if let (varName, afterVar) = parseVariableName(input, index) {
            if let afterEq = parseLiteral("=", input, afterVar) {
                if let (expr, afterExpr) = parseExpression(input, afterEq) {
                    return .Let(varName, expr)
                }
            }
        }
        return .Error("error: invalid syntax for LET")
    }

    /// Parse the arguments for an IF statement
    ///
    /// "IF" expression relop expression "THEN" statement
    func parseIfArguments(input: InputLine, _ index: Int) -> Statement {
        if let (lhs, afterLhs) = parseExpression(input, index) {
            if let (relop, afterRelop) = parseRelop(input, afterLhs) {
                if let (rhs, afterRhs) = parseExpression(input, afterRelop) {
                    if let afterThen = parseLiteral("THEN", input, afterRhs) {
                        let thenStatement = parseStatement(input, afterThen)
                        switch thenStatement {
                        case .Error(_): return .Error("error: invalid statement following THEN")
                        default:        return .If(lhs, relop, rhs, Box(thenStatement))
                        }
                    }
                }
            }
        }

        return .Error("error: invalid syntax for IF")
    }

    /// Attempt to parse an PrintList.
    ///
    /// Returns PrintList and index of next character if successful.  Returns nil otherwise.
    func parsePrintList(input: InputLine, _ index: Int) -> (PrintList, Int)? {
        if let (item, nextIndex) = parsePrintItem(input, index) {

            if let afterSeparator = parseLiteral(",", input, nextIndex) {
                // Parse remainder of line
                if let (tail, afterTail) = parsePrintList(input, afterSeparator) {
                    return (.Items(item, Box(tail)), afterTail)
                }
            }

            return (.Item(item), nextIndex)
        }

        return nil
    }

    /// Attempt to parse a PrintItem.
    ///
    /// Returns PrintItem and index of next character if successful.  Returns nil otherwise.
    func parsePrintItem(input: InputLine, _ index: Int) -> (PrintItem, Int)? {
        if let (chars, nextIndex) = parseString(input, index) {
            return (.Str(chars), nextIndex)
        }

        if let (expression, nextIndex) = parseExpression(input, index) {
            return (.Expr(expression), nextIndex)
        }

        return nil
    }

    /// Attempt to parse an Expression.  Returns Expression and index of next character if successful.  Returns nil if not.
    func parseExpression(input: InputLine, _ index: Int) -> (Expression, Int)? {
        var leadingPlus = false
        var leadingMinus = false
        var afterSign = index

        if let nextIndex = parseLiteral("+", input, index) {
            leadingPlus = true
            afterSign = nextIndex
        }
        else if let nextIndex = parseLiteral("-", input, index) {
            leadingMinus = true
            afterSign = nextIndex
        }

        if let (uexpr, afterUexpr) = parseUnsignedExpression(input, afterSign) {

            if leadingPlus {
                return (.Plus(uexpr), afterUexpr)
            }

            if leadingMinus {
                return (.Minus(uexpr), afterUexpr)
            }

            return (.UnsignedExpr(uexpr), afterUexpr)
        }

        return nil
    }

    /// Attempt to parse an UnsignedExpression.  Returns UnsignedExpression and index of next character if successful.  Returns nil if not.
    func parseUnsignedExpression(input: InputLine, _ index: Int) -> (UnsignedExpression, Int)? {
        if let (term, nextIndex) = parseTerm(input, index) {

            // If followed by "+", then it's addition
            if let afterOp = parseLiteral("+", input, nextIndex) {
                if let (uexpr, afterTerm) = parseUnsignedExpression(input, afterOp) {
                    return (.Sum(term, Box(uexpr)), afterTerm)
                }
            }

            // If followed by "-", then it's subtraction
            if let afterOp = parseLiteral("-", input, nextIndex) {
                if let (uexpr, afterTerm) = parseUnsignedExpression(input, afterOp) {
                    return (.Diff(term, Box(uexpr)), afterTerm)
                }
            }

            return (.Value(term), nextIndex)
        }

        return nil
    }

    /// Attempt to parse a Term.  Returns Term and index of next character if successful.  Returns nil if not.
    func parseTerm(input: InputLine, _ index: Int) -> (Term, Int)? {
        if let (factor, nextIndex) = parseFactor(input, index) {

            // If followed by "*", then it's a multiplication
            if let afterOp = parseLiteral("*", input, nextIndex) {
                if let (term, afterTerm) = parseTerm(input, afterOp) {
                    return (.Product(factor, Box(term)), afterTerm)
                }
            }

            // If followed by "/", then it's a quotient
            if let afterOp = parseLiteral("/", input, nextIndex) {
                if let (term, afterTerm) = parseTerm(input, afterOp) {
                    return (.Quotient(factor, Box(term)), afterTerm)
                }
            }

            return (.Value(factor), nextIndex)
        }

        return nil
    }

    /// Attempt to parse a Factor.  Returns Factor and index of next character if successful.  Returns nil if not.
    func parseFactor(input: InputLine, _ index: Int) -> (Factor, Int)? {
        // number
        if let (number, nextIndex) = parseNumber(input, index) {
            return (.Num(number), nextIndex)
        }

        // "(" expression ")"
        if let afterLParen = parseLiteral("(", input, index) {
            if let (expr, afterExpr) = parseExpression(input, afterLParen) {
                if let afterRParen = parseLiteral(")", input, afterExpr) {
                    return (.ParenExpr(Box(expr)), afterRParen)
                }
            }
        }

        // variable
        if let (variableName, nextIndex) = parseVariableName(input, index) {
            return (.Var(variableName), nextIndex)
        }

        return nil
    }

    /// Determine whether the remainder of the line starts with a specified sequence of characters.
    ///
    /// If true, returns index of the character following the matched string. If false, returns nil.
    ///
    /// Matching is case-insensitive. Spaces in the input are ignored.
    func parseLiteral(literal: String, _ input: InputLine, _ index: Int) -> Int? {
        let chars = charsFromString(literal)
        var matchCount = 0
        var matchGoal = chars.count

        let n = input.count
        var i = index
        while (matchCount < matchGoal) && (i < n) {
            let c = input[i++]

            if c == Char_Space {
                continue
            }
            else if toUpper(c) == toUpper(chars[matchCount]) {
                ++matchCount
            }
            else {
                return nil
            }
        }

        if matchCount == matchGoal {
            return i
        }

        return nil
    }

    /// Attempt to read an unsigned number from input.  If successful, returns
    /// parsed number and index of next input character.  If not, returns nil.
    func parseNumber(input: InputLine, _ index: Int) -> (Number, Int)? {
        var i = skipSpaces(input, index)

        let count = input.count
        if i == count {
            // at end of input
            return nil
        }

        if !isDigitChar(input[i]) {
            // doesn't start with a digit
            return nil
        }

        var number = Number(input[i++] - Char_0)
        while i < count {
            let c = input[i]
            if isDigitChar(c) {
                number = (number &* 10) &+ Number(c - Char_0)
            }
            else if c != Char_Space {
                break
            }
            ++i
        }
        
        return (number, i)
    }

    /// Attempt to parse a string literal
    ///
    /// Returns characters and index of next character if successful.
    /// Returns nil otherwise.
    func parseString(input: InputLine, _ index: Int) -> ([Char], Int)? {
        let count = input.count
        var i = skipSpaces(input, index)
        if i < count {
            if input[i] == Char_DQuote {
                ++i
                var stringChars: [Char] = []
                var foundEnd = false

                while i < count {
                    let c = input[i++]
                    if c == Char_DQuote {
                        foundEnd = true
                        break
                    }
                    else {
                        stringChars.append(c)
                    }
                }

                if foundEnd {
                    return (stringChars, i)
                }
            }
        }
        
        return nil
    }

    /// Attempt to read a variable name.
    ///
    /// Returns variable name and index of next input character on success, or nil otherwise.
    func parseVariableName(input: InputLine, _ index: Int) -> (VariableName, Int)? {
        let count = input.count
        let i = skipSpaces(input, index)
        if i < count {
            let c = input[i]
            if isAlphabeticChar(c) {
                return (toUpper(c), i + 1)
            }
        }

        return nil
    }

    /// Attempt to read a relational operator (=, <, >, <=, >=, <>, ><)
    ///
    /// Returns operator and index of next input character on success, or nil otherwise.
    func parseRelop(input: InputLine, _ index: Int) -> (Relop, Int)? {
        let count = input.count
        let firstIndex = skipSpaces(input, index)
        if firstIndex < count {
            var relop: Relop = .EqualTo
            var after = index
            
            let c = input[firstIndex]
            switch c {
            case Char_Equal:  relop = .EqualTo
            case Char_LAngle: relop = .LessThan
            case Char_RAngle: relop = .GreaterThan
            default:          return nil
            }
            after = firstIndex + 1

            if firstIndex < (count - 1) {
                let nextIndex = skipSpaces(input, firstIndex + 1)
                if nextIndex < count {
                    let next = input[nextIndex]
                    switch (c, next) {

                    case (Char_LAngle, Char_Equal):
                        relop = .LessThanOrEqualTo
                        after = nextIndex + 1

                    case (Char_LAngle, Char_RAngle):
                        relop = .NotEqualTo
                        after = nextIndex + 1

                    case (Char_RAngle, Char_Equal):
                        relop = .GreaterThanOrEqualTo
                        after = nextIndex + 1

                    case (Char_RAngle, Char_LAngle):
                        relop = .NotEqualTo
                        after = nextIndex + 1

                    default:
                        break
                    }
                }
            }

            return (relop, after)
        }

        return nil
    }

    /// Return index of first non-space character at or after specified index
    func skipSpaces(input: InputLine, _ index: Int) -> Int {
        var i = index
        let count = input.count
        while i < count && input[i] == Char_Space {
            ++i
        }
        return i
    }


    // MARK: - Program editing

    func insertLineIntoProgram(lineNumber: Number, _ statement: Statement) {
        if let replaceIndex = indexOfProgramLineWithNumber(lineNumber) {
            program[replaceIndex] = (lineNumber, statement)
        }
        else if lineNumber > getLastProgramLineNumber() {
            program.append(lineNumber, statement)
        }
        else {
            program.append(lineNumber, statement)
            program.sort { lhs, rhs in
                return lhs.0 < rhs.0
            }
        }
    }

    func indexOfProgramLineWithNumber(lineNumber: Int) -> Int? {
        for (index, element) in enumerate(program) {
            let (n, statement) = element
            if lineNumber == n {
                return index
            }
        }
        return nil
    }

    func getLastProgramLineNumber() -> Int {
        if program.count > 0 {
            let (lineNumber, _) = program.last!
            return lineNumber
        }

        return 0
    }


    // MARK: - Execution

    /// Execute the given statement
    func execute(statement: Statement) {
        switch statement {
        case let .Print(exprList):          executePrint(exprList)
        case let .Let(varName, expr):       executeLet(varName, expr)
        case let .If(lhs, relop, rhs, box): executeIf(lhs, relop, rhs, box)
        case .List:                         executeList()
        case .Run:                          executeRun()
        case .End:                          executeEnd()
        default:                            showError("error: unimplemented statement type")
        }
    }

    /// Execute PRINT with the specified arguments
    func executePrint(printList: PrintList) {
        switch printList {
        case .Item(let item):
            print(item)

        case .Items(let item, let printList):
            // Print the first item
            print(item)

            // Walk the list to print remaining items
            var remainder = printList.boxedValue
            var done = false
            while !done {
                switch remainder {
                case .Item(let item):
                    // last item
                    print(Char_Tab)
                    print(item)
                    done = true
                case .Items(let head, let tail):
                    print(Char_Tab)
                    print(head)
                    remainder = tail.boxedValue
                }
            }
        }

        print(Char_Linefeed)
    }

    func executeLet(variableName: VariableName, _ expression: Expression) {
        v[variableName] = expression.getValue(v)
    }

    func executeIf(lhs: Expression, _ relop: Relop, _ rhs: Expression, _ boxedStatement: Box<Statement>) {
        if relop.isTrueForNumbers(lhs.getValue(v), rhs.getValue(v)) {
            execute(boxedStatement.boxedValue)
        }
    }

    func executeList() {
        for (lineNumber, statement) in program {
            print("\(lineNumber) \(statement.text)\n")
        }
    }

    func executeRun() {
        if program.count == 0 {
            showError("error: no program in memory")
        }

        programIndex = 0
        clearVariables()
        isRunning = true
        while isRunning {
            if programIndex >= program.count {
                showError("error: program does not terminate with END")
                isRunning = false
                break
            }

            let (lineNumber, statement) = program[programIndex++]
            execute(statement)
        }
    }

    func executeEnd() {
        isRunning = false
    }


    // MARK: - I/O

    /// Send a single character to the output stream
    func print(c: Char) {
        io.putOutputChar(self, c)
    }

    /// Send characters to the output stream
    func print(chars: [Char]) {
        for c in chars {
            io.putOutputChar(self, c)
        }
    }

    /// Send string to the output stream
    func print(s: String) {
        return print(charsFromString(s))
    }

    /// Print a PrintItem
    func print(printItem: PrintItem) {
        switch (printItem) {

        case .Str(let chars):
            print(chars)

        case .Expr(let expression):
            let value = expression.getValue(v)
            let stringValue = "\(value)"
            let chars = charsFromString(stringValue)
            print(chars)
        }
    }

    /// Display error message
    func showError(message: String) {
        io.showError(self, message: message)
    }

    /// Read a line of input.  Return array of characters, or nil if at end of input stream.
    ///
    /// Result does not include any non-graphic characters that were in the input stream.
    /// Any horizontal tab ('\t') in the input will be converted to a single space.
    ///
    /// Result may be an empty array, indicating an empty input line, not end of input.
    func readInputLine() -> InputLine? {
        var lineBuffer: InputLine = Array()

        if var c = io.getInputChar(self) {
            while c != Char_Linefeed {
                if isGraphicChar(c) {
                    lineBuffer.append(c)
                }
                else if c == Char_Tab {
                    // Convert tabs to spaces
                    lineBuffer.append(Char_Space)
                }

                if let nextChar = io.getInputChar(self) {
                    c = nextChar
                }
                else {
                    // Hit EOF, so return what we've read up to now
                    break
                }
            }
        }
        else {
            // No characters to read
            return nil
        }

        return lineBuffer
    }
}
