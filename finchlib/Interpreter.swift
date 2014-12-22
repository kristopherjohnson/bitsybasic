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
                return .Error(message)

            default:
                if afterStmt.isRemainingLineEmpty {
                    return .NumberedStatement(num, stmt)
                }
                else {
                    return .Error("error: unexpected characters following complete statement")
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
    /// Looks for a keyword at the start of the line, and then delegates
    /// to a keyword-specific function to parse whatever arguments belong
    /// with the keyword.
    ///
    /// Returns parsed statement (which may be a Statement.Error) and index
    /// of character following the end of the statement
    func statement(pos: InputPosition) -> (Statement, InputPosition) {
        // "PRINT"
        if let nextPos = literal("PRINT", pos) {
            return parsePrintArguments(nextPos)
        }

        // "PR" is an abbreviation for "PRINT"
        if let nextPos = literal("PR", pos) {
            return parsePrintArguments(nextPos)
        }

        // "?" is a synonym for "PRINT"
        if let nextPos = literal("?", pos) {
            return parsePrintArguments(nextPos)
        }

        // "INPUT"
        if let nextPos = literal("INPUT", pos) {
            return parseInputArguments(nextPos)
        }

        // "IN" is an abbreviation for "INPUT"
        if let nextPos = literal("IN", pos) {
            return parseInputArguments(nextPos)
        }

        // "LET"
        if let nextPos = literal("LET", pos) {
            return parseLetArguments(nextPos)
        }

        // "IF"
        if let nextPos = literal("IF", pos) {
            return parseIfArguments(nextPos)
        }

        // "GOTO"
        if let nextPos = literal("GOTO", pos) {
            return parseGotoArguments(nextPos)
        }

        // "GOSUB"
        if let nextPos = literal("GOSUB", pos) {
            return parseGosubArguments(nextPos)
        }

        // "RETURN"
        if let nextPos = literal("RETURN", pos) {
            return (.Return, nextPos)
        }

        // "REM"
        if let nextPos = literal("REM", pos) {
            return parseRemArguments(nextPos)
        }

        // "LIST"
        if let nextPos = literal("LIST", pos) {
            return (.List, nextPos)
        }

        // "RUN"
        if let nextPos = literal("RUN", pos) {
            return (.Run, nextPos)
        }

        // "END"
        if let nextPos = literal("END", pos) {
            return (.End, nextPos)
        }

        // "CLEAR"
        if let nextPos = literal("CLEAR", pos) {
            return (.Clear, nextPos)
        }

        // "TRON"
        if let nextPos = literal("TRON", pos) {
            return (.Tron, nextPos)
        }

        // "TROFF"
        if let nextPos = literal("TROFF", pos) {
            return (.Troff, nextPos)
        }

        return (.Error("error: not a valid statement"), pos)
    }

    /// Parse the arguments for a PRINT statement
    func parsePrintArguments(pos: InputPosition) -> (Statement, InputPosition) {
        if let (exprList, afterExprList) = printList(pos) {
            return (.Print(exprList), afterExprList)
        }

        return (.Error("error: PRINT - invalid syntax"), pos)
    }

    /// Parse the arguments for an INPUT statement
    func parseInputArguments(pos: InputPosition) -> (Statement, InputPosition) {
        if let (varList, afterVarList) = varList(pos) {
            return (.Input(varList), afterVarList)
        }

        return (.Error("error: INPUT - invalid syntax"), pos)
    }
    
    /// Parse the arguments for a LET statement
    ///
    /// "LET" var "=" expression
    func parseLetArguments(pos: InputPosition) -> (Statement, InputPosition) {
        if let (varName, afterVar) = variableName(pos) {
            if let afterEq = literal("=", afterVar) {
                if let (expr, afterExpr) = expression(afterEq) {
                    return (.Let(varName, expr), afterExpr)
                }
            }
        }

        return (.Error("error: LET - invalid syntax"), pos)
    }

    /// Parse the arguments for a GOTO statement
    ///
    /// "GOTO" expression
    func parseGotoArguments(pos: InputPosition) -> (Statement, InputPosition) {
        if let (expr, afterExpr) = expression(pos) {
            return (.Goto(expr), afterExpr)
        }

        return (.Error("error: GOTO - invalid syntax"), pos)
    }
    
    /// Parse the arguments for a GOSUB statement
    ///
    /// "GOSUB" expression
    func parseGosubArguments(pos: InputPosition) -> (Statement, InputPosition) {
        if let (expr, afterExpr) = expression(pos) {
            return (.Gosub(expr), afterExpr)
        }

        return (.Error("error: GOSUB - invalid syntax"), pos)
    }
    
    /// Parse the arguments for an IF statement
    ///
    /// "IF" expression relop expression "THEN" statement
    func parseIfArguments(pos: InputPosition) -> (Statement, InputPosition) {
        if let (lhs, afterLhs) = expression(pos) {
            if let (relop, afterRelop) = relop(afterLhs) {
                if let (rhs, afterRhs) = expression(afterRelop) {
                    if let afterThen = literal("THEN", afterRhs) {
                        let (stmt, afterStmt) = statement(afterThen)
                        switch stmt {
                        case .Error(_):
                            return (.Error("error: IF - invalid statement following THEN"), afterStmt)
                        default:
                            return (.If(lhs, relop, rhs, Box(stmt)), afterStmt)
                        }
                    }
                }
            }
        }

        return (.Error("error: IF - invalid syntax"), pos)
    }

    /// Parse the arguments for a REM statement
    ///
    /// "REM" commentstring
    func parseRemArguments(pos: InputPosition) -> (Statement, InputPosition) {
        let commentChars = pos.remainingChars
        return (.Rem(stringFromChars(commentChars)), pos.endOfLine)
    }

    /// Attempt to parse a PrintList.
    ///
    /// Returns PrintList and index of next character if successful.  Returns nil otherwise.
    func printList(pos: InputPosition) -> (PrintList, InputPosition)? {
        if let (item, afterItem) = printItem(pos) {

            if let afterSeparator = literal(",", afterItem) {
                // Parse remainder of line
                if let (tail, afterTail) = printList(afterSeparator) {
                    return (.Items(item, .Tab, Box(tail)), afterTail)
                }
                else if afterSeparator.isRemainingLineEmpty {
                    // trailing comma
                    return (.Item(item, .Tab), afterSeparator)
                }
            }
            else if let afterSeparator = literal(";", afterItem) {
                // Parse remainder of line
                if let (tail, afterTail) = printList(afterSeparator) {
                    return (.Items(item, .Empty, Box(tail)), afterTail)
                }
                else if afterSeparator.isRemainingLineEmpty {
                    // trailing semicolon
                    return (.Item(item, .Empty), afterSeparator)
                }
            }

            return (.Item(item, .Newline), afterItem)
        }

        return nil
    }

    /// Attempt to parse a PrintItem.
    ///
    /// Returns PrintItem and index of next character if successful.  Returns nil otherwise.
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
    /// Returns VarList and index of next character if successful.  Returns nil otherwise.
    func varList(pos: InputPosition) -> (VarList, InputPosition)? {
        if let (item, afterItem) = variableName(pos) {

            if let afterSeparator = literal(",", afterItem) {
                // Parse remainder of line
                if let (tail, afterTail) = varList(afterSeparator) {
                    return (.Items(item, Box(tail)), afterTail)
                }
            }

            return (.Item(item), afterItem)
        }

        return nil
    }
    
    /// Attempt to parse an Expression.
    /// 
    /// Returns Expression and index of next character if successful.  Returns nil if not.
    func expression(pos: InputPosition) -> (Expression, InputPosition)? {
        var leadingPlus = false
        var leadingMinus = false
        var afterSign = pos

        if let afterPlus = literal("+", pos) {
            leadingPlus = true
            afterSign = afterPlus
        }
        else if let afterMinus = literal("-", pos) {
            leadingMinus = true
            afterSign = afterMinus
        }

        if let (uexpr, afterUexpr) = unsignedExpression(afterSign) {

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
    func unsignedExpression(pos: InputPosition) -> (UnsignedExpression, InputPosition)? {
        if let (term, afterTerm) = term(pos) {

            // If followed by "+", then it's addition
            if let afterOp = literal("+", afterTerm) {
                if let (uexpr, afterExpr) = unsignedExpression(afterOp) {
                    return (.Sum(term, Box(uexpr)), afterExpr)
                }
            }

            // If followed by "-", then it's subtraction
            if let afterOp = literal("-", afterTerm) {
                if let (uexpr, afterExpr) = unsignedExpression(afterOp) {
                    return (.Diff(term, Box(uexpr)), afterExpr)
                }
            }

            return (.Value(term), afterTerm)
        }

        return nil
    }

    /// Attempt to parse a Term.  Returns Term and index of next character if successful.  Returns nil if not.
    func term(pos: InputPosition) -> (Term, InputPosition)? {
        if let (fact, afterFact) = factor(pos) {

            // If followed by "*", then it's a multiplication
            if let afterOp = literal("*", afterFact) {
                if let (term, afterTerm) = term(afterOp) {
                    return (.Product(fact, Box(term)), afterTerm)
                }
            }

            // If followed by "/", then it's a quotient
            if let afterOp = literal("/", afterFact) {
                if let (term, afterTerm) = term(afterOp) {
                    return (.Quotient(fact, Box(term)), afterTerm)
                }
            }

            return (.Value(fact), afterFact)
        }

        return nil
    }

    /// Attempt to parse a Factor.  Returns Factor and index of next character if successful.  Returns nil if not.
    func factor(pos: InputPosition) -> (Factor, InputPosition)? {
        // number
        if let (num, afterNum) = numberConstant(pos) {
            return (.Num(num), afterNum)
        }

        // "RND(" expression ")"
        if let afterLParen = literal("RND(", pos) {
            if let (expr, afterExpr) = expression(afterLParen) {
                if let afterRParen = literal(")", afterExpr) {
                    return (.Rnd(Box(expr)), afterRParen)
                }
            }
        }

        // "(" expression ")"
        if let afterLParen = literal("(", pos) {
            if let (expr, afterExpr) = expression(afterLParen) {
                if let afterRParen = literal(")", afterExpr) {
                    return (.ParenExpr(Box(expr)), afterRParen)
                }
            }
        }

        // variable
        if let (variableName, afterVar) = variableName(pos) {
            return (.Var(variableName), afterVar)
        }

        return nil
    }

    /// Determine whether the remainder of the line starts with a specified sequence of characters.
    ///
    /// If true, returns index of the character following the matched string. If false, returns nil.
    ///
    /// Matching is case-insensitive. Spaces in the input are ignored.
    func literal(s: String, _ pos: InputPosition) -> InputPosition? {
        let chars = charsFromString(s)
        var matchCount = 0
        var matchGoal = chars.count

        var i = pos
        while (matchCount < matchGoal) && !i.isAtEndOfLine {
            let c = i.char
            i = i.next

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
    /// Returns characters and index of next character if successful.
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
    /// Returns variable name and index of next input character on success, or nil otherwise.
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
    /// Returns operator and index of next input character on success, or nil otherwise.
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
        case let .Print(exprList):          PRINT(exprList)
        case let .Input(varList):           INPUT(varList)
        case let .Let(varName, expr):       LET(varName, expr)
        case let .If(lhs, relop, rhs, box): IF(lhs, relop, rhs, box)
        case let .Goto(expr):               GOTO(expr)
        case let .Gosub(expr):              GOSUB(expr)
        case .Return:                       RETURN()
        case .List:                         LIST()
        case .Run:                          RUN()
        case .End:                          END()
        case .Clear:                        CLEAR()
        case .Rem(_):                       break
        case .Tron:                         isTraceOn = true
        case .Troff:                        isTraceOn = false
        case let .Error(message):           abortRunWithErrorMessage(message)
        }
    }

    /// Execute PRINT statement
    func PRINT(printList: PrintList) {
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
    func INPUT(varList: VarList) {
        if let input = readInputLine() {
            let pos = InputPosition(input, 0)
            switch varList {
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
                            if let afterLastComma = literal(",", nextPos) {
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
                            if let afterThisComma = literal(",", nextPos) {
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
    func IF(lhs: Expression, _ relop: Relop, _ rhs: Expression, _ boxedStatement: Box<Statement>) {
        if relop.isTrueForNumbers(lhs.evaluate(v), rhs.evaluate(v)) {
            execute(boxedStatement.value)
        }
    }

    /// Execute LIST statement
    func LIST() {
        for (lineNumber, statement) in program {
            print("\(lineNumber) \(statement.listText)\n")
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
    func GOTO(expression: Expression) {
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
    func GOSUB(expression: Expression) {
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
    func RETURN() {
        if returnStack.count > 0 {
            programIndex = returnStack.last!
            returnStack.removeLast()
        }
        else {
            showError("error: RETURN - empty return stack")
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
