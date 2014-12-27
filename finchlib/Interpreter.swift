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

    /// Array of numbers, addressable using the syntax "@(i)"
    var a: [Number] = Array(count: 1024, repeatedValue: 0)

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
        clearVariablesAndArray()
    }

    /// Set values of all variables and array elements to zero
    func clearVariablesAndArray() {
        for varname in Ch_A...Ch_Z {
            v[varname] = 0
        }
        for i in 0..<a.count {
            a[i] = 0
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
            io.showCommandPrompt(self)

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
        case let .EmptyNumberedLine(num):       deleteLineFromProgram(num)
        case .Empty:                            break
        case let .Error(message):               showError(message)
        }
    }


    // MARK: - Parsing

    func parseInputLine(input: InputLine) -> Line {
        let start = InputPosition(input, 0)

        let afterSpaces = start.afterSpaces()

        // If there are no non-space characters, skip this line
        if afterSpaces.isAtEndOfLine {
            return .Empty
        }

        // If line starts with a number, add the statement to the program
        if let (num, afterNum) = numberLiteral(afterSpaces) {
            if afterNum.isRemainingLineEmpty {
                return .EmptyNumberedLine(num)
            }

            if let (stmt, afterStmt) = statement(afterNum) {
                if afterStmt.isRemainingLineEmpty {
                    return .NumberedStatement(num, stmt)
                }
                else {
                    return .Error("line \(num): error: unexpected characters following complete statement")
                }
            }
            else {
                return .Error("line \(num): error: not a valid statement")
            }
        }

        // Otherwise, try to execute statement immediately
        if let (stmt, afterStmt) = statement(afterSpaces) {
            if afterStmt.isRemainingLineEmpty {
                return .UnnumberedStatement(stmt)
            }
            else {
                return .Error("error: unexpected characters following complete statement")
            }
        }
        else {
            return .Error("error: not a valid statement")
        }
    }


    /// Parse a statement
    ///
    /// Returns a parsed statement or Statement.Error, and position
    /// of character following the end of the parsed statement
    func statement(pos: InputPosition) -> (Statement, InputPosition)? {

        // "PRINT" [ printList ]
        // "PR" [ printList ]
        // "?" [ printList" ]
        if let (PRINT, afterKeyword) = oneOfLit(T_PRINT, T_PR, T_QuestionMark)(pos: pos) {
            if let (plist, afterPrintList) = printList(afterKeyword) {
                return (.Print(plist), afterPrintList)
            }
            else {
                return (.PrintNewline, afterKeyword)
            }
        }

        // "LET" lvalue = expression
        // lvalue = expression
        if let ((LET, v, EQ, expr), nextPos) =
            parse(pos, optLit(T_LET), lvalue, lit(T_Equal), expression)
        {
            return (.Let(v, expr), nextPos)
        }

        // "INPUT" lvalueList
        // "IN" lvalueList
        if let ((INPUT, lvalues), nextPos) =
            parse(pos, oneOfLit(T_INPUT, T_IN), lvalueList)
        {
            return (.Input(lvalues), nextPos)
        }

        // "DIM @(" expr ")"
        if let ((DIM, AT, LPAREN, expr, RPAREN), nextPos) =
            parse(pos, lit(T_DIM), lit(T_At), lit(T_LParen), expression, lit(T_RParen))
        {
            return (.DimArray(expr), nextPos)
        }

        // "IF" lhs relop rhs "THEN" statement
        // "IF" lhs relop rhs statement
        if let ((IF, lhs, op, rhs, THEN, stmt), nextPos) =
            parse(pos, lit(T_IF), expression, relop, expression, optLit(T_THEN), statement)
        {
            return (.If(lhs, op, rhs, Box(stmt)), nextPos)
        }

        // "GOTO" expression
        if let ((GOTO, expr), nextPos) =
            parse(pos, lit(T_GOTO), expression)
        {
            return (.Goto(expr), nextPos)
        }

        // "GOSUB" expression
        if let ((GOSUB, expr), nextPos) =
            parse(pos, lit(T_GOSUB), expression)
        {
            return (.Gosub(expr), nextPos)
        }

        // "REM" commentstring
        // "'" commentstring
        if let ((REM, comment), nextPos) =
            parse(pos, oneOfLit(T_REM, T_Tick), remainderOfLine)
        {
            return (.Rem(comment), nextPos)
        }

        // "LIST"
        // "LIST" expression
        // "LIST" expression "," expression
        //
        // We allow "LS" as an undocumented synonym for "LIST", because
        // Kris is stupid and always types "LS".
        if let ((LIST, from, COMMA, to), nextPos) =
            parse(pos, oneOfLit(T_LIST, T_LS), expression, lit(T_Comma), expression)
        {
            return (.List(.Range(from, to)), nextPos)
        }
        else if let ((LIST, lineNumber), nextPos) =
            parse(pos, oneOfLit(T_LIST, T_LS), expression)
        {
            return (.List(.SingleLine(lineNumber)), nextPos)
        }
        else if let (LIST, nextPos) = oneOfLiteral([T_LIST, T_LS], pos)
        {
            return (.List(.All), nextPos)
        }

        // "SAVE" filenamestring
        if let ((SAVE, filename), nextPos) =
            parse(pos, lit(T_SAVE), stringLiteral)
        {
            return (.Save(stringFromChars(filename)), nextPos)
        }

        // "LOAD" filenamestring
        if let ((LOAD, filename), nextPos) =
            parse(pos, lit(T_LOAD), stringLiteral)
        {
            return (.Load(stringFromChars(filename)), nextPos)
        }

        // For statements that consist only of a keyword, we can use a simple table
        let simpleStatements: [(String, Statement)] = [
            (T_RETURN, .Return),
            (T_RUN,    .Run   ),
            (T_END,    .End   ),
            (T_CLEAR,  .Clear ),
            (T_BYE,    .Bye   ),
            (T_TRON,   .Tron  ),
            (T_TROFF,  .Troff ),
            (T_HELP,   .Help  )
        ]
        for (token, stmt) in simpleStatements {
            if let (TOKEN, nextPos) = literal(token, pos) {
                return (stmt, nextPos)
            }
        }

        return nil
    }

    /// Attempt to parse a PrintList.
    ///
    /// Returns PrintList and position of next character if successful.  Returns nil otherwise.
    func printList(pos: InputPosition) -> (PrintList, InputPosition)? {
        if let (item, afterItem) = printItem(pos) {

            if let (_, afterSep) = literal(T_Comma, afterItem) {
                // "," printList
                // "," (trailing at end of line)

                if let (tail, afterTail) = printList(afterSep) {
                    return (.Items(item, .Tab, Box(tail)), afterTail)
                }
                else if afterSep.isRemainingLineEmpty {
                    return (.Item(item, .Tab), afterSep)
                }
            }
            else if let (_, afterSep) = literal(T_Semicolon, afterItem) {
                // ";" printList
                // ";" (trailing at end of line)

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
        if let (chars, afterChars) = stringLiteral(pos) {
            return (.Str(chars), afterChars)
        }

        if let (expression, afterExpr) = expression(pos) {
            return (.Expr(expression), afterExpr)
        }

        return nil
    }

    /// Attempt to parse a LvalueList.
    ///
    /// Returns LvalueList and position of next character if successful.  Returns nil otherwise.
    func lvalueList(pos: InputPosition) -> (LvalueList, InputPosition)? {
        // lvalue
        if let (item, afterItem) = lvalue(pos) {

            // "," lvalueList
            if let (_, afterSep) = literal(T_Comma, afterItem) {
                if let (tail, afterTail) = lvalueList(afterSep) {
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
        if let ((PLUS, uexpr), nextPos) =
            parse(pos, lit(T_Plus), unsignedExpression)
        {
            return (.Plus(uexpr), nextPos)
        }

        if let ((MINUS, uexpr), nextPos) =
            parse(pos, lit(T_Minus), unsignedExpression)
        {
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
            if let ((PLUS, uexpr), afterExpr) =
                parse(afterTerm, lit(T_Plus), unsignedExpression)
            {
                return (.Compound(t, ArithOp.Add, Box(uexpr)), afterExpr)
            }

            // If followed by "-", then it's subtraction
            if let ((MINUS, uexpr), afterExpr) =
                parse(afterTerm, lit(T_Minus), unsignedExpression)
            {
                return (.Compound(t, ArithOp.Subtract, Box(uexpr)), afterExpr)
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
            if let ((MULT, t), afterTerm) =
                parse(afterFact, lit(T_Asterisk), term)
            {
                return (.Compound(fact, ArithOp.Multiply, Box(t)), afterTerm)
            }

            // If followed by "/", then it's a quotient
            if let ((DIV, t), afterTerm) =
                parse(afterFact, lit(T_Slash), term)
            {
                return (.Compound(fact, ArithOp.Divide, Box(t)), afterTerm)
            }

            // Otherwise, just a simple term
            return (.Value(fact), afterFact)
        }

        return nil
    }

    /// Attempt to parse a Factor.  Returns Factor and position of next character if successful.  Returns nil if not.
    func factor(pos: InputPosition) -> (Factor, InputPosition)? {
        // number
        if let (num, afterNum) = numberLiteral(pos) {
            return (.Num(num), afterNum)
        }

        // "RND(" expression ")"
        if let ((RND, LPAREN, expr, RPAREN), nextPos) =
            parse(pos, lit(T_RND), lit(T_LParen), expression, lit(T_RParen))
        {
            return (.Rnd(Box(expr)), nextPos)
        }

        // "(" expression ")"
        if let ((LPAREN, expr, RPAREN), nextPos) =
            parse(pos, lit(T_LParen), expression, lit(T_RParen))
        {
            return (.ParenExpr(Box(expr)), nextPos)
        }

        // "@(" expression ")"
        if let ((AT, LPAREN, expr, RPAREN), nextPos) =
            parse(pos, lit(T_At), lit(T_LParen), expression, lit(T_RParen))
        {
            return (.ArrayElement(Box(expr)), nextPos)
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

            if c == Ch_Space {
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

    /// Check for a literal at the specified position.
    ///
    /// If the literal is present, then return it and the following position.
    ///
    /// If the literal is not present, then just return it and the original position.
    ///
    /// This is used in situations where a statement allows an optional keyword,
    /// such as LET or THEN, that can be ignored if present.
    func optLiteral(s: String, _ pos: InputPosition) -> (String, InputPosition)? {
        if let (lit, nextPos) = literal(s, pos) {
            return (lit, nextPos)
        }

        return (s, pos)
    }

    /// Curried variant of `optLiteral`, for use with `parse()`.
    func optLit(s: String)(pos: InputPosition) -> (String, InputPosition)? {
        return optLiteral(s, pos)
    }

    /// Try to parse one of a set of literals
    ///
    /// Returns first match, or nil if there are no matches
    func oneOfLiteral(strings: [String], _ pos: InputPosition) -> (String, InputPosition)? {
        for s in strings {
            if let match = literal(s, pos) {
                return match
            }
        }
        return nil
    }

    /// Curried form of `oneOfLiteral()`, for use with `parse`
    func oneOfLit(strings: String...)(pos: InputPosition) -> (String, InputPosition)? {
        return oneOfLiteral(strings, pos)
    }

    /// Attempt to read an unsigned number from input.  If successful, returns
    /// parsed number and position of next input character.  If not, returns nil.
    func numberLiteral(pos: InputPosition) -> (Number, InputPosition)? {
        var i = pos.afterSpaces()

        if i.isAtEndOfLine {
            return nil
        }

        if !isDigitChar(i.char) {
            // doesn't start with a digit
            return nil
        }

        var num = Number(i.char - Ch_0)
        i = i.next
        loop: while !i.isAtEndOfLine {
            let c = i.char
            if isDigitChar(c) {
                num = (num &* 10) &+ Number(c - Ch_0)
            }
            else if c != Ch_Space {
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
    func stringLiteral(pos: InputPosition) -> ([Char], InputPosition)? {
        var i = pos.afterSpaces()
        if !i.isAtEndOfLine {
            if i.char == Ch_DQuote {
                i = i.next
                var stringChars: [Char] = []
                var foundTrailingDelim = false

                loop: while !i.isAtEndOfLine {
                    let c = i.char
                    i = i.next
                    if c == Ch_DQuote {
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

    func lvalue(pos: InputPosition) -> (Lvalue, InputPosition)? {
        if let (v, nextPos) = variableName(pos) {
            return (.Var(v), nextPos)
        }

        if let ((AT, LPAREN, expr, RPAREN), nextPos) = parse(pos, lit(T_At), lit(T_LParen), expression, lit(T_RParen)) {
            return (.ArrayElement(expr), nextPos)
        }

        return nil
    }

    /// Attempt to read a variable name.
    ///
    /// Returns variable name and position of next input character on success, or nil otherwise.
    func variableName(pos: InputPosition) -> (VariableName, InputPosition)? {
        let i = pos.afterSpaces()
        if !i.isAtEndOfLine {
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
    func relop(pos: InputPosition) -> (RelOp, InputPosition)? {
        // Note: We need to test the longer sequences before the shorter
        if let (op, nextPos) = literal(T_LessOrEqual, pos) {
            return (.LessOrEqual, nextPos)
        }
        if let (op, nextPos) = literal(T_GreaterOrEqual, pos) {
            return (.GreaterOrEqual, nextPos)
        }
        if let (op, nextPos) = literal(T_NotEqual, pos) {
            return (.NotEqual, nextPos)
        }
        if let (op, nextPos) = literal(T_NotEqualAlt, pos) {
            return (.NotEqual, nextPos)
        }
        if let (op, nextPos) = literal(T_Less, pos) {
            return (.Less, nextPos)
        }
        if let (op, nextPos) = literal(T_Greater, pos) {
            return (.Greater, nextPos)
        }
        if let (op, nextPos) = literal(T_Equal, pos) {
            return (.Equal, nextPos)
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

    func deleteLineFromProgram(lineNumber: Number) {
        if let index = indexOfProgramLineWithNumber(lineNumber) {
            program.removeAtIndex(index)
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
        case .PrintNewline:                  PRINT()
        case let .Input(lvalueList):         INPUT(lvalueList)
        case let .Let(lvalue, expr):         LET(lvalue, expr)
        case let .DimArray(expr):            DIM(expr)
        case let .If(lhs, relop, rhs, stmt): IF(lhs, relop, rhs, stmt)
        case let .Goto(expr):                GOTO(expr)
        case let .Gosub(expr):               GOSUB(expr)
        case .Return:                        RETURN()
        case let .List(range):               LIST(range)
        case let .Save(filename):            SAVE(filename)
        case let .Load(filename):            LOAD(filename)
        case .Run:                           RUN()
        case .End:                           END()
        case .Clear:                         CLEAR()
        case .Rem(_):                        break
        case .Tron:                          isTraceOn = true
        case .Troff:                         isTraceOn = false
        case .Bye:                           BYE()
        case .Help:                          HELP()
        }
    }

    /// Execute PRINT statement
    func PRINT(plist: PrintList) {
        switch plist {
        case let .Item(item, terminator):
            writeOutput(item)
            writeOutput(terminator)

        case let .Items(item, sep, printList):
            // Print the first item
            writeOutput(item)
            writeOutput(sep)

            // Walk the list to print remaining items
            var remainder = printList.value
            loop: while true {
                switch remainder {
                case let .Item(item, terminator):
                    // last item
                    writeOutput(item)
                    writeOutput(terminator)
                    break loop
                case let .Items(head, sep, tail):
                    writeOutput(head)
                    writeOutput(sep)
                    remainder = tail.value
                }
            }
        }
    }

    /// Execute PRINT statement with no arguments
    func PRINT() {
        writeOutput("\n")
    }

    /// Execute INPUT statement
    /// 
    /// All values must be on a single input line, separated by commas.
    func INPUT(lvalueList: LvalueList) {

        let lvalues = lvalueList.asArray

        func showHelpMessage() {
            if lvalues.count > 1 {
                showError("You must enter a comma-separated list of \(lvalues.count) values")
            }
            else {
                showError("You must enter a value.")
            }
        }

        // Loop until successful or we hit end of input stream
        inputLoop: while true {
            io.showInputPrompt(self)
            if let input = readInputLine() {
                var pos = InputPosition(input, 0)

                for (index, lvalue) in enumerate(lvalues) {
                    if index == 0 {
                        if let (num, after) = inputExpression(pos) {
                            assignToLvalue(lvalue, number: num)
                            pos = after
                        }
                        else {
                            showHelpMessage()
                            continue inputLoop
                        }
                    }
                    else if let ((COMMA, num), after) = parse(pos, lit(T_Comma), inputExpression) {
                        assignToLvalue(lvalue, number: num)
                        pos = after
                    }
                    else {
                        showHelpMessage()
                        continue inputLoop
                    }
                }

                // If we get here, we've read input for all the variables
                break inputLoop
            }
            else {
                abortRunWithErrorMessage("error - INPUT: end of input stream")
                break inputLoop
            }
        }
    }

    /// Parse user entry for INPUT
    ///
    /// Return parsed number and following position if successful, or nil otherwise.
    ///
    /// Accepts entry of a number, with optional sign (+|-), or a variable name.
    func inputExpression(pos: InputPosition) -> (Number, InputPosition)? {
        // number
        if let (num, nextPos) = numberLiteral(pos) {
            return (num, nextPos)
        }

        // "+" number
        if let ((PLUS, num), nextPos) = parse(pos, lit(T_Plus), numberLiteral) {
            return (num, nextPos)
        }

        // "-" number
        if let ((MINUS, num), nextPos) = parse(pos, lit(T_Minus), numberLiteral) {
            return (-num, nextPos)
        }

        // variable
        if let (varname, nextPos) = variableName(pos) {
            return (v[varname] ?? 0, nextPos)
        }

        return nil
    }

    /// Execute LET statement
    func LET(lvalue: Lvalue, _ expression: Expression) {
        assignToLvalue(lvalue, number: expression.evaluate(v, a))
    }

    /// Assign a new value for a specified Lvalue
    func assignToLvalue(lvalue: Lvalue, number: Number) {
        switch lvalue {
        case let .Var(variableName):
            v[variableName] = number

        case let .ArrayElement(indexExpr):
            let index = indexExpr.evaluate(v, a) % a.count
            if index < 0 {
                a[a.count + index] = number
            }
            else {
                a[index] = number
            }
        }
    }

    /// Execute DIM @() statement
    func DIM(expr: Expression) {
        let newCount = expr.evaluate(v, a)
        if newCount < 0 {
            abortRunWithErrorMessage("error: DIM - size cannot be negative")
            return
        }

        a = Array(count: newCount, repeatedValue: 0)
    }

    /// Execute IF statement
    func IF(lhs: Expression, _ relop: RelOp, _ rhs: Expression, _ stmt: Box<Statement>) {
        if relop.isTrueForNumbers(lhs.evaluate(v, a), rhs.evaluate(v, a)) {
            execute(stmt.value)
        }
    }

    /// Execute LIST statement with no arguments
    func LIST(range: ListRange) {
        switch range {
        case .All:
            for (lineNumber, stmt) in program {
                writeOutput("\(lineNumber) \(stmt.listText)\n")
            }

        case let .SingleLine(expr):
            let listLineNumber = expr.evaluate(v, a)
            for (lineNumber, stmt) in program {
                if lineNumber == listLineNumber {
                    writeOutput("\(lineNumber) \(stmt.listText)\n")
                }
            }

        case let .Range(from, to):
            let fromLineNumber = from.evaluate(v, a)
            let toLineNumber = to.evaluate(v, a)

            for (lineNumber, stmt) in program {
                if isValue(lineNumber, inClosedInterval: fromLineNumber, toLineNumber) {
                    writeOutput("\(lineNumber) \(stmt.listText)\n")
                }
            }
        }
    }

    /// Execute SAVE statement
    func SAVE(filename: String) {
        let filenameCString = (filename as NSString).UTF8String
        let modeCString = ("w" as NSString).UTF8String

        let file = fopen(filenameCString, modeCString)
        if file != nil {
            for (lineNumber, stmt) in program {
                let outputLine = "\(lineNumber) \(stmt.listText)\n"
                let outputLineChars = charsFromString(outputLine)
                fwrite(outputLineChars, 1, UInt(outputLineChars.count), file)
            }
            fclose(file)
        }
        else {
            abortRunWithErrorMessage("error: SAVE - unable to open file \"\(filename)\": \(errnoMessage())")
        }
    }

    /// Execute LOAD statement
    func LOAD(filename: String) {
        let filenameCString = (filename as NSString).UTF8String
        let modeCString = ("r" as NSString).UTF8String

        let file = fopen(filenameCString, modeCString)
        if file != nil {
            loop: while true {
                let maybeInputLine = getInputLine {
                    let c = fgetc(file)
                    return (c == EOF) ? nil : Char(c)
                }

                if let inputLine = maybeInputLine {
                    processInput(inputLine)
                }
                else {
                    break loop
                }
            }

            if ferror(file) != 0 {
                abortRunWithErrorMessage("error: LOAD - read error for file \"\(filename)\": \(errnoMessage())")
            }

            fclose(file)
        }
        else {
            abortRunWithErrorMessage("error: LOAD - unable to open file \"\(filename)\": \(errnoMessage())")
        }
    }

    /// Execute RUN statement
    func RUN() {
        if program.count == 0 {
            showError("error: RUN - no program in memory")
            return
        }

        programIndex = 0
        clearVariablesAndArray()
        clearReturnStack()
        doRunLoop()
    }

    /// Execute END statement
    func END() {
        isRunning = false
    }

    /// Execute GOTO statement
    func GOTO(expr: Expression) {
        let lineNumber = expr.evaluate(v, a)
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
        let lineNumber = expr.evaluate(v, a)
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
        clearVariablesAndArray()
    }

    /// Execute BYE statement
    public func BYE() {
        io.bye(self)
    }

    /// Execute HELP statement
    public func HELP() {
        let lines = [
            "FinchBasic Statements:",
            "  BYE",
            "  CLEAR",
            "  END",
            "  GOSUB expression",
            "  GOTO expression",
            "  HELP",
            "  IF expression relop expression THEN statement",
            "  INPUT var-list",
            "  LET var = expression",
            "  LIST [firstLine, [lastLine]]",
            "  LOAD \"filename\"",
            "  PRINT expr-list",
            "  REM comment",
            "  RETURN",
            "  RUN",
            "  SAVE \"filename\"",
            "  TRON | TROFF"
        ]

        for line in lines {
            writeOutput(line)
            writeOutput("\n")
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

            let (lineNumber, stmt) = program[programIndex]
            if isTraceOn {
                io.showDebugTrace(self, message: "[\(lineNumber)]")
            }
            ++programIndex
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
            showError("abort: program terminated")
        }
    }


    // MARK: - I/O

    /// Send a single character to the output stream
    func writeOutput(c: Char) {
        io.putOutputChar(self, c)
    }

    /// Send characters to the output stream
    func writeOutput(chars: [Char]) {
        for c in chars {
            io.putOutputChar(self, c)
        }
    }

    /// Send string to the output stream
    func writeOutput(s: String) {
        return writeOutput(charsFromString(s))
    }

    /// Print an object that conforms to the PrintTextProvider protocol
    func writeOutput(p: PrintTextProvider) {
        writeOutput(p.printText(v, a))
    }

    /// Display error message
    func showError(message: String) {
        io.showError(self, message: message)
    }

    /// Read a line using the InterpreterIO interface.
    /// 
    /// Return array of characters, or nil if at end of input stream.
    ///
    /// Result does not include any non-graphic characters that were in the input stream.
    /// Any horizontal tab ('\t') in the input will be converted to a single space.
    ///
    /// Result may be an empty array, indicating an empty input line, not end of input.
    func readInputLine() -> InputLine? {
        return getInputLine { self.io.getInputChar(self) }
    }

    /// Get a line of input, using specified function to retrieve characters.
    /// 
    /// Return array of characters, or nil if at end of input stream.
    ///
    /// Result does not include any non-graphic characters that were in the input stream.
    /// Any horizontal tab ('\t') in the input will be converted to a single space.
    ///
    /// Result may be an empty array, indicating an empty input line, not end of input.
    func getInputLine(getChar: () -> Char?) -> InputLine? {
        var lineBuffer = InputLine()

        if var c = getChar() {
            loop: while c != Ch_Linefeed {
                if isGraphicChar(c) {
                    lineBuffer.append(c)
                }
                else if c == Ch_Tab {
                    // Convert tabs to spaces
                    lineBuffer.append(Ch_Space)
                }

                if let nextChar = getChar() {
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


// MARK: - Input

/// Input is a "line" consisting of 8-bit ASCII/UTF8 characters
public typealias InputLine = [Char]

/// Current position on a line of input
///
/// This encapsulates the concept of an index into a character array.
/// It provides some convenient methods/properties used by the
/// parsing code in `Interpreter`.
struct InputPosition {
    let input: InputLine
    let index: Int

    init(_ input: InputLine, _ index: Int) {
        self.input = input
        self.index = index
    }

    /// Return the character at this position
    var char: Char {
        assert(!isAtEndOfLine, "caller must check for end-of-line before calling char")
        return input[index]
    }

    /// Return true if there are no non-space characters at or following the
    /// specified index in the specified line
    var isRemainingLineEmpty: Bool {
        return afterSpaces().index == input.count
    }

    /// Return number of characters following this position, including the character at this position)
    var remainingCount: Int {
        return input.count - index
    }

    /// Return remaining characters on line, including the character at this position
    var remainingChars: [Char] {
        return index < input.count ? Array(input[index..<input.count]) : []
    }

    /// Return true if this position is at the end of the line
    var isAtEndOfLine: Bool {
        return index >= input.count
    }

    /// Return the next input position
    var next: InputPosition {
        return InputPosition(input, index + 1)
    }

    /// Return the position at the end of the line
    var endOfLine: InputPosition {
        return InputPosition(input, input.count)
    }

    /// Return position of first non-space character at or after this position
    func afterSpaces() -> InputPosition {
        var i = index
        let count = input.count
        while i < count && input[i] == Ch_Space {
            ++i
        }
        return InputPosition(input, i)
    }
}


// MARK: - Parsing helpers

// The parse() functions take a starting position and a sequence
// of "parsing functions" to apply in order.
//
// Each parsing function takes an `InputPosition` and returns a
// `(T, InputPosition)?` pair, where `T` is the type of data
// parsed.  The parsing function returns `nil` if it cannot parse
// the element it is looking for at that position.
//
// `parse()` returns a tuple containing all the parsed elements
// and the following `InputPosition`.
//
// This allows us to write pattern-matching parsing code like this:
//
//     if let ((LET, v, EQ, expr), nextPos) =
//         parse(pos, lit("LET"), variable, lit("EQ"), expression)
//     {
//         // do something with v, expr, and nextPos
//         // ...
//     }
//
// which is equivalent to this:
//
//     if let (_, afterLet) = lit("LET")(pos) {
//         if let (v, afterVar) = variable(afterLet) {
//             if (_, afterEq) = lit("EQ")(afterVar) {
//                 if (expr, nextPos) = expression(afterEq) {
//                     // do something with v, expr, and nextPos
//                     // ...
//                 }
//             }
//         }
//     }
//
// where `lit(String)`, `variable`, and `expression` are
// functions that take an `InputPosition` and return an Optional
// pair `(T, InputPosition)?`
//
// Note: These functions were originally defined in a separate source
// file, but the Swift optimizer generated invalid code.  The workaround
// was to move the definitions into this file.  For more information,
// see http://www.openradar.me/19349390
// and https://twitter.com/jckarter/status/548582743240900609

/// Parse two elements using parsing functions, returning the elements and next input position
func parse<A, B> (
    position: InputPosition,
    a: (InputPosition) -> (A, InputPosition)?,
    b: (InputPosition) -> (B, InputPosition)?) -> ((A, B), InputPosition)?
{
    if let (a, afterA) = a(position) {
        if let (b, afterB) = b(afterA) {
            return ((a, b), afterB)
        }
    }
    return nil
}

/// Parse three elements using parsing functions, returning the elements and next input position
func parse<A, B, C> (
    position: InputPosition,
    a: (InputPosition) -> (A, InputPosition)?,
    b: (InputPosition) -> (B, InputPosition)?,
    c: (InputPosition) -> (C, InputPosition)?) -> ((A, B, C), InputPosition)?
{
    if let (a, afterA) = a(position) {
        if let (b, afterB) = b(afterA) {
            if let (c, afterC) = c(afterB) {
                return ((a, b, c), afterC)
            }
        }
    }

    return nil
}

/// Parse four elements using parsing functions, returning the elements and next input position
func parse<A, B, C, D> (
    position: InputPosition,
    a: (InputPosition) -> (A, InputPosition)?,
    b: (InputPosition) -> (B, InputPosition)?,
    c: (InputPosition) -> (C, InputPosition)?,
    d: (InputPosition) -> (D, InputPosition)?) -> ((A, B, C, D), InputPosition)?
{
    if let (a, afterA) = a(position) {
        if let (b, afterB) = b(afterA) {
            if let (c, afterC) = c(afterB) {
                if let (d, afterD) = d(afterC) {
                    return ((a, b, c, d), afterD)
                }
            }
        }
    }

    return nil
}

/// Parse five elements using parsing functions, returning the elements and next input position
func parse<A, B, C, D, E> (
    position: InputPosition,
    a: (InputPosition) -> (A, InputPosition)?,
    b: (InputPosition) -> (B, InputPosition)?,
    c: (InputPosition) -> (C, InputPosition)?,
    d: (InputPosition) -> (D, InputPosition)?,
    e: (InputPosition) -> (E, InputPosition)?) -> ((A, B, C, D, E), InputPosition)?
{
    if let (a, afterA) = a(position) {
        if let (b, afterB) = b(afterA) {
            if let (c, afterC) = c(afterB) {
                if let (d, afterD) = d(afterC) {
                    if let (e, afterE) = e(afterD) {
                        return ((a, b, c, d, e), afterE)
                    }
                }
            }
        }
    }

    return nil
}

/// Parse six elements using parsing functions, returning the elements and next input position
func parse<A, B, C, D, E, F> (
    position: InputPosition,
    a: (InputPosition) -> (A, InputPosition)?,
    b: (InputPosition) -> (B, InputPosition)?,
    c: (InputPosition) -> (C, InputPosition)?,
    d: (InputPosition) -> (D, InputPosition)?,
    e: (InputPosition) -> (E, InputPosition)?,
    f: (InputPosition) -> (F, InputPosition)?) -> ((A, B, C, D, E, F), InputPosition)?
{
    if let (a, afterA) = a(position) {
        if let (b, afterB) = b(afterA) {
            if let (c, afterC) = c(afterB) {
                if let (d, afterD) = d(afterC) {
                    if let (e, afterE) = e(afterD) {
                        if let (f, afterF) = f(afterE) {
                            return ((a, b, c, d, e, f), afterF)
                        }
                    }
                }
            }
        }
    }

    return nil
}

