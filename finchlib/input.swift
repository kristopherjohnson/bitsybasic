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
        while i < count && input[i] == Char_Space {
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

