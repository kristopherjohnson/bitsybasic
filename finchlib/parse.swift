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


// MARK: - Input

/// Input is a "line" consisting of 8-bit ASCII characters
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
        while i < count && input[i] == Ch_Space {
            ++i
        }
        return InputPosition(input, i)
    }

    // MARK: - Parsing

    // The parse() methods take a starting position and a sequence
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
    //         pos.parse(lit("LET"), variable, lit("="), expression)
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
    //
    // Note: These functions were originally defined in a separate source
    // file, but the Swift optimizer generated invalid code.  The workaround
    // was to move the definitions into this file.  For more information,
    // see http://www.openradar.me/19349390
    // and https://twitter.com/jckarter/status/548582743240900609


    /// Parse an element using parsing functions, returning the elements and next input position
    func parse<A> (
        a: (InputPosition) -> (A, InputPosition)?) -> (A, InputPosition)?
    {
        if let (a, afterA) = a(self) {
            return (a, afterA)
        }
        return nil
    }

    /// Parse two elements using parsing functions, returning the elements and next input position
    func parse<A, B> (
        a: (InputPosition) -> (A, InputPosition)?,
        b: (InputPosition) -> (B, InputPosition)?) -> (A, B, InputPosition)?
    {
        if let (a, afterA) = a(self) {
            if let (b, afterB) = b(afterA) {
                return (a, b, afterB)
            }
        }
        return nil
    }

    /// Parse three elements using parsing functions, returning the elements and next input position
    func parse<A, B, C> (
        a: (InputPosition) -> (A, InputPosition)?,
        b: (InputPosition) -> (B, InputPosition)?,
        c: (InputPosition) -> (C, InputPosition)?) -> (A, B, C, InputPosition)?
    {
        if let (a, afterA) = a(self) {
            if let (b, afterB) = b(afterA) {
                if let (c, afterC) = c(afterB) {
                    return (a, b, c, afterC)
                }
            }
        }

        return nil
    }

    /// Parse four elements using parsing functions, returning the elements and next input position
    func parse<A, B, C, D> (
        a: (InputPosition) -> (A, InputPosition)?,
        b: (InputPosition) -> (B, InputPosition)?,
        c: (InputPosition) -> (C, InputPosition)?,
        d: (InputPosition) -> (D, InputPosition)?) -> (A, B, C, D, InputPosition)?
    {
        if let (a, afterA) = a(self) {
            if let (b, afterB) = b(afterA) {
                if let (c, afterC) = c(afterB) {
                    if let (d, afterD) = d(afterC) {
                        return (a, b, c, d, afterD)
                    }
                }
            }
        }

        return nil
    }

    /// Parse five elements using parsing functions, returning the elements and next input position
    func parse<A, B, C, D, E> (
        a: (InputPosition) -> (A, InputPosition)?,
        b: (InputPosition) -> (B, InputPosition)?,
        c: (InputPosition) -> (C, InputPosition)?,
        d: (InputPosition) -> (D, InputPosition)?,
        e: (InputPosition) -> (E, InputPosition)?) -> (A, B, C, D, E, InputPosition)?
    {
        if let (a, afterA) = a(self) {
            if let (b, afterB) = b(afterA) {
                if let (c, afterC) = c(afterB) {
                    if let (d, afterD) = d(afterC) {
                        if let (e, afterE) = e(afterD) {
                            return (a, b, c, d, e, afterE)
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Parse six elements using parsing functions, returning the elements and next input position
    func parse<A, B, C, D, E, F> (
        a: (InputPosition) -> (A, InputPosition)?,
        b: (InputPosition) -> (B, InputPosition)?,
        c: (InputPosition) -> (C, InputPosition)?,
        d: (InputPosition) -> (D, InputPosition)?,
        e: (InputPosition) -> (E, InputPosition)?,
        f: (InputPosition) -> (F, InputPosition)?) -> (A, B, C, D, E, F, InputPosition)?
    {
        if let (a, afterA) = a(self) {
            if let (b, afterB) = b(afterA) {
                if let (c, afterC) = c(afterB) {
                    if let (d, afterD) = d(afterC) {
                        if let (e, afterE) = e(afterD) {
                            if let (f, afterF) = f(afterE) {
                                return (a, b, c, d, e, f, afterF)
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
}

/// Parse a statement
///
/// Returns a parsed statement and position of character
/// following the end of the parsed statement, or nil
// if there is no valid statement.
func statement(pos: InputPosition) -> (Statement, InputPosition)? {

    // "PRINT" [ printList ]
    // "PR" [ printList ]
    // "?" [ printList" ]
    if let (PRINT, afterKeyword) = oneOfLiteral([T_PRINT, T_PR, T_QuestionMark], pos) {
        if let (plist, afterPrintList) = printList(afterKeyword) {
            return (.Print(plist), afterPrintList)
        }
        else {
            return (.PrintNewline, afterKeyword)
        }
    }

    // "LET" lvalue = expression
    // lvalue = expression
    if let (LET, v, EQ, expr, nextPos) =
        pos.parse(optLit(T_LET), lvalue, lit(T_Equal), expression)
    {
        return (.Let(v, expr), nextPos)
    }

    // "INPUT" lvalueList
    // "IN" lvalueList
    if let (INPUT, lvalues, nextPos) =
        pos.parse(oneOfLit(T_INPUT, T_IN), lvalueList)
    {
        return (.Input(lvalues), nextPos)
    }

    // "DIM @(" expr ")"
    if let (DIM, AT, LPAREN, expr, RPAREN, nextPos) =
        pos.parse(lit(T_DIM), lit(T_At), lit(T_LParen), expression, lit(T_RParen))
    {
        return (.DimArray(expr), nextPos)
    }

    // "IF" lhs relop rhs "THEN" statement
    // "IF" lhs relop rhs statement
    if let (IF, lhs, op, rhs, THEN, stmt, nextPos) =
        pos.parse(lit(T_IF), expression, relop, expression, optLit(T_THEN), statement)
    {
        return (.If(lhs, op, rhs, Box(stmt)), nextPos)
    }

    // "GOTO" expression
    if let (GOTO, expr, nextPos) =
        pos.parse(oneOfLit(T_GOTO, T_GT), expression)
    {
        return (.Goto(expr), nextPos)
    }

    // "GOSUB" expression
    if let (GOSUB, expr, nextPos) =
        pos.parse(oneOfLit(T_GOSUB, T_GS), expression)
    {
        return (.Gosub(expr), nextPos)
    }

    // "REM" commentstring
    // "'" commentstring
    if let (REM, comment, nextPos) =
        pos.parse(oneOfLit(T_REM, T_Tick), remainderOfLine)
    {
        return (.Rem(comment), nextPos)
    }

    // "LIST"
    // "LIST" expression
    // "LIST" expression "," expression
    if let (LIST, from, COMMA, to, nextPos) =
        pos.parse(oneOfLit(T_LIST, T_LS), expression, lit(T_Comma), expression)
    {
        return (.List(.Range(from, to)), nextPos)
    }
    else if let (LIST, lineNumber, nextPos) =
        pos.parse(oneOfLit(T_LIST, T_LS), expression)
    {
        return (.List(.SingleLine(lineNumber)), nextPos)
    }
    else if let (LIST, nextPos) = oneOfLiteral([T_LIST, T_LS], pos)
    {
        return (.List(.All), nextPos)
    }

    // "SAVE" filenamestring
    if let (SAVE, filename, nextPos) =
        pos.parse(oneOfLit(T_SAVE, T_SV), stringLiteral)
    {
        return (.Save(stringFromChars(filename)), nextPos)
    }

    // "LOAD" filenamestring
    if let (LOAD, filename, nextPos) =
        pos.parse(oneOfLit(T_LOAD, T_LD), stringLiteral)
    {
        return (.Load(stringFromChars(filename)), nextPos)
    }

    // For statements that consist only of a keyword, we can use a simple table
    let simpleStatements: [(String, Statement)] = [
        (T_RETURN,   .Return),
        (T_RT,       .Return),
        (T_RUN,      .Run   ),
        (T_END,      .End   ),
        (T_CLEAR,    .Clear ),
        (T_BYE,      .Bye   ),
        (T_FILES,    .Files ),
        (T_FL,       .Files ),
        (T_CLIPSAVE, .ClipSave),
        (T_CLIPLOAD, .ClipLoad),
        (T_TRON,     .Tron  ),
        (T_TROFF,    .Troff ),
        (T_HELP,     .Help  )
    ]
    for (token, stmt) in simpleStatements {
        if let (TOKEN, nextPos) = literal(token, pos) {
            return (stmt, nextPos)
        }
    }

    return nil
}

/// Attempt to parse a PrintList.
///
/// Returns PrintList and position of next character if successful.  Returns nil otherwise.
func printList(pos: InputPosition) -> (PrintList, InputPosition)? {
    if let (item, afterItem) = printItem(pos) {

        if let (_, afterSep) = literal(T_Comma, afterItem) {
            // "," printList
            // "," (trailing at end of line)

            if let (tail, afterTail) = printList(afterSep) {
                return (.Items(item, .Tab, Box(tail)), afterTail)
            }
            else if afterSep.isRemainingLineEmpty {
                return (.Item(item, .Tab), afterSep)
            }
        }
        else if let (_, afterSep) = literal(T_Semicolon, afterItem) {
            // ";" printList
            // ";" (trailing at end of line)

            if let (tail, afterTail) = printList(afterSep) {
                return (.Items(item, .Empty, Box(tail)), afterTail)
            }
            else if afterSep.isRemainingLineEmpty {
                // trailing semicolon
                return (.Item(item, .Empty), afterSep)
            }
        }

        return (.Item(item, .Newline), afterItem)
    }

    return nil
}

/// Attempt to parse a PrintItem.
///
/// Returns PrintItem and position of next character if successful.  Returns nil otherwise.
func printItem(pos: InputPosition) -> (PrintItem, InputPosition)? {
    if let (s, afterChars) = stringLiteral(pos) {
        return (.Str(s), afterChars)
    }

    if let (expr, afterExpr) = expression(pos) {
        return (.Expr(expr), afterExpr)
    }

    return nil
}

/// Attempt to parse a LvalueList.
///
/// Returns LvalueList and position of next character if successful.  Returns nil otherwise.
func lvalueList(pos: InputPosition) -> (LvalueList, InputPosition)? {
    // lvalue
    if let (item, afterItem) = lvalue(pos) {

        // "," lvalueList
        if let (_, afterSep) = literal(T_Comma, afterItem) {
            if let (tail, afterTail) = lvalueList(afterSep) {
                return (.Items(item, Box(tail)), afterTail)
            }
        }

        return (.Item(item), afterItem)
    }

    return nil
}

/// Attempt to parse an Expression.
///
/// Returns Expression and position of next character if successful.  Returns nil if not.
func expression(pos: InputPosition) -> (Expression, InputPosition)? {
    if let (PLUS, uexpr, nextPos) =
        pos.parse(lit(T_Plus), unsignedExpression)
    {
        return (.Plus(uexpr), nextPos)
    }

    if let (MINUS, uexpr, nextPos) =
        pos.parse(lit(T_Minus), unsignedExpression)
    {
        return (.Minus(uexpr), nextPos)
    }

    if let (uexpr, nextPos) = unsignedExpression(pos) {
        return (.UnsignedExpr(uexpr), nextPos)
    }

    return nil
}

/// Attempt to parse an UnsignedExpression.
///
/// Returns UnsignedExpression and position of next character if successful.  Returns nil if not.
func unsignedExpression(pos: InputPosition) -> (UnsignedExpression, InputPosition)? {
    if let (t, afterTerm) = term(pos) {

        // If followed by "+", then it's addition
        if let (PLUS, uexpr, afterExpr) =
            afterTerm.parse(lit(T_Plus), unsignedExpression)
        {
            return (.Compound(t, ArithOp.Add, Box(uexpr)), afterExpr)
        }

        // If followed by "-", then it's subtraction
        if let (MINUS, uexpr, afterExpr) =
            afterTerm.parse(lit(T_Minus), unsignedExpression)
        {
            return (.Compound(t, ArithOp.Subtract, Box(uexpr)), afterExpr)
        }

        // Otherwise, just a simple term
        return (.Value(t), afterTerm)
    }

    return nil
}

/// Attempt to parse a Term.
///
/// Returns Term and position of next character if successful.  Returns nil if not.
func term(pos: InputPosition) -> (Term, InputPosition)? {
    if let (fact, afterFact) = factor(pos) {

        // If followed by "*", then it's a product
        if let (MULT, t, afterTerm) =
            afterFact.parse(lit(T_Asterisk), term)
        {
            return (.Compound(fact, ArithOp.Multiply, Box(t)), afterTerm)
        }

        // If followed by "/", then it's a quotient
        if let (DIV, t, afterTerm) =
            afterFact.parse(lit(T_Slash), term)
        {
            return (.Compound(fact, ArithOp.Divide, Box(t)), afterTerm)
        }

        // Otherwise, just a simple term
        return (.Value(fact), afterFact)
    }

    return nil
}

/// Attempt to parse a Factor.  Returns Factor and position of next character if successful.  Returns nil if not.
func factor(pos: InputPosition) -> (Factor, InputPosition)? {
    // number
    if let (num, afterNum) = numberLiteral(pos) {
        return (.Num(num), afterNum)
    }

    // "RND(" expression ")"
    if let (RND, LPAREN, expr, RPAREN, nextPos) =
        pos.parse(lit(T_RND), lit(T_LParen), expression, lit(T_RParen))
    {
        return (.Rnd(Box(expr)), nextPos)
    }

    // "(" expression ")"
    if let (LPAREN, expr, RPAREN, nextPos) =
        pos.parse(lit(T_LParen), expression, lit(T_RParen))
    {
        return (.ParenExpr(Box(expr)), nextPos)
    }

    // "@(" expression ")"
    if let (AT, LPAREN, expr, RPAREN, nextPos) =
        pos.parse(lit(T_At), lit(T_LParen), expression, lit(T_RParen))
    {
        return (.ArrayElement(Box(expr)), nextPos)
    }

    // variable
    if let (variableName, afterVar) = variableName(pos) {
        return (.Var(variableName), afterVar)
    }

    return nil
}

/// Determine whether the remainder of the line starts with a specified sequence of characters.
///
/// If true, returns position of the character following the matched string. If false, returns nil.
///
/// Matching is case-insensitive. Spaces in the input are ignored.
func literal(s: String, pos: InputPosition) -> (String, InputPosition)? {
    let chars = charsFromString(s)
    var matchCount = 0
    var matchGoal = chars.count

    var i = pos
    loop: while (matchCount < matchGoal) && !i.isAtEndOfLine {
        let c = i.char
        i = i.next

        if c == Ch_Space {
            continue loop
        }
        else if toUpper(c) == toUpper(chars[matchCount]) {
            ++matchCount
        }
        else {
            return nil
        }
    }

    if matchCount == matchGoal {
        return (s, i)
    }

    return nil
}

/// Curried variant of `literal()`, for use with `parse()`
func lit(s: String)(pos: InputPosition) -> (String, InputPosition)? {
    return literal(s, pos)
}

/// Check for a literal at the specified position.
///
/// If the literal is present, then return it and the following position.
///
/// If the literal is not present, then just return it and the original position.
///
/// This is used in situations where a statement allows an optional keyword,
/// such as LET or THEN, that can be ignored if present.
func optLiteral(s: String, pos: InputPosition) -> (String, InputPosition)? {
    if let (lit, nextPos) = literal(s, pos) {
        return (lit, nextPos)
    }

    return (s, pos)
}

/// Curried variant of `optLiteral`, for use with `parse()`.
func optLit(s: String)(pos: InputPosition) -> (String, InputPosition)? {
    return optLiteral(s, pos)
}

/// Try to parse one of a set of literals
///
/// Returns first match, or nil if there are no matches
func oneOfLiteral(strings: [String], pos: InputPosition) -> (String, InputPosition)? {
    for s in strings {
        if let match = literal(s, pos) {
            return match
        }
    }
    return nil
}

/// Curried form of `oneOfLiteral()`, for use with `parse`
func oneOfLit(strings: String...)(pos: InputPosition) -> (String, InputPosition)? {
    return oneOfLiteral(strings, pos)
}

/// Attempt to read an unsigned number from input.  If successful, returns
/// parsed number and position of next input character.  If not, returns nil.
func numberLiteral(pos: InputPosition) -> (Number, InputPosition)? {
    var i = pos.afterSpaces()

    if i.isAtEndOfLine {
        return nil
    }

    if !isDigitChar(i.char) {
        // doesn't start with a digit
        return nil
    }

    var num = Number(i.char - Ch_0)
    i = i.next
    loop: while !i.isAtEndOfLine {
        let c = i.char
        if isDigitChar(c) {
            num = (num &* 10) &+ Number(c - Ch_0)
        }
        else if c != Ch_Space {
            break loop
        }
        i = i.next
    }

    return (num, i)
}

/// Attempt to parse a string literal
///
/// Returns characters and position of next character if successful.
/// Returns nil otherwise.
func stringLiteral(pos: InputPosition) -> ([Char], InputPosition)? {
    var i = pos.afterSpaces()
    if !i.isAtEndOfLine {
        if i.char == Ch_DQuote {
            i = i.next
            var stringChars: [Char] = Array()
            var foundTrailingDelim = false

            loop: while !i.isAtEndOfLine {
                let c = i.char
                i = i.next
                if c == Ch_DQuote {
                    foundTrailingDelim = true
                    break loop
                }
                else {
                    stringChars.append(c)
                }
            }

            if foundTrailingDelim {
                return (stringChars, i)
            }
        }
    }

    return nil
}

/// Attempt to parse an Lvalue (variable name or array element reference)
///
/// Returns Lvalue and position of next input character on success, or nil otherwise.
func lvalue(pos: InputPosition) -> (Lvalue, InputPosition)? {
    if let (v, nextPos) = variableName(pos) {
        return (.Var(v), nextPos)
    }

    if let (AT, LPAREN, expr, RPAREN, nextPos) =
        pos.parse(lit(T_At), lit(T_LParen), expression, lit(T_RParen))
    {
        return (.ArrayElement(expr), nextPos)
    }

    return nil
}

/// Attempt to parse an Lvalue (variable name or array element reference) from a String
///
/// Returns Lvalue if successful, or nil if the string cannot be parsed as an Lvalue.
func lvalue(s: String) -> Lvalue? {
    let inputLine = charsFromString(s)
    var inputPosition = InputPosition(inputLine, 0)
    if let (lvalue, nextPos) = lvalue(inputPosition) {
        return lvalue
    }

    return nil
}

/// Attempt to read a variable name.
///
/// Returns variable name and position of next input character on success, or nil otherwise.
func variableName(pos: InputPosition) -> (VariableName, InputPosition)? {
    let i = pos.afterSpaces()
    if !i.isAtEndOfLine {
        let c = i.char
        if isAlphabeticChar(c) {
            return (toUpper(c), i.next)
        }
    }

    return nil
}

/// Attempt to read a relational operator (=, <, >, <=, >=, <>, ><)
///
/// Returns operator and position of next input character on success, or nil otherwise.
func relop(pos: InputPosition) -> (RelOp, InputPosition)? {
    // Note: We need to test the longer sequences before the shorter
    if let (op, nextPos) = literal(T_LessOrEqual, pos) {
        return (.LessOrEqual, nextPos)
    }
    if let (op, nextPos) = literal(T_GreaterOrEqual, pos) {
        return (.GreaterOrEqual, nextPos)
    }
    if let (op, nextPos) = literal(T_NotEqual, pos) {
        return (.NotEqual, nextPos)
    }
    if let (op, nextPos) = literal(T_NotEqualAlt, pos) {
        return (.NotEqual, nextPos)
    }
    if let (op, nextPos) = literal(T_Less, pos) {
        return (.Less, nextPos)
    }
    if let (op, nextPos) = literal(T_Greater, pos) {
        return (.Greater, nextPos)
    }
    if let (op, nextPos) = literal(T_Equal, pos) {
        return (.Equal, nextPos)
    }

    return nil
}

/// Return the remaining characters in the line as a String
func remainderOfLine(pos: InputPosition) -> (String, InputPosition)? {
    return (stringFromChars(pos.remainingChars), pos.endOfLine)
}

/// Parse user entry for INPUT
///
/// Return parsed number and following position if successful, or nil otherwise.
///
/// Accepts entry of a number with optional leading sign (+|-), or a variable name.
func inputExpression(v: VariableBindings, pos: InputPosition) -> (Number, InputPosition)? {
    // number
    if let (num, nextPos) = numberLiteral(pos) {
        return (num, nextPos)
    }

    // "+" number
    if let (PLUS, num, nextPos) = pos.parse(lit(T_Plus), numberLiteral) {
        return (num, nextPos)
    }

    // "-" number
    if let (MINUS, num, nextPos) = pos.parse(lit(T_Minus), numberLiteral) {
        return (-num, nextPos)
    }

    // variable
    if let (varname, nextPos) = variableName(pos) {
        return (v[varname] ?? 0, nextPos)
    }

    return nil
}

