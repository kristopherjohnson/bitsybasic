---
layout: page
title: PRINT statement
---

Send characters to the display


## Syntax Diagram

![Syntax diagram](/diagram/PRINT-statement.png)


## Also See

- [expression](/reference/expression)
- [string-literal](/reference/string-literal)


## Details

A `PRINT` statement with no arguments sends a newline character to the display.

A `PRINT` statement with arguments displays those arguments. When arguments are separated by a semicolon, then they are displayed without any separator between them.  When arguments are separated by a comma, they are aligned in columns.

By default, a `PRINT` statement sends a newline character to the display after processing all the arguments. If a semicolon is present at the end of the statement, then the newline is suppressed, and a subsequent `PRINT` statement will continue at position where the last one finished. If a comma is present at the end of the line, then a TAB character is sent to the display instead of a newline.

`PR` and `?` are abbreviations for the `PRINT` keyword.


## Examples

    PRINT
    PRINT X, Y, Z
    PRINT "The sum of " ; X ; " and " ; Y ; " is " ; (X + Y)

    10 REM - Print "One two three" on a single line
    20 PRINT "One ";
    30 PRINT "two ";
    40 PRINT "three"
    50 END
