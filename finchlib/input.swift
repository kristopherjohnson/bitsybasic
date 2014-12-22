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
        return skipSpaces().index == input.count
    }

    /// Return number of characters following this position (including the character at this position)
    var remainingCount: Int {
        return input.count - index
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
    func skipSpaces() -> InputPosition {
        var i = index
        let count = input.count
        while i < count && input[i] == Char_Space {
            ++i
        }
        return InputPosition(input, i)
    }
}
