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

An expression is evaluated by the interpreter to produce a numeric value.

Arithmetic operators have their standard precedences. That is, `1+2*3+4` is evaluated as `1+(2*3)+4`, not as `(((1+2)*3)+4)`.

The `RND(n)` function returns a random number between 0 and n-1, inclusive.


## Examples

    PRINT "The sum is " ; A + B + C
    LET @(N+1) = Y * (Z+1)

