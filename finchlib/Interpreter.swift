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
public class StandardIO: InterpreterIO {
    public final func getInputChar(interpreter: Interpreter) -> Char? {
        let c = getchar()
        return c == EOF ? nil : Char(c)
    }

    public final func putOutputChar(interpreter: Interpreter, _ c: Char) {
        putchar(Int32(c))
        fflush(stdin)
    }

    public final func showPrompt(interpreter: Interpreter) {
        putchar(Int32(Char_Colon))
        fflush(stdin)
    }

    public final func showError(interpreter: Interpreter, message: String) {
        var chars = charsFromString(message)
        chars.append(Char_Linefeed)
        fwrite(chars, 1, UInt(chars.count), stderr)
        fflush(stderr)
    }
}


// MARK: - Interpreter

/// Tiny Basic interpreter
public class Interpreter {
    /// Array of program lines
    var program: Program = []

    /// Variable values
    var v: [VariableName : Number] = [:]

    /// Low-level I/O interface
    var io: InterpreterIO

    /// Return stack
    var returnStack: [Number] = []


    /// Initialize, optionally passing in a custom BasicInterpreterIO handler
    public init(interpreterIO: InterpreterIO = StandardIO()) {
        io = interpreterIO

        // Initialize all variable values to zero
        for n in Char_A...Char_Z {
            v[n] = 0
        }
    }


    // MARK: - Top-level loop

    /// Display prompt and read input lines and interpret them until end of input
    public final func interpretInput() {
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
    final func processInput(input: InputLine) {
        let line = parseInputLine(input)
        switch line {
        case .UnnumberedStatement(let statement): execute(statement)
        case .NumberedStatement(_, _):            insertLineIntoProgram(line)
        case .Empty:                              break
        case .Error(let message):                 showError(message)
        }
    }


    // MARK: - Parsing

    final func parseInputLine(input: InputLine) -> Line {
        let count = input.count
        let i = skipSpaces(input, 0)

        // If there are no non-space characters, skip this line
        if i == count {
            return .Empty
        }

        // Check whether the line starts with a number
        if let (number, nextIndex) = parseNumber(input, i) {
            let statement = parseStatement(input, nextIndex)
            switch statement {
            case .Error(let message): return .Error(message)
            default:                  return .NumberedStatement(number, statement)
            }
        }
        else {
            let statement = parseStatement(input, i)
            switch statement {
            case .Error(let message): return .Error(message)
            default:                  return .UnnumberedStatement(statement)
            }
        }
    }

    /// Return index of first non-space character at or after specified index
    final func skipSpaces(input: InputLine, _ index: Int) -> Int {
        var i = index
        let count = input.count
        while i < count && input[i] == Char_Space {
            ++i
        }
        return i
    }

    /// Attempt to read an unsigned number from input.  If successful, returns
    /// parsed number and index of next input character.  If not, returns nil.
    final func parseNumber(input: InputLine, _ index: Int) -> (Number, Int)? {
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
            let c = input[i++]
            if isDigitChar(c) {
                number = (number &* 10) &+ Number(c - Char_0)
            }
            else if c != Char_Space {
                break
            }
        }

        return (number, i)
    }
    
    final func parseStatement(input: InputLine, _ i: Int) -> Statement {
        if let nextIndex = parseLiteral("PRINT", input, i) {
            return parsePrintArguments(input, nextIndex)
        }

        // "PR" is an abbreviation for "PRINT"
        if let nextIndex = parseLiteral("PR", input, i) {
            return parsePrintArguments(input, nextIndex)
        }

        return .Error("error: not a statement")
    }

