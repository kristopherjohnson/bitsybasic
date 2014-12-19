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


// MARK: - I/O

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

/// Standard implementation of BasicInterpreterIO that reads from stdin,
/// writes to stdout, and sends error messages to stderr.
public class StandardIO: InterpreterIO {
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
        var chars: [Char] = Array(message.utf8)
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
    var v: [VariableName: Number] = [:]

    /// Low-level I/O interface
    var io: InterpreterIO

    /// Initialize, optionally passing in a custom BasicInterpreterIO handler
    public init(interpreterIO: InterpreterIO = StandardIO()) {
        io = interpreterIO
        for n: VariableName in Char_A...Char_Z {
            v[n] = 0
        }
    }

    /// Display prompt and read input lines and interpret them until end of input
    public func interpret() {
        while true {
            io.showPrompt(self)
            if let input = readInputLine() {
                processInputLine(input)
            }
            else {
                break
            }
        }
    }

    /// Read a line of input.  Return array of characters, or nil if reached end of input stream.
    ///
    /// Result does not include any non-graphic characters that were in the input stream.
    /// Any horizontal tab ('\t')  in the input will be converted to a single space.
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

    func processInputLine(input: InputLine) {
        let line = parseInputLine(input)
        switch line {
        case .UnnumberedStatement(let statement): execute(statement)
        case .NumberedStatement(_, _):            insertLineIntoProgram(line)
        case .Empty:                              break
        case .Error(let message):                 showError(message)
        }
    }
    
    func parseInputLine(input: InputLine) -> Line {
        var i = 0
        let n = input.count

        // Skip leading spaces
        while i < n && input[i] == Char_Space {
            ++i
        }

        // If there are no non-space characters, skip this line
        if i == n {
            return .Empty
        }

        // Check whether the line starts with a number
        if isDigitChar(input[i]) {
            // Parse the line number
            var number = Number(input[i] - Char_0)
            i++
            while i < n {
                let c = input[i++]
                if isDigitChar(c) {
                    number = (number &* 10) &+ Number(c - Char_0)
                }
                else if c != Char_Space {
                    break
                }
            }

            if i < n {
                let statement = parseStatement(input, i)
                switch statement {
                case .Error(let message): return .Error(message)
                default:                  return .NumberedStatement(number, statement)
                }
            }
            else {
                return .Error("error: line number must be followed by a statement")
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

    func parseStatement(input: InputLine, _ i: Int) -> Statement {
        if let nextIndex = hasPrefix("PRINT", input, i) {
            return parsePrintArguments(input, nextIndex)
        }

        if let nextIndex = hasPrefix("PR", input, i) {
            return parsePrintArguments(input, nextIndex)
        }

        return .Error("error: not a statement")
    }

    /// Determine whether the remainder of the line starts with a specified sequence of characters.
    ///
    /// If true, returns index of the character following the prefix. If false, returns nil.
    ///
    /// Matching is case-insensitive. Spaces in the input are ignored.
    func hasPrefix(prefix: String, _ input: InputLine, _ index: Int) -> Int? {
        let prefixChars: [Char] = Array(prefix.utf8)
        var matchCount = 0
        var matchGoal = prefixChars.count

        let n = input.count
        var i = index
        while (matchCount < matchGoal) && (i < n) {
            let c = input[i++]

            if c == Char_Space {
                continue
            }
            else if toUpper(c) == toUpper(prefixChars[matchCount]) {
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
    func parsePrintArguments(input: InputLine, _ index: Int) -> Statement {
        let printList = parsePrintList(input, index)
        switch printList {
        case .Error(let message): return .Error(message)
        default:                  return .Print(printList)
        }
    }

    func parsePrintList(input: InputLine, _ index: Int) -> PrintList {
        let n = input.count
        var i = index

        while i < n && input[i] == Char_Space {
            ++i
        }

        if i == n {
            return .Error("error: missing arguments to PRINT")
        }

        if input[i] == Char_DQuote {
            ++i
            var stringChars: [Char] = []
            var foundEnd = false

            while i < n {
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
                // TODO: check for line continuation
                stringChars.append(Char_Linefeed)
                
                return .Item(PrintItem.Str(stringChars))
            }
            else {
                return .Error("error: missing terminator for string")
            }
        }

        return .Error("error: invalid arguments for PRINT")
    }

    func insertLineIntoProgram(line: Line) {
        
    }

    func execute(statement: Statement) {
        switch statement {
        case .Print(let printList): executePrint(printList)
        default:                    showError("error: unimplemented statement type")
        }
    }

    func executePrint(printList: PrintList) {
        switch printList {
        case .Item(let item):
            switch item {
            case .Str(let chars):
                for c in chars { io.putOutputChar(self, c) }
            default:
                showError("error: unimplemented printitem type")
            }
        default:
            showError("error: unimplemented printlist type")
        }
    }

    func showError(message: String) {
        io.showError(self, message: message)
    }
}
