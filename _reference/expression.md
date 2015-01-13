---
layout: page
title: Expression
---

Numeric expression


## Syntax Diagram

![Syntax diagram](/diagram/expression.png)


## Also See

- [number](/reference/number)
- [variable](/reference/variable)
- [array-element](/reference/array-element)


## Details

The interpreter evaluates expressions to produce numeric values.

Arithmetic operators have their standard precedences. That is, `1+2*3+4` is evaluated as `1+(2*3)+4`, not as `(((1+2)*3)+4)`.

The `RND(n)` function returns a random number between 0 and (_n_ - 1), inclusive.  Add one to the result if you want a random number between 1 and _n_.


## Examples

    PRINT "The sum is " ; A + B + C
    LET @(N+1) = Y * (Z + 1)

    10 REM Find remainder from dividing X by Y
    20 LET R = X - X/Y*Y

    10 REM Simulate roll of a six-sided die
    20 LET D = RND(6) + 1
    30 PRINT "You rolled " ; D

