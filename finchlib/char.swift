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


/// An input/output character is an 8-bit value
///
/// Note: In most cases, Finch will ignore any character values
/// that fall outside the 7-bit ASCII graphical character range.
public typealias Char = UInt8

// ASCII/UTF8 character codes that we use
let Char_Tab:       Char = 9   // '\t'
let Char_Linefeed:  Char = 10  // '\n'
let Char_Space:     Char = 32  // ' '
let Char_DQuote:    Char = 34  // '"'
let Char_Comma:     Char = 44  // ','
let Char_0:         Char = 48  // '0'
let Char_9:         Char = 57  // '9'
let Char_LAngle:    Char = 60  // '<'
let Char_RAngle:    Char = 62  // '>'
let Char_Equal:     Char = 61  // '='
let Char_Colon:     Char = 58  // ':'
let Char_Semicolon: Char = 59  // ';'
let Char_A:         Char = 65  // 'A'
let Char_Z:         Char = 90  // 'Z'
let Char_a:         Char = 97  // 'a'
let Char_z:         Char = 122 // 'z'
let Char_Tilde:     Char = 126 // '~'

/// Return true if `c` is a printable ASCII character, or false otherwise
func isGraphicChar(c: Char) -> Bool {
    return Char_Space <= c && c <= Char_Tilde
}

/// Return true if `c` is in the range 'A'...'Z' or 'a'...'z', or false otherwise
func isAlphabeticChar(c: Char) -> Bool {
    return (Char_A <= c && c <= Char_Z) || (Char_a <= c && c <= Char_z)
}

/// Return true if `c` is in the range '0'...'9', or false otherwise
func isDigitChar(c: Char) -> Bool {
    return Char_0 <= c && c <= Char_9
}

/// If `c` is in the range 'a'...'z', then return the uppercase variant of that character.
/// Otherwise, return `c`.
func toUpper(c: Char) -> Char {
    if Char_a <= c && c <= Char_z {
        return c - (Char_a - Char_A)
    }
    else {
        return c
    }
}

/// Given array of Char, return a null-terminated array of CChar
public func cStringFromChars(chars: [Char]) -> [CChar] {
    var cchars: [CChar] = Array(count: chars.count + 1, repeatedValue: 0)
    for i in 0..<chars.count {
        cchars[i] = CChar(chars[i])
    }
    return cchars
}

/// Given array of Char, return a String
public func stringFromChars(chars: [Char]) -> String {
    let cString = cStringFromChars(chars)
    if let result = String.fromCString(cString) {
        return result
    }

    // This will only happen if String.fromCString() fails, which
    // should never happen unless the input string contains invalid
    // UTF8
    assert(false, "unable to convert 8-bit characters to String")
    return ""
}

/// Given a single Char, return a single-character String
public func stringFromChar(c: Char) -> String {
    let chars = [c]
    return stringFromChars(chars)
}

/// Given a string, return array of Chars
public func charsFromString(s: String) -> [Char] {
    return Array(s.utf8)
}
