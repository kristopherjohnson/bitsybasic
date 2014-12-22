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
        loop: while true {
            io.showPrompt(self)

            if let input = readInputLine() {
                processInput(input)
            }
            else {
                break loop
            }
        }
    }

    /// Parse an input line and execute it or add it to the program
    func processInput(input: InputLine) {
        let line = parseInputLine(input)

        switch line {
        case let .UnnumberedStatement(stmt):    execute(stmt)
        case let .NumberedStatement(num, stmt): insertLineIntoProgram(num, stmt)
        case .Empty:                            break
        case let .Error(message):               showError(message)
        }
    }


    // MARK: - Parsing

    func parseInputLine(input: InputLine) -> Line {
        let start = InputPosition(input, 0)

        let i = start.afterSpaces()

        // If there are no non-space characters, skip this line
        if i.isAtEndOfLine {
            return .Empty
        }

        // If line starts with a number, add the statement to the program
        if let (num, afterNum) = numberConstant(i) {
            let (stmt, afterStmt) = statement(afterNum)
            switch stmt {
            case .Error(let message):
                return .Error("line \(num): \(message)")

            default:
                if afterStmt.isRemainingLineEmpty {
                    return .NumberedStatement(num, stmt)
                }
                else {
                    return .Error("line \(num): error: unexpected characters following complete statement")
                }
            }
        }

        // Otherwise, try to execute statement immediately
        let (stmt, afterStmt) = statement(i)
        switch stmt {
        case .Error(let message):
            return .Error(message)

        default:
            if afterStmt.isRemainingLineEmpty {
                return .UnnumberedStatement(stmt)
            }
            else {
                return .Error("error: unexpected characters following complete statement")
            }
        }
    }


    /// Parse a statement
    ///
    /// Returns a parsed statement or Statement.Error, and position
    /// of character following the end of the parsed statement
    func statement(pos: InputPosition) -> (Statement, InputPosition) {
        // "PRINT" printList
        // "PR" printList
        // "?" printList"
        if let ((PRINT, plist), nextPos) = parse(pos, lit("PRINT"), printList) {
            return ((.Print(plist)), nextPos)
        }
        else if let ((PR, plist), nextPos) = parse(pos, lit("PR"), printList) {
            return ((.Print(plist)), nextPos)
        }
        else if let ((QMARK, plist), nextPos) = parse(pos, lit("?"), printList) {
            return ((.Print(plist)), nextPos)
        }

        // "LET" var = expression
        // var = expression
        if let ((LET, v, EQ, expr), nextPos) =
            parse(pos, lit("LET"), variableName, lit("="), expression)
        {
            return ((.Let(v, expr)), nextPos)
        }
        else if let ((v, EQ, expr), nextPos) =
            parse(pos, variableName, lit("="), expression)
        {
            return ((.Let(v, expr)), nextPos)
        }

        // "INPUT" varList
        // "IN" varList
        if let ((INPUT, vars), nextPos) = parse(pos, lit("INPUT"), varList) {
            return ((.Input(vars)), nextPos)
        }
        else if let ((INPUT, vars), nextPos) = parse(pos, lit("IN"), varList) {
            return ((.Input(vars)), nextPos)
        }

        // "IF" lhs relop rhs "THEN" statement
        // "IF" lhs relop rhs statement
        if let ((IF, lhs, op, rhs, THEN, stmt), nextPos) =
            parse(pos, lit("IF"), expression, relop, expression, lit("THEN"), statement)
        {
            return (.If(lhs, op, rhs, Box(stmt)), nextPos)
        }
        else if let ((IF, lhs, op, rhs, stmt), nextPos) =
            parse(pos, lit("IF"), expression, relop, expression, statement)
        {
            return (.If(lhs, op, rhs, Box(stmt)), nextPos)
        }

        // "GOTO" expression
        if let ((GOTO, expr), nextPos) = parse(pos, lit("GOTO"), expression) {
            return (.Goto(expr), nextPos)
        }

        // "GOSUB" expression
        if let ((GOSUB, expr), nextPos) = parse(pos, lit("GOSUB"), expression) {
            return (.Gosub(expr), nextPos)
        }

        // "RETURN"
        if let (RETURN, nextPos) = literal("RETURN", pos) {
            return (.Return, nextPos)
        }

        // "REM" commentstring
        if let ((REM, comment), nextPos) = parse(pos, lit("REM"), remainderOfLine) {
            return (.Rem(comment), nextPos)
        }

        // "LIST"
        if let (LIST, nextPos) = literal("LIST", pos) {
            return (.List, nextPos)
        }

        // "RUN"
        if let (RUN, nextPos) = literal("RUN", pos) {
            return (.Run, nextPos)
        }

        // "END"
        if let (END, nextPos) = literal("END", pos) {
            return (.End, nextPos)
        }

        // "CLEAR"
        if let (CLEAR, nextPos) = literal("CLEAR", pos) {
            return (.Clear, nextPos)
        }

        // "TRON"
        if let (TRON, nextPos) = literal("TRON", pos) {
            return (.Tron, nextPos)
        }

        // "TROFF"
        if let (TROFF, nextPos) = literal("TROFF", pos) {
            return (.Troff, nextPos)
        }

        return (.Error("error: not a valid statement"), pos)
    }

    /// Attempt to parse a PrintList.
    ///
    /// Returns PrintList and position of next character if successful.  Returns nil otherwise.
    func printList(pos: InputPosition) -> (PrintList, InputPosition)? {
        if let (item, afterItem) = printItem(pos) {

            if let (_, afterSep) = literal(",", afterItem) {
                // Parse remainder of line
                if let (tail, afterTail) = printList(afterSep) {
                    return (.Items(item, .Tab, Box(tail)), afterTail)
                }
                else if afterSep.isRemainingLineEmpty {
                    // trailing comma
                    return (.Item(item, .Tab), afterSep)
                }
            }
            else if let (_, afterSep) = literal(";", afterItem) {
                // Parse remainder of line
                if let (tail, afterTail) = printList(afterSep) {
                    return (.Items(item, .Empty, Box(tail)), afterTail)
                }
                else if afterSep.isRemainingLineEmpty {
                    // trailing semicolon
                    return (.Item(item, .Empty), afterSep)
                }
            }

            return (.Item(item, .Newline), afterItem)
        }

        return nil
    }

    /// Attempt to parse a PrintItem.
    ///
    /// Returns PrintItem and position of next character if successful.  Returns nil otherwise.
    func printItem(pos: InputPosition) -> (PrintItem, InputPosition)? {
        if let (chars, afterChars) = stringConstant(pos) {
            return (.Str(chars), afterChars)
        }

        if let (expression, afterExpr) = expression(pos) {
            return (.Expr(expression), afterExpr)
        }

        return nil
    }

    /// Attempt to parse a VarList.
    ///
    /// Returns VarList and position of next character if successful.  Returns nil otherwise.
    func varList(pos: InputPosition) -> (VarList, InputPosition)? {
        if let (item, afterItem) = variableName(pos) {

            if let (_, afterSep) = literal(",", afterItem) {
                // Parse remainder of line
                if let (tail, afterTail) = varList(afterSep) {
                    return (.Items(item, Box(tail)), afterTail)
                }
            }

            return (.Item(item), afterItem)
        }

        return nil
    }
    
    /// Attempt to parse an Expression.
    /// 
    /// Returns Expression and position of next character if successful.  Returns nil if not.
    func expression(pos: InputPosition) -> (Expression, InputPosition)? {
        if let ((PLUS, uexpr), nextPos) = parse(pos, lit("+"), unsignedExpression) {
            return (.Plus(uexpr), nextPos)
        }

        if let ((MINUS, uexpr), nextPos) = parse(pos, lit("-"), unsignedExpression) {
            return (.Minus(uexpr), nextPos)
        }

        if let (uexpr, nextPos) = unsignedExpression(pos) {
            return (.UnsignedExpr(uexpr), nextPos)
        }

        return nil
    }

    /// Attempt to parse an UnsignedExpression.
    ///
    /// Returns UnsignedExpression and position of next character if successful.  Returns nil if not.
    func unsignedExpression(pos: InputPosition) -> (UnsignedExpression, InputPosition)? {
        if let (t, afterTerm) = term(pos) {

            // If followed by "+", then it's addition
            if let ((PLUS, uexpr), afterExpr) = parse(afterTerm, lit("+"), unsignedExpression) {
                return (.Sum(t, Box(uexpr)), afterExpr)
            }

            // If followed by "-", then it's subtraction
            if let ((MINUS, uexpr), afterExpr) = parse(afterTerm, lit("-"), unsignedExpression) {
                return (.Diff(t, Box(uexpr)), afterExpr)
            }

            // Otherwise, just a simple term
            return (.Value(t), afterTerm)
        }

        return nil
    }

    /// Attempt to parse a Term.
    ///
    /// Returns Term and position of next character if successful.  Returns nil if not.
    func term(pos: InputPosition) -> (Term, InputPosition)? {
        if let (fact, afterFact) = factor(pos) {

            // If followed by "*", then it's a product
            if let ((MULT, t), afterTerm) = parse(afterFact, lit("*"), term) {
                return (.Product(fact, Box(t)), afterTerm)
            }

            // If followed by "/", then it's a quotient
            if let ((DIV, t), afterTerm) = parse(afterFact, lit("/"), term) {
                return (.Quotient(fact, Box(t)), afterTerm)
            }

            // Otherwise, just a simple term
            return (.Value(fact), afterFact)
        }

        return nil
    }

    /// Attempt to parse a Factor.  Returns Factor and position of next character if successful.  Returns nil if not.
    func factor(pos: InputPosition) -> (Factor, InputPosition)? {
        // number
        if let (num, afterNum) = numberConstant(pos) {
            return (.Num(num), afterNum)
        }

        // "RND(" expression ")"
        if let ((RND, expr, RPAREN), nextPos) = parse(pos, lit("RND("), expression, lit(")")) {
            return (.Rnd(Box(expr)), nextPos)
        }

        // "(" expression ")"
        if let ((LPAREN, expr, RPAREN), nextPos) = parse(pos, lit("("), expression, lit(")")) {
            return (.ParenExpr(Box(expr)), nextPos)
        }

        // variable
        if let (variableName, afterVar) = variableName(pos) {
            return (.Var(variableName), afterVar)
        }

        return nil
    }

    /// Determine whether the remainder of the line starts with a specified sequence of characters.
    ///
    /// If true, returns position of the character following the matched string. If false, returns nil.
    ///
    /// Matching is case-insensitive. Spaces in the input are ignored.
    func literal(s: String, _ pos: InputPosition) -> (String, InputPosition)? {
        let chars = charsFromString(s)
        var matchCount = 0
        var matchGoal = chars.count

        var i = pos
        loop: while (matchCount < matchGoal) && !i.isAtEndOfLine {
            let c = i.char
            i = i.next

            if c == Char_Space {
                continue loop
            }
            else if toUpper(c) == toUpper(chars[matchCount]) {
                ++matchCount
            }
            else {
                return nil
            }
        }

        if matchCount == matchGoal {
            return (s, i)
        }

        return nil
    }

    /// Curried variant of `literal()`, for use with `parse()`
    func lit(s: String)(pos: InputPosition) -> (String, InputPosition)? {
        return literal(s, pos)
    }

    /// Attempt to read an unsigned number from input.  If successful, returns
    /// parsed number and position of next input character.  If not, returns nil.
    func numberConstant(pos: InputPosition) -> (Number, InputPosition)? {
        var i = pos.afterSpaces()

        if i.isAtEndOfLine {
            return nil
        }

        if !isDigitChar(i.char) {
            // doesn't start with a digit
            return nil
        }

        var num = Number(i.char - Char_0)
        i = i.next
        loop: while !i.isAtEndOfLine {
            let c = i.char
            if isDigitChar(c) {
                num = (num &* 10) &+ Number(c - Char_0)
            }
            else if c != Char_Space {
                break loop
            }
            i = i.next
        }
        
        return (num, i)
    }

    /// Attempt to parse a string literal
    ///
    /// Returns characters and position of next character if successful.
    /// Returns nil otherwise.
    func stringConstant(pos: InputPosition) -> ([Char], InputPosition)? {
        var i = pos.afterSpaces()
        if !i.isAtEndOfLine {
            if i.char == Char_DQuote {
                i = i.next
                var stringChars: [Char] = []
                var foundTrailingDelim = false

                loop: while !i.isAtEndOfLine {
                    let c = i.char
                    i = i.next
                    if c == Char_DQuote {
                        foundTrailingDelim = true
                        break loop
                    }
                    else {
                        stringChars.append(c)
                    }
                }

                if foundTrailingDelim {
                    return (stringChars, i)
                }
            }
        }
        
        return nil
    }

    /// Attempt to read a variable name.
    ///
    /// Returns variable name and position of next input character on success, or nil otherwise.
    func variableName(pos: InputPosition) -> (VariableName, InputPosition)? {
        let i = pos.afterSpaces()
        if !pos.isAtEndOfLine {
            let c = i.char
            if isAlphabeticChar(c) {
                return (toUpper(c), i.next)
            }
        }

        return nil
    }

    /// Attempt to read a relational operator (=, <, >, <=, >=, <>, ><)
    ///
    /// Returns operator and position of next input character on success, or nil otherwise.
    func relop(pos: InputPosition) -> (Relop, InputPosition)? {
        let firstPos = pos.afterSpaces()
        if !firstPos.isAtEndOfLine {
            var result: Relop = .EqualTo

            let firstChar = firstPos.char
            switch firstChar {
            case Char_Equal:  result = .EqualTo
            case Char_LAngle: result = .LessThan
            case Char_RAngle: result = .GreaterThan
            default:          return nil
            }

            var afterPos = firstPos.next
            let nextPos = afterPos.afterSpaces()
            if !nextPos.isAtEndOfLine {
                let nextChar = nextPos.char
                switch (firstChar, nextChar) {

                case (Char_LAngle, Char_Equal):
                    result = .LessThanOrEqualTo
                    afterPos = nextPos.next

                case (Char_LAngle, Char_RAngle):
                    result = .NotEqualTo
                    afterPos = nextPos.next

                case (Char_RAngle, Char_Equal):
                    result = .GreaterThanOrEqualTo
                    afterPos = nextPos.next

                case (Char_RAngle, Char_LAngle):
                    result = .NotEqualTo
                    afterPos = nextPos.next

                default:
                    break
                }
            }


            return (result, afterPos)
        }

        return nil
    }

    /// Return the remaining characters in the line as a String
    func remainderOfLine(pos: InputPosition) -> (String, InputPosition)? {
        return (stringFromChars(pos.remainingChars), pos.endOfLine)
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
    func execute(stmt: Statement) {
        switch stmt {
        case let .Print(exprList):           PRINT(exprList)
        case let .Input(varList):            INPUT(varList)
        case let .Let(varName, expr):        LET(varName, expr)
        case let .If(lhs, relop, rhs, stmt): IF(lhs, relop, rhs, stmt)
        case let .Goto(expr):                GOTO(expr)
        case let .Gosub(expr):               GOSUB(expr)
        case .Return:                        RETURN()
        case .List:                          LIST()
        case .Run:                           RUN()
        case .End:                           END()
        case .Clear:                         CLEAR()
        case .Rem(_):                        break
        case .Tron:                          isTraceOn = true
        case .Troff:                         isTraceOn = false
        case let .Error(message):            abortRunWithErrorMessage(message)
        }
    }

    /// Execute PRINT statement
    func PRINT(plist: PrintList) {
        switch plist {
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
    func INPUT(varlist: VarList) {

        // TODO: Re-implement this as follows, so that it is more like other BASICs:
        //
        // - Display a "? " prompt before reading the input line (and provide means to suppress prompt)
        // - Keep prompting for input until valid data is received.  Don't abort on error
        // - Find a cleaner way to iterate through the variable list
        
        if let input = readInputLine() {
            let pos = InputPosition(input, 0)
            switch varlist {
            case let .Item(variableName):
                if let (expr, afterExpr) = expression(pos) {
                    v[variableName] = expr.evaluate(v)
                }
                else {
                    abortRunWithErrorMessage("error: INPUT - unable to parse expression")
                    return
                }

            case let .Items(firstVariableName, otherItems):
                if let (firstExpr, afterExpr) = expression(pos) {
                    v[firstVariableName] = firstExpr.evaluate(v)

                    var x = otherItems.value
                    var nextPos = afterExpr
                    loop: while true {
                        switch x {

                        case let .Item(lastVariableName):
                            if let (_, afterLastComma) = literal(",", nextPos) {
                                if let (lastExpr, afterLastExpr) = expression(afterLastComma) {
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
                            if let (_, afterThisComma) = literal(",", nextPos) {
                                if let (thisExpr, afterThisExpr) = expression(afterThisComma) {
                                    v[thisVariableName] = thisExpr.evaluate(v)

                                    x = tail.value
                                    nextPos = afterThisExpr
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
    func LET(variableName: VariableName, _ expression: Expression) {
        v[variableName] = expression.evaluate(v)
    }

    /// Execute IF statement
    func IF(lhs: Expression, _ relop: Relop, _ rhs: Expression, _ stmt: Box<Statement>) {
        if relop.isTrueForNumbers(lhs.evaluate(v), rhs.evaluate(v)) {
            execute(stmt.value)
        }
    }

    /// Execute LIST statement
    func LIST() {
        for (lineNumber, stmt) in program {
            print("\(lineNumber) \(stmt.listText)\n")
        }
    }

    /// Execute RUN statement
    func RUN() {
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
    func END() {
        isRunning = false
    }

    /// Execute GOTO statement
    func GOTO(expr: Expression) {
        let lineNumber = expr.evaluate(v)
        if let i = indexOfProgramLineWithNumber(lineNumber) {
            programIndex = i
            if !isRunning {
                doRunLoop()
            }
        }
        else {
            abortRunWithErrorMessage("error: GOTO \(lineNumber) - no line with that number")
        }
    }

    /// Execute GOSUB statement
    func GOSUB(expr: Expression) {
        let lineNumber = expr.evaluate(v)
        if let i = indexOfProgramLineWithNumber(lineNumber) {
            returnStack.append(programIndex)
            programIndex = i
            if !isRunning {
                doRunLoop()
            }
        }
        else {
            abortRunWithErrorMessage("error: GOSUB \(lineNumber) - no line with that number")
        }
    }

    /// Execute RETURN statement
    func RETURN() {
        if returnStack.count > 0 {
            programIndex = returnStack.last!
            returnStack.removeLast()
        }
        else {
            abortRunWithErrorMessage("error: RETURN - empty return stack")
        }
    }

    /// Reset the machine to initial state
    public func CLEAR() {
        clearProgram()
        clearReturnStack()
        clearVariables()
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

            let (lineNumber, stmt) = program[programIndex++]
            if isTraceOn {
                io.showDebugTrace(self, message: "[\(lineNumber)]")
            }
            execute(stmt)
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
        var lineBuffer = InputLine()

        if var c = io.getInputChar(self) {
            loop: while c != Char_Linefeed {
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
                    break loop
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
