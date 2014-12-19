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

import Cocoa
import XCTest
import finchlib

/// Implementation of InterpreterIO that uses strings for
/// input and output.  Useful for unit tests.
class StringIO: InterpreterIO {
    /// Characters to be returned by getInputChar()
    var inputChars: [Char] = []

    /// Index of the next character of inputChars to be returned by getInputChar()
    var inputIndex: Int = 0

    /// Characters passed to putOutputChar()
    var outputChars: [Char] = []

    /// Strings passed to showError()
    var errors: [String] = []

    /// Get/set inputChars as a String value
    var inputString: String {
        get {
            return stringFromChars(inputChars)
        }
        set {
            inputChars = Array(newValue.utf8)
            inputIndex = 0
        }
    }

    /// Get outputChars as a String value
    var outputString: String {
        return stringFromChars(outputChars)
    }

    func getInputChar(interpreter: Interpreter) -> Char? {
        if inputIndex < inputChars.count {
            return inputChars[inputIndex++]
        }

        return nil
    }

    func putOutputChar(interpreter: Interpreter, _ c: Char) {
        outputChars.append(c)
    }

    func showPrompt(interpreter: Interpreter) {
        // does nothing
    }

    func showError(interpreter: Interpreter, message: String) {
        errors.append(message)
    }
}

class finchlibTests: XCTestCase {

    var io = StringIO()
    var interpreter = Interpreter()

    override func setUp() {
        super.setUp()

        // for each test, create a fresh StringIO instance and assign it
        // to a fresh Interpreter instance
        io = StringIO()
        interpreter = Interpreter(interpreterIO: io)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testPrintString() {
        io.inputString = "PRINT \"Hello, world!\""

        interpreter.interpret()

        XCTAssertEqual(0, io.errors.count)
        XCTAssertEqual("Hello, world!\n", io.outputString)
    }

    func testPrintString2() {
        io.inputString = "  P R\"Goodbye, world!\""

        interpreter.interpret()

        XCTAssertEqual(0, io.errors.count)
        XCTAssertEqual("Goodbye, world!\n", io.outputString)
    }
}
