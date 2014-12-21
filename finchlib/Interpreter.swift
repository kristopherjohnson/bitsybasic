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

/// Protocol implemented by object that provides I/O operations for an Interpreter
public protocol InterpreterIO {
    /// Return next input character, or nil if at end-of-file or an error occurs
    func getInputChar(interpreter: Interpreter) -> Char?

    /// Write specified output character
    func putOutputChar(interpreter: Interpreter, _ c: Char)

    /// Display the input prompt to the user
    func showPrompt(interpreter: Interpreter)

    /// Display error message to user
    func showError(interpreter: Interpreter, message: String)

    /// Display a debug trace message
    func showDebugTrace(interpreter: Interpreter, message: String)
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

    public func showDebugTrace(interpreter: Interpreter, message: String) {
        var chars = charsFromString(message)
        fwrite(chars, 1, UInt(chars.count), stdout)
        fflush(stdout)
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

    /// If true, print line numbers while program runs
    var isTraceOn = false


    /// Initialize, optionally passing in a custom InterpreterIO handler
    public init(interpreterIO: InterpreterIO = StandardIO()) {
        io = interpreterIO
        clearVariables()
    }

    /// Reset the machine to initial state
    public func clear() {
        clearProgram()
        clearReturnStack()
        clearVariables()
    }

    /// Set values of all variables to zero
    func clearVariables() {
        for varname in Char_A...Char_Z {
            v[varname] = 0
        }
    }

    /// Remove program from meory
    func clearProgram() {
        program = []
        programIndex = 0
        isRunning = false
    }

    /// Remove all items from the return stack
    func clearReturnStack() {
        returnStack = []
    }


    // MARK: - Top-level loop

    /// Display prompt and read input lines and interpret them until end of input
    public func interpretInputLines() {
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
        if let (number, afterNumber) = parseNumber(input, i) {
            let (statement, afterStatement) = parseStatement(input, afterNumber)
            switch statement {
            case .Error(let message):
                return .Error(message)

            default:
                if isRemainingLineEmpty(input, afterStatement) {
                    return .NumberedStatement(number, statement)
                }
                else {
                    return .Error("error: unexpected characters following complete statement")
                }
            }
        }

        // Otherwise, try to execute statement immediately
        let (statement, afterStatement) = parseStatement(input, i)
        switch statement {
        case .Error(let message):
            return .Error(message)

        default:
            if isRemainingLineEmpty(input, afterStatement) {
                return .UnnumberedStatement(statement)
            }
            else {
                return .Error("error: unexpected characters following complete statement")
            }
        }
    }

    /// Parse a statement
    ///
    /// Looks for a keyword at the start of the line, and then delegates
    /// to a keyword-specific function to parse whatever arguments belong
    /// with the keyword.
    ///
    /// Returns parsed statement (which may be a Statement.Error) and index
    /// of character following the end of the statement
    func parseStatement(input: InputLine, _ index: Int) -> (Statement, Int) {
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

        // "INPUT"
        if let nextIndex = parseLiteral("INPUT", input, index) {
            return parseInputArguments(input, nextIndex)
        }

        // "IN" is an abbreviation for "INPUT"
        if let nextIndex = parseLiteral("IN", input, index) {
            return parseInputArguments(input, nextIndex)
        }

        // "LET"
        if let nextIndex = parseLiteral("LET", input, index) {
            return parseLetArguments(input, nextIndex)
        }

        // "IF"
        if let nextIndex = parseLiteral("IF", input, index) {
            return parseIfArguments(input, nextIndex)
        }

        // "GOTO"
        if let nextIndex = parseLiteral("GOTO", input, index) {
            return parseGotoArguments(input, nextIndex)
        }

        // "GOSUB"
        if let nextIndex = parseLiteral("GOSUB", input, index) {
            return parseGosubArguments(input, nextIndex)
        }

        // "RETURN"
        if let nextIndex = parseLiteral("RETURN", input, index) {
            return (.Return, nextIndex)
        }

        // "REM"
        if let nextIndex = parseLiteral("REM", input, index) {
            return parseRemArguments(input, nextIndex)
        }

        // "LIST"
        if let nextIndex = parseLiteral("LIST", input, index) {
            return (.List, nextIndex)
        }

        // "RUN"
        if let nextIndex = parseLiteral("RUN", input, index) {
            return (.Run, nextIndex)
        }

        // "END"
        if let nextIndex = parseLiteral("END", input, index) {
            return (.End, nextIndex)
        }

        // "CLEAR"
        if let nextIndex = parseLiteral("CLEAR", input, index) {
            return (.Clear, nextIndex)
        }

        // "TRON"
        if let nextIndex = parseLiteral("TRON", input, index) {
            return (.Tron, nextIndex)
        }

        // "TROFF"
        if let nextIndex = parseLiteral("TROFF", input, index) {
            return (.Troff, nextIndex)
        }

        return (.Error("error: not a valid statement"), index)
    }

    /// Parse the arguments for a PRINT statement
    func parsePrintArguments(input: InputLine, _ index: Int) -> (Statement, Int) {
        if let (exprList, nextIndex) = parsePrintList(input, index) {
            return (.Print(exprList), nextIndex)
        }

        return (.Error("error: PRINT - invalid syntax"), index)
    }

    /// Parse the arguments for an INPUT statement
    func parseInputArguments(input: InputLine, _ index: Int) -> (Statement, Int) {
        if let (varList, nextIndex) = parseVarList(input, index) {
            return (.Input(varList), nextIndex)
        }

        return (.Error("error: INPUT - invalid syntax"), index)
    }
    
    /// Parse the arguments for a LET statement
    ///
    /// "LET" var "=" expression
    func parseLetArguments(input: InputLine, _ index: Int) -> (Statement, Int) {
        if let (varName, afterVar) = parseVariableName(input, index) {
            if let afterEq = parseLiteral("=", input, afterVar) {
                if let (expr, afterExpr) = parseExpression(input, afterEq) {
                    return (.Let(varName, expr), afterExpr)
                }
            }
        }

        return (.Error("error: LET - invalid syntax"), index)
    }

    /// Parse the arguments for a GOTO statement
    ///
    /// "GOTO" expression
    func parseGotoArguments(input: InputLine, _ index: Int) -> (Statement, Int) {
        if let (expr, afterExpr) = parseExpression(input, index) {
            return (.Goto(expr), afterExpr)
        }

        return (.Error("error: GOTO - invalid syntax"), index)
    }
    
    /// Parse the arguments for a GOSUB statement
    ///
    /// "GOSUB" expression
    func parseGosubArguments(input: InputLine, _ index: Int) -> (Statement, Int) {
        if let (expr, afterExpr) = parseExpression(input, index) {
            return (.Gosub(expr), afterExpr)
        }

        return (.Error("error: GOSUB - invalid syntax"), index)
    }
    
    /// Parse the arguments for an IF statement
    ///
    /// "IF" expression relop expression "THEN" statement
    func parseIfArguments(input: InputLine, _ index: Int) -> (Statement, Int) {
        if let (lhs, afterLhs) = parseExpression(input, index) {
            if let (relop, afterRelop) = parseRelop(input, afterLhs) {
                if let (rhs, afterRhs) = parseExpression(input, afterRelop) {
                    if let afterThen = parseLiteral("THEN", input, afterRhs) {
                        let (statement, afterStatement) = parseStatement(input, afterThen)
                        switch statement {
                        case .Error(_):
                            return (.Error("error: IF - invalid statement following THEN"), afterStatement)
                        default:
                            return (.If(lhs, relop, rhs, Box(statement)), afterStatement)
                        }
                    }
                }
            }
        }

        return (.Error("error: IF - invalid syntax"), index)
    }

    /// Parse the arguments for a REM statement
    ///
    /// "REM" commentstring
    func parseRemArguments(input: InputLine, _ index: Int) -> (Statement, Int) {
        let commentChars: [Char] = Array(input[index..<input.count])
        return (.Rem(stringFromChars(commentChars)), input.count)
    }

    /// Attempt to parse a PrintList.
    ///
    /// Returns PrintList and index of next character if successful.  Returns nil otherwise.
    func parsePrintList(input: InputLine, _ index: Int) -> (PrintList, Int)? {
        if let (item, nextIndex) = parsePrintItem(input, index) {

            if let afterSeparator = parseLiteral(",", input, nextIndex) {
                // Parse remainder of line
                if let (tail, afterTail) = parsePrintList(input, afterSeparator) {
                    return (.Items(item, .Tab, Box(tail)), afterTail)
                }
                else if isRemainingLineEmpty(input, afterSeparator) {
                    // trailing comma
                    return (.Item(item, .Tab), afterSeparator)
                }
            }
            else if let afterSeparator = parseLiteral(";", input, nextIndex) {
                // Parse remainder of line
                if let (tail, afterTail) = parsePrintList(input, afterSeparator) {
                    return (.Items(item, .Empty, Box(tail)), afterTail)
                }
                else if isRemainingLineEmpty(input, afterSeparator) {
                    // trailing semicolon
                    return (.Item(item, .Empty), afterSeparator)
                }
            }

            return (.Item(item, .Newline), nextIndex)
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

    /// Attempt to parse a VarList.
    ///
    /// Returns VarList and index of next character if successful.  Returns nil otherwise.
    func parseVarList(input: InputLine, _ index: Int) -> (VarList, Int)? {
        if let (item, nextIndex) = parseVariableName(input, index) {

            if let afterSeparator = parseLiteral(",", input, nextIndex) {
                // Parse remainder of line
                if let (tail, afterTail) = parseVarList(input, afterSeparator) {
                    return (.Items(item, Box(tail)), afterTail)
                }
            }

            return (.Item(item), nextIndex)
        }

        return nil
    }
    
    /// Attempt to parse an Expression.
    /// 
    /// Returns Expression and index of next character if successful.  Returns nil if not.
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

    /// Return true if there are no non-space characters at or following the
    /// specified index in the specified line
    func isRemainingLineEmpty(input: InputLine, _ index: Int) -> Bool {
        return skipSpaces(input, index) == input.count
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
            // TODO: Rather than appending element and re-sorting, it would
            // probably be more efficient to find the correct insertion location
            // and do an insert operation.

            program.append(lineNumber, statement)

            // Re-sort by line numbers
            program.sort { $0.0 < $1.0 }
        }
    }

    func indexOfProgramLineWithNumber(lineNumber: Number) -> Int? {
        for (index, element) in enumerate(program) {
            let (n, statement) = element
            if lineNumber == n {
                return index
            }
        }
        return nil
    }

    func getLastProgramLineNumber() -> Number {
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
        case let .Input(varList):           executeInput(varList)
        case let .Let(varName, expr):       executeLet(varName, expr)
        case let .If(lhs, relop, rhs, box): executeIf(lhs, relop, rhs, box)
        case let .Goto(expr):               executeGoto(expr)
        case let .Gosub(expr):              executeGosub(expr)
        case .Return:                       executeReturn()
        case .List:                         executeList()
        case .Run:                          executeRun()
        case .End:                          executeEnd()
        case .Clear:                        clear()
        case .Rem(_):                       break
        case .Tron:                         isTraceOn = true
        case .Troff:                        isTraceOn = false
        case let .Error(message):           abortRunWithErrorMessage(message)
        }
    }

    /// Execute PRINT statement
    func executePrint(printList: PrintList) {
        switch printList {
        case let .Item(item, terminator):
            print(item)
            print(terminator)

        case let .Items(item, sep, printList):
            // Print the first item
            print(item)
            print(sep)

            // Walk the list to print remaining items
            var remainder = printList.value
            loop: while true {
                switch remainder {
                case let .Item(item, terminator):
                    // last item
                    print(item)
                    print(terminator)
                    break loop
                case let .Items(head, sep, tail):
                    print(head)
                    print(sep)
                    remainder = tail.value
                }
            }
        }
    }

    /// Execute INPUT statement
    /// 
    /// All values must be on a single input line, separated by commas.
    func executeInput(varList: VarList) {
        if let input = readInputLine() {
            switch varList {
            case let .Item(variableName):
                if let (expr, afterExpr) = parseExpression(input, 0) {
                    v[variableName] = expr.evaluate(v)
                }
                else {
                    abortRunWithErrorMessage("error: INPUT - unable to parse expression")
                    return
                }

            case let .Items(firstVariableName, otherItems):
                if let (firstExpr, afterExpr) = parseExpression(input, 0) {
                    v[firstVariableName] = firstExpr.evaluate(v)

                    var x = otherItems.value
                    var nextIndex = afterExpr
                    loop: while true {
                        switch x {

                        case let .Item(lastVariableName):
                            if let afterLastComma = parseLiteral(",", input, nextIndex) {
                                if let (lastExpr, afterLastExpr) = parseExpression(input, afterLastComma) {
                                    v[lastVariableName] = lastExpr.evaluate(v)
                                }
                                else {
                                    abortRunWithErrorMessage("error: INPUT - unable to read expression")
                                    return
                                }
                            }
                            else {
                                abortRunWithErrorMessage("error: INPUT - expecting comma and additional expression")
                                return
                            }
                            break loop

                        case let .Items(thisVariableName, tail):
                            if let afterThisComma = parseLiteral(",", input, nextIndex) {
                                if let (thisExpr, afterThisExpr) = parseExpression(input, afterThisComma) {
                                    v[thisVariableName] = thisExpr.evaluate(v)

                                    x = tail.value
                                    nextIndex = afterThisExpr
                                }
                                else {
                                    abortRunWithErrorMessage("error: INPUT - unable to read all expressions")
                                    return
                                }
                            }
                            else {
                                abortRunWithErrorMessage("error: INPUT - expecting comma and additional expression")
                                return
                            }
                        }
                    }
                }
                else {
                    abortRunWithErrorMessage("error: INPUT - unable to parse expression")
                    return
                }
            }
        }
        else {
            abortRunWithErrorMessage("error: INPUT - unable to read input stream")
        }
    }

    /// Execute LET statement
    func executeLet(variableName: VariableName, _ expression: Expression) {
        v[variableName] = expression.evaluate(v)
    }

    /// Execute IF statement
    func executeIf(lhs: Expression, _ relop: Relop, _ rhs: Expression, _ boxedStatement: Box<Statement>) {
        if relop.isTrueForNumbers(lhs.evaluate(v), rhs.evaluate(v)) {
            execute(boxedStatement.value)
        }
    }

    /// Execute LIST statement
    func executeList() {
        for (lineNumber, statement) in program {
            print("\(lineNumber) \(statement.listText)\n")
        }
    }

    /// Execute RUN statement
    func executeRun() {
        if program.count == 0 {
            showError("error: RUN - no program in memory")
            return
        }

        programIndex = 0
        clearVariables()
        clearReturnStack()
        doRunLoop()
    }

    /// Execute END statement
    func executeEnd() {
        isRunning = false
    }

    /// Execute GOTO statement
    func executeGoto(expression: Expression) {
        let lineNumber = expression.evaluate(v)
        if let i = indexOfProgramLineWithNumber(lineNumber) {
            programIndex = i
            if !isRunning {
                doRunLoop()
            }
        }
        else {
            showError("error: GOTO \(lineNumber) - no line with that number")
        }
    }

    /// Execute GOSUB statement
    func executeGosub(expression: Expression) {
        let lineNumber = expression.evaluate(v)
        if let i = indexOfProgramLineWithNumber(lineNumber) {
            returnStack.append(programIndex)
            programIndex = i
            if !isRunning {
                doRunLoop()
            }
        }
        else {
            showError("error: GOTO \(lineNumber) - no line with that number")
        }
    }

    /// Execute RETURN statement
    func executeReturn() {
        if returnStack.count > 0 {
            programIndex = returnStack.last!
            returnStack.removeLast()
        }
        else {
            showError("error: RETURN - empty return stack")
        }
    }


    /// Starting at current program index, execute commands
    func doRunLoop() {
        isRunning = true
        while isRunning {
            if programIndex >= program.count {
                showError("error: RUN - program does not terminate with END")
                isRunning = false
                break
            }

            let (lineNumber, statement) = program[programIndex++]
            if isTraceOn {
                io.showDebugTrace(self, message: "[\(lineNumber)]")
            }
            execute(statement)
        }
    }

    /// Display error message and stop running
    ///
    /// Call this method if an unrecoverable error happens while executing a statement
    func abortRunWithErrorMessage(message: String) {
        showError(message)
        if isRunning {
            isRunning = false
            showError("abort: unrecoverable error")
        }
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

    /// Print an object that conforms to the PrintTextProvider protocol
    func print(p: PrintTextProvider) {
        print(p.printText(v))
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
