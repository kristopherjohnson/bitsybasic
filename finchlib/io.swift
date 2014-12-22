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

