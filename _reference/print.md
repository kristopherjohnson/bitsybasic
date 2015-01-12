---
layout: page
title: PRINT statement
---

Send characters to the display


## Syntax Diagram

![Syntax diagram](/diagram/PRINT-statement.png)

Also see [expression](/expression/) and [string-literal](/string-literal/).


## Details

A `PRINT` statement with no arguments sends a newline character to the display.

A `PRINT` statement with arguments will print those arguments. When arguments are separated by a semicolon, then they will be displayed with no separator between them.  When arguments are separated by a comma, they will be aligned in columns (a TAB character is sent to the output).

By default, a `PRINT` statement will send a newline character to the display after processing all the arguments. If a semicolon is present at the end of the statement, then this newline will be suppressed, and so a subsequent `PRINT` statement will continue at position where the last one finished. If a comma is present at the end of the line, then a TAB character is sent to the display instead of a newline.

`PR` and `?` are abbreviations for the `PRINT` keyword.


## Examples

    PRINT
    PRINT X, Y, Z
    PRINT "The sum of " ; X ; " and " ; Y ; " is " ; (X + Y)
