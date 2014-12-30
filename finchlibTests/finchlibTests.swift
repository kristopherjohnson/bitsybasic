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
import XCTest

#if os(iOS)
    import BitsyBASIC
#else
    import finchlib
#endif


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

    /// Number of times showInputPrompt has been called
    var inputPromptCount: Int = 0

    /// Number of times bye has been called
    var byeCount: Int = 0

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

    func getInputChar(interpreter: Interpreter) -> InputCharResult {
        if inputIndex < inputChars.count {
            return .Value(inputChars[inputIndex++])
        }

        return .EndOfStream
    }

    func putOutputChar(interpreter: Interpreter, _ c: Char) {
        outputChars.append(c)
    }

    func showCommandPrompt(interpreter: Interpreter) {
        // does nothing
    }

    func showInputPrompt(interpreter: Interpreter) {
        ++inputPromptCount
    }

    func showError(interpreter: Interpreter, message: String) {
        errors.append(message)
    }

    func showDebugTrace(interpreter: Interpreter, message: String) {
        // does nothing
    }

    func bye(interpreter: Interpreter) {
        ++byeCount
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
        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("", io.outputString, "should produce no output")
    }

    func testEmptyLines() {
        io.inputString = "\n  \n   \n\n"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("", io.outputString, "should produce no output")
    }

    func testPrintStrings() {
        io.inputString = "PRINT \"Hello, world!\"\n   P R\"Goodbye, world!\"\n ? \"Question?\""

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("Hello, world!\nGoodbye, world!\nQuestion?\n", io.outputString, "should print two lines")
    }

    func testPrintNumber() {
        io.inputString = "PRINT 321"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("321\n", io.outputString, "should print the number")
    }

    func testPrintNumbers() {
        io.inputString = "PRINT 11,22,33"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("11\t22\t33\n", io.outputString, "should print the numbers with tabs between them")
    }

    func testPrintStringsAndNumbers() {
        io.inputString = "PRINT \"one\",1,\"two\",2"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("one\t1\ttwo\t2\n", io.outputString, "should print the values with tabs between them")
    }

    func testMultiplyTerms() {
        io.inputString = "PRINT 12 * 3, 2 * 9"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("36\t18\n", io.outputString, "should print the products of 12 * 3 and 2 * 9, separated with a tab")
    }

    func testDivideTerms() {
        io.inputString = "PRINT 12/3,9/4"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("4\t2\n", io.outputString, "should print the quotients 12 / 3 and 9 / 4, separated with a tab")
    }

    func testAddAndSubtract() {
        io.inputString = "PRINT 12 + 3, 2 - 9"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("15\t-7\n", io.outputString, "should print the sums of 12 + 3 and 2 - 9, separated with a tab")
    }

    func testPlusAndMinus() {
        io.inputString = "PRINT -99 , +4, -12 ,+5"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("-99\t4\t-12\t5\n", io.outputString, "should print the values separated by tabs")
    }

    func testParentheses() {
        io.inputString = "PRINT (5 + 2 ) * 3, 10 -(  2 * 7), -100 + (-7)"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("21\t-4\t-107\n", io.outputString, "should print the values separated by tabs")
    }

    func testPrintFailForInvalidTrailingCharacters() {
        io.inputString = lines(
            "10 PRINT 5 + 2   X ",
            "LIST"
        )
        interpreter.runUntilEndOfInput()

        XCTAssertEqual(1, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("", io.outputString, "LIST should produce no output for invalid statement")
    }

    func testLet() {
        io.inputString = lines(
            "LET x = 15",
            "let Q = 99",
            "PRINT X, q - 11, a"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("15\t88\t0\n", io.outputString, "should print the values separated by tabs")
    }

    func testIfEqual() {
        io.inputString = lines(
            "IF 0 = 0 THEN PRINT 1",
            "IF 1 = 0 THEN PRINT 2",
            "IF 99 = 99 THEN PRINT 3"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("1\n3\n", io.outputString, "should print expected lines")
    }

    func testIfNotEqual() {
        io.inputString = lines(
            "IF 1 <> 0 THEN PRINT 1",
            "IF 1 >< 0 THEN PRINT 2",
            "IF 99 <> 99 THEN PRINT 3"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("1\n2\n", io.outputString, "should print expected lines")
    }
    
    func testIfLessThan() {
        io.inputString = lines(
            "IF 0 < 0 THEN PRINT 1",
            "IF 1 < 9 THEN PRINT 2",
            "IF -99 < 99 THEN PRINT 3"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("2\n3\n", io.outputString, "should print expected lines")
    }

    func testIfLessThanOrEqualTo() {
        io.inputString = lines(
            "IF 0 <= 0    THEN PRINT 1",
            "IF 10 <= 9   THEN PRINT 2",
            "IF -99<  =99 THEN PRINT 3"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("1\n3\n", io.outputString, "should print expected lines")
    }

    func testIfGreaterThan() {
        io.inputString = lines(
            "IF 0 > 0 THEN PRINT 1",
            "IF 9 > 1 THEN PRINT 2",
            "IF 99 > -99 THEN PRINT 3"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("2\n3\n", io.outputString, "should print expected lines")
    }

    func testIfGreaterThanOrEqualTo() {
        io.inputString = lines(
            "IF 0 >= 0 THEN PRINT 1",
            "IF 1 >= 9 THEN PRINT 2",
            "IF 99>  =-99 THEN PRINT 3"
            )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("1\n3\n", io.outputString, "should print expected lines")
    }

    func testListPrettyPrint() {
        io.inputString = lines(
            " 2 0   if  y < ( x + 1 )  then print \"foo\", \"bar\"  ",
            " 3 0   go to x  +100  ",
            "   1 0  pr \"Hello\", \"world\"  ",
            " 4 0  in z  ,y  ,  x  ",
            " 5 0   let x = 10*y + (2 * z  )  ",
            " 7 0   re TURN  ",
            " 8 0  c lE  ar   ",
            " 9 0   Lis t  ",
            " 6 0   go sub 3 9 9  ",
            "  1 0 0   r u n  ",
            " 1   1 0  e n   d  ",
            " 1    2 0   t r   o N  ",
            "  1  3  0    tr  off  ",

            "list",
            ""
        )

        interpreter.runUntilEndOfInput()

        let expectedOutput = lines(
            "10 PRINT \"Hello\", \"world\""                 ,
            "20 IF Y < (X + 1) THEN PRINT \"foo\", \"bar\"" ,
            "30 GOTO X + 100"                               ,
            "40 INPUT Z, Y, X"                              ,
            "50 LET X = 10 * Y + (2 * Z)"                   ,
            "60 GOSUB 399"                                  ,
            "70 RETURN"                                     ,
            "80 CLEAR"                                      ,
            "90 LIST"                                       ,
            "100 RUN"                                       ,
            "110 END"                                       ,
            "120 TRON"                                      ,
            "130 TROFF"                                     ,
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected lines")
    }

    func testRun() {
        io.inputString = lines(
            "10 print \"hello\"",
            "20 print \"world\"",
            "30 end",
            "run"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("hello\nworld\n", io.outputString, "should print expected lines")
    }

    func testRunWithoutEnd() {
        io.inputString = "10 print \"hello\"\n20 print \"world\"\nrun\n"

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(1, io.errors.count, "should have error due to lack of END")
        XCTAssertEqual("hello\nworld\n", io.outputString, "should print expected lines")
    }

    func testGoto() {
        io.inputString = lines(
            "10 print \"hello\"",
            "15 goto 30",
            "20 print \"world\"",
            "30 end",
            "run"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("hello\n", io.outputString, "should print expected lines")
    }

    func testGosub() {
        io.inputString = lines(
            "10 gosub 100",
            "20 gosub 200",
            "30 gosub 100",
            "40 end",
            "100 print \"hello\"",
            "110 return",
            "200 print \"goodbye\"",
            "210 return",
            "run"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("hello\ngoodbye\nhello\n", io.outputString, "should print expected lines")
    }

    func testRem() {
        io.inputString = lines(
            "10  rem-This is a comment",
            "20  end",
            "list",
            "run"
            )

        let expectedOutput = lines(
            "10 REM-This is a comment",
            "20 END",
            ""
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected lines")
    }

    func testRemTick() {
        io.inputString = lines(
            "10  ' This is a comment",
            "20  end",
            "list",
            "run"
        )

        let expectedOutput = lines(
            "10 REM This is a comment",
            "20 END",
            ""
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected lines")
    }
    
    func testClear() {
        io.inputString = lines(
            "10  rem-This is a comment",
            "20  end",
            "clear",
            "list"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("", io.outputString, "should print nothing")
    }

    func testInput() {
        io.inputString = lines(
            "10 print \"Enter three numbers:\""      ,
            "20 input a, b, c"                       ,
            "30 print \"The numbers are \", a, b, c" ,
            "40 end"                                 ,
            "run"                                    ,
            "101, -202, 303"                          ,
            ""
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = "Enter three numbers:\nThe numbers are \t101\t-202\t303\n"

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(1, io.inputPromptCount, "showInputPrompt() should have been called")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testInputWithBadEntry() {
        io.inputString = lines(
            "5 let x = 23"                                     ,
            "10 print \"Enter a number:\""                     ,
            "20 input a"                                       ,
            "30 print \"Enter another number:\""               ,
            "40 input b"                                       ,
            "50 print \"The numbers are \"; a ; \" and \" ; b" ,
            "60 end"                                           ,
            "run"                                              ,

            "$"                                                ,
            "  &"                                              ,
            "101"                                              ,

            ""                                                 ,
            " @"                                               ,
            "x"                                                ,
            ""
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "Enter a number:"             ,
            "Enter another number:"       ,
            "The numbers are 101 and 23" ,
            ""
        )

        XCTAssertEqual(4, io.errors.count, "\(lines(io.errors))")
        XCTAssertEqual(6, io.inputPromptCount, "should call showInputPrompt for each attempt to read")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testPrintWithSemicolons() {
        io.inputString = "print 1; 2, 3; \"hello\""

        interpreter.runUntilEndOfInput()

        var expectedOutput = "12\t3hello\n"

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testPrintWithTrailingSemicolon() {
        io.inputString = lines(
            "10 print \"Hello, \";"  ,
            "20 print \"world!\""    ,
            "30 end"                 ,
            "run"
            )

        interpreter.runUntilEndOfInput()

        var expectedOutput = "Hello, world!\n"

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testPrintWithTrailingComma() {
        io.inputString = lines(
            "10 print \"Hello, \","  ,
            "20 print \"world!\""    ,
            "30 end"                 ,
            "run"
            )

        interpreter.runUntilEndOfInput()

        var expectedOutput = "Hello, \tworld!\n"

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testAsciiArt() {
        io.inputString = lines(
            "10 LET X = 5"               ,
            "20 LET I = X"               ,
            "30 PRINT \"*\";"            ,
            "40 LET I = I - 1"           ,
            "50 IF I > 0 THEN GOTO 30"   ,
            "60 LET X = X - 1"           ,
            "70 IF X = 0 THEN END"       ,
            "80 PRINT \"\""              ,
            "90 GOTO 20"                 ,
            "RUN"
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "*****",
            "****" ,
            "***"  ,
            "**"   ,
            "*"
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testRnd() {
        io.inputString = lines(
            "1 LET N = 1000"                       ,
            "5 LET X = -1"                         ,
            "10 LET X = RND(10)"                   ,
            "20 IF X >= 10 THEN PRINT \"too big\"" ,
            "30 IF X < 0 THEN PRINT \"too small\"" ,
            "40 LET N = N - 1"                     ,
            "50 IF N > 0 THEN GOTO 5"              ,
            "60 END"                               ,
            "RUN"
        )

        interpreter.runUntilEndOfInput()

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual("", io.outputString, "should produce no output")
    }

    func testLetWithoutLet() {
        io.inputString = lines(
            "10 N = 100"   ,
            "20 x = 4"     ,
            "LIST"         ,
            ""
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "10 LET N = 100" ,
            "20 LET X = 4"   ,
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testIfWithoutThen() {
        io.inputString = lines(
            "10 if n = 100 go to 100"                   ,
            "20 if x = 1 if y = 2 if z = 3 print x,y,z" ,
            "LIST"                                      ,
            ""
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "10 IF N = 100 THEN GOTO 100"                                ,
            "20 IF X = 1 THEN IF Y = 2 THEN IF Z = 3 THEN PRINT X, Y, Z" ,
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testLineNumberOnly() {
        io.inputString = lines(
            "10 if n = 100 then go to 100"   ,
            "20 if x = 1 then y = 2"         ,
            "10"                             ,
            "  20  "                         ,
            "LIST"                           ,
            ""
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testPrintWithNoArguments() {
        io.inputString = lines(
            "PRINT"            ,
            "PRINT"            ,
            "PRINT \"hello\""  ,
            "PRINT"            ,
            "PRINT"            ,
            ""
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "",
            "",
            "hello",
            "",
            "",
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testBye() {
        io.inputString = lines(
            "10  b y e"  ,
            "20 END"     ,
            "LIST"       ,
            "RUN"        ,
            ""
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "10 BYE",
            "20 END",
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(1, io.byeCount)
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testLeftAssociativeProductsAndQuotients() {
        io.inputString = lines(
            "print 1999/100*100"
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "1900",
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testLeftAssociativeSumsAndDifferences() {
        io.inputString = lines(
            "print 10-7+100"
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "103",
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testPrecedence() {
        io.inputString = lines(
            "print 3*7+4*9"     ,
            "print 3*(7+4)*9"   ,
            "print 20/2-15*3"
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "57",
            "297",
            "-35",
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testArray() {
        io.inputString = lines(
            "10 let x = 99"                          ,
            "20 print \"Enter three numbers\""       ,
            "30 input @(x), @(x+1), @(x+2)"          ,
            "40 let @(x+3) = @(x) + @(x+1) + @(x+2)" ,
            "50 print \"Their sum is \"; @(x+3)"     ,
            "60 end"                                 ,
            "run"                                    ,
            "123, 456, 789"
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "Enter three numbers" ,
            "Their sum is 1368"   ,
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }

    func testAbbreviations() {
        io.inputString = lines(
            "10  p r 99"                              ,
            "20 ? \"hello, world\""                   ,
            "30  i n @(x), @(x+1), @(x+2)"            ,
            "40  g t 100"                             ,
            "50  g s 200"                             ,
            "60  r t"                                 ,
            "70  l s"                                 ,
            "80  r n"                                 ,
            "90  s v \"foo.bas\""                     ,
            "100  l d \"foo.bas\""                    ,
            "list",
            ""
        )

        interpreter.runUntilEndOfInput()

        var expectedOutput = lines(
            "10 PRINT 99"                       ,
            "20 PRINT \"hello, world\""         ,
            "30 INPUT @(X), @(X + 1), @(X + 2)" ,
            "40 GOTO 100"                       ,
            "50 GOSUB 200"                      ,
            "60 RETURN"                         ,
            "70 LIST"                           ,
            "80 RUN"                            ,
            "90 SAVE \"foo.bas\""               ,
            "100 LOAD \"foo.bas\""              ,
            ""
        )

        XCTAssertEqual(0, io.errors.count, "unexpected \"\(io.firstError)\"")
        XCTAssertEqual(expectedOutput, io.outputString, "should print expected output")
    }
}