    /// Determine whether the remainder of the line starts with a specified sequence of characters.
    ///
    /// If true, returns index of the character following the matched string. If false, returns nil.
    ///
    /// Matching is case-insensitive. Spaces in the input are ignored.
    final func parseLiteral(literal: String, _ input: InputLine, _ index: Int) -> Int? {
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
    
    /// Parse the arguments for a PRINT statement
    final func parsePrintArguments(input: InputLine, _ index: Int) -> Statement {
        let exprList = parseExprList(input, index)
        switch exprList {
        case .Error(let message): return .Error(message)
        default:                  return .Print(exprList)
        }
    }

    final func parseExprList(input: InputLine, _ index: Int) -> ExprList {
        let i = skipSpaces(input, index)
        let count = input.count
        if i == count {
            return .Error("error: missing arguments to PRINT")
        }

        if let (chars, nextIndex) = parseString(input, i) {
            return .Str(chars)
        }

        if let (expression, nextIndex) = parseExpression(input, i) {
            return .Expr(expression)
        }

        return .Error("error: invalid arguments for PRINT")
    }

    /// Attempt to parse a string, which is delimited with " at start and end
    ///
    /// Returns characters between delimiters and index of next character if successful.
    /// Returns nil otherwise.
    final func parseString(input: InputLine, _ index: Int) -> ([Char], Int)? {
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

    /// Attempt to parse an Expression.  Returns Expression and index of next character if successful.  Returns nil if not.
    final func parseExpression(input: InputLine, _ index: Int) -> (Expression, Int)? {
        if let (unsignedExpression, nextIndex) = parseUnsignedExpression(input, index) {
            return (.UnsignedExpr(unsignedExpression), nextIndex)
        }

        return nil
    }

    /// Attempt to parse an UnsignedExpression.  Returns UnsignedExpression and index of next character if successful.  Returns nil if not.
    final func parseUnsignedExpression(input: InputLine, _ index: Int) -> (UnsignedExpression, Int)? {
        if let (term, nextIndex) = parseTerm(input, index) {
            return (.Value(term), nextIndex)
        }

        return nil
    }

    /// Attempt to parse a Term.  Returns Term and index of next character if successful.  Returns nil if not.
    final func parseTerm(input: InputLine, _ index: Int) -> (Term, Int)? {
        if let (factor, nextIndex) = parseFactor(input, index) {
            return (.Value(factor), nextIndex)
        }

        return nil
    }

    /// Attempt to parse a Factor.  Returns Factor and index of next character if successful.  Returns nil if not.
    final func parseFactor(input: InputLine, _ index: Int) -> (Factor, Int)? {
        if let (number, nextIndex) = parseNumber(input, index) {
            return (.Num(number), nextIndex)
        }

        return nil
    }

    // MARK: - Program editing

    final func insertLineIntoProgram(line: Line) {
        showError("error: program editing not yet implemented")
    }


    // MARK: - Execution

    /// Execute the given statement
    final func execute(statement: Statement) {
        switch statement {
        case .Print(let exprList): executePrint(exprList)
        default:                   showError("error: unimplemented statement type")
        }
    }

    /// Execute PRINT with the specified arguments
    final func executePrint(exprList: ExprList) {
        switch exprList {
        case .Str(let chars):
            printChars(chars)
            printChar(Char_Linefeed)

        case .Expr(let expression):
            let value = expression.value
            let stringValue = "\(value)"
            let chars = charsFromString(stringValue)
            printChars(chars)
            printChar(Char_Linefeed)

        default:
            showError("error: unimplemented printitem type")
        }
    }


    // MARK: - I/O

    /// Send a single character to the output stream
    final func printChar(c: Char) {
        io.putOutputChar(self, c)
    }

    /// Send characters to the output stream
    final func printChars(chars: [Char]) {
        for c in chars {
            io.putOutputChar(self, c)
        }
    }

    /// Display error message
    final func showError(message: String) {
        io.showError(self, message: message)
    }

    /// Read a line of input.  Return array of characters, or nil if at end of input stream.
    ///
    /// Result does not include any non-graphic characters that were in the input stream.
    /// Any horizontal tab ('\t') in the input will be converted to a single space.
    ///
    /// Result may be an empty array, indicating an empty input line, not end of input.
    final func readInputLine() -> InputLine? {
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
