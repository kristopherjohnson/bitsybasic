---
layout: page
title: INPUT statement
---

Read numeric input from user


## Syntax Diagram

![Syntax diagram](/diagram/INPUT-statement.png)


## Also See

- [variable](/reference/variable)
- [array-element](/reference/array-element)


## Details

The `INPUT` statement displays a "?" prompt and then waits for the user to enter one or more numeric values.  Those values will be stored in the specified variables and/or array elements.

If there is more than one input value, the user must separate the values with a comma.

In addition to numeric values, the user may specify a single alphabetic character for a value.  The value of the associated variable with be the value stored.  This allows for simple character-based input, as shown in the example.


## Examples

    10 REM - Add two numbers
    20 PRINT "Enter a number:"
    30 INPUT A
    40 PRINT "Enter another number:"
    50 INPUT B
    60 PRINT "The sum of " ; A ; " and " ; B ; " is " ; (A+B)
    70 END

    10 REM - Multiply three numbers
    20 PRINT "Enter three numbers:"
    30 INPUT A, B, C
    40 PRINT A;"*";B;"*";C;"=";A*B*C
    50 END

    10 REM - Allow user to respond with 'Y' or 'N'
    20 LET Y = 1
    30 LET N = 0
    40 PRINT "Is it a nice day (Y/N)"
    50 INPUT A
    60 IF A = Y THEN PRINT "Good"
    70 IF A = N THEN PRINT "Too bad"
    80 IF A < N THEN GOTO 40
    90 IF A > Y THEN GOTO 40
    100 END

