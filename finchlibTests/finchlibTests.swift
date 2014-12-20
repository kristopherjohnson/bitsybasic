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

    /// Get the first recorded error message. Returns empty string if no errors recorded.
    var firstError: String {
        if errors.count > 0 {
            return errors[0]
        }
        return ""
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

    func testEmptyInput() {
        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("", io.outputString, "should produce no output")
    }

    func testEmptyLines() {
        io.inputString = "\n  \n   \n\n"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("", io.outputString, "should produce no output")
    }

    func testPrintStrings() {
        io.inputString = "PRINT \"Hello, world!\"\n   P R\"Goodbye, world!\" "

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("Hello, world!\nGoodbye, world!\n", io.outputString, "should print two lines")
    }

    func testPrintNumber() {
        io.inputString = "PRINT 321"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("321\n", io.outputString, "should print the number")
    }

    func testPrintNumbers() {
        io.inputString = "PRINT 11,22,33"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("11\t22\t33\n", io.outputString, "should print the numbers with tabs between them")
    }

    func testPrintStringsAndNumbers() {
        io.inputString = "PRINT \"one\",1,\"two\",2"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("one\t1\ttwo\t2\n", io.outputString, "should print the values with tabs between them")
    }

    func testMultiplyTerms() {
        io.inputString = "PRINT 12 * 3, 2 * 9"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("36\t18\n", io.outputString, "should print the products of 12 * 3 and 2 * 9, separated with a tab")
    }

    func testDivideTerms() {
        io.inputString = "PRINT 12/3,9/4"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("4\t2\n", io.outputString, "should print the quotients 12 / 3 and 9 / 4, separated with a tab")
    }

    func testAddAndSubtract() {
        io.inputString = "PRINT 12 + 3, 2 - 9"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("15\t-7\n", io.outputString, "should print the sums of 12 + 3 and 2 - 9, separated with a tab")
    }

    func testPlusAndMinus() {
        io.inputString = "PRINT -99 , +4, -12 ,+5"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("-99\t4\t-12\t5\n", io.outputString, "should print the values separated by tabs")
    }

    func testParentheses() {
        io.inputString = "PRINT (5 + 2 ) * 3, 10 -(  2 * 7)"

        interpreter.interpretInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("21\t-4\n", io.outputString, "should print the values separated by tabs")
    }
}
