---
layout: page
title: GOSUB statement
---

Call a subroutine


## Syntax Diagram

![Syntax diagram](/diagram/GOSUB-statement.png)


## Also See

- [expression](/reference/expression)
- [RETURN statement](/reference/return)
- [GOTO statement](/reference/goto)

## Details

The `GOSUB` statement saves the current program location to the return stack, and then jumps to the specified line number.  A subsequent use of [RETURN](/reference/return) will cause the program to jump back to the line following the `GOSUB`.

`GS` is an abbreviation for `GOSUB`.


## Examples

    10 LET X = 2
    20 REM - Square twice
    20 GOSUB 100
    30 GOSUB 100
    40 PRINT "The final value of X is " ; X
    50 END
    100 REM - Square X
    110 LET X = X * X
    120 RETURN

