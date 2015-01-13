---
layout: page
title: RETURN statement
---

Return from subroutine


## Syntax Diagram

![Syntax diagram](/diagram/RETURN-statement.png)


## Also See

- [GOSUB statement](/reference/gosub)


## Details

A `RETURN` statement pops a program location from the return stack and jumps to that location.  It is used to return from a subroutine that was entered by using [GOSUB](/reference/gosub).


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

