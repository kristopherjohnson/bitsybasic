/*
Copyright (c) 2015 Kristopher Johnson

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

// MARK: - System I/O

/// Possible results for the InterpreterIO.getInputChar method
public enum InputLineResult {
    /// Input line
    case Value(InputLine)

    /// Reached end of input stream
    case EndOfStream

    /// No characters available now
    case Waiting
}

/// Possible results for the InterpreterIO.getInputChar method
public enum InputCharResult {
    /// Char
    case Value(Char)

    /// Reached end of input stream
    case EndOfStream

    /// No characters available now
    case Waiting
}

/// Protocol implemented by object that provides I/O operations for an Interpreter
public protocol InterpreterIO: NSObjectProtocol {
    /// Return next input character, or nil if at end-of-file or an error occurs
    func getInputCharForInterpreter(interpreter: Interpreter) -> InputCharResult

    /// Write specified output character
    func putOutputChar(c: Char, forInterpreter interpreter: Interpreter)

    /// Display a prompt to the user for entering an immediate command or line of code
    func showCommandPromptForInterpreter(interpreter: Interpreter)

    /// Display a prompt to the user for entering data for an INPUT statement
    func showInputPromptForInterpreter(interpreter: Interpreter)

    /// Display error message to user
    func showErrorMessage(message: String, forInterpreter interpreter: Interpreter)

    /// Display a debug trace message
    func showDebugTraceMessage(message: String, forInterpreter interpreter: Interpreter)

    /// Called when BYE is executed
    func byeForInterpreter(interpreter: Interpreter)
}

/// Default implementation of InterpreterIO that reads from stdin,
/// writes to stdout, and sends error messages to stderr.  The
/// BYE command will cause the process to exit with a succesful
/// result code.
///
/// This implementation's `getInputChar()` will block until a
/// character is read from standard input or end-of-stream is reached.
/// It will never return `.Waiting`.
public final class StandardIO: NSObject, InterpreterIO {
    public func getInputCharForInterpreter(interpreter: Interpreter) -> InputCharResult {
        let c = getchar()
        return c == EOF ? .EndOfStream : .Value(Char(c))
    }

    public func putOutputChar(c: Char, forInterpreter interpreter: Interpreter) {
        putchar(Int32(c))
        fflush(stdout)
    }

    public func showCommandPromptForInterpreter(interpreter: Interpreter) {
        putchar(Int32(Ch_RAngle))
        fflush(stdout)
    }

    public func showInputPromptForInterpreter(interpreter: Interpreter) {
        putchar(Int32(Ch_QuestionMark))
        putchar(Int32(Ch_Space))
        fflush(stdout)
    }

    public func showErrorMessage(message: String, forInterpreter interpreter: Interpreter) {
        var chars = charsFromString(message)
        chars.append(Ch_Linefeed)
        fwrite(chars, 1, chars.count, stderr)
        fflush(stderr)
    }

    public func showDebugTraceMessage(message: String, forInterpreter interpreter: Interpreter) {
        var chars = charsFromString(message)
        fwrite(chars, 1, chars.count, stdout)
        fflush(stdout)
    }

    public func byeForInterpreter(interpreter: Interpreter) {
        exit(EXIT_SUCCESS)
    }
}
