---
layout: page
title: Variable
---

A stored numeric value


## Syntax Diagram

![Syntax diagram](/diagram/variable.png)


## Also See

- [expression](/reference/expression)
- [LET statement](/reference/let)
- [INPUT statement](/reference/input)
- [array-element](/reference/array-element)


## Details

The BitsyBASIC interpreter provides 26 global variables, named `A`, `B`, `C`, ..., `Y`, `Z`.

All variables have the value zero when the interpreter starts, and are reset to zero by the [CLEAR statement](/reference/clear).

Variable values are used in expressions.  Variable values can be set with the [LET statement](/reference/let) and [INPUT statement](/reference/input).


## Examples

    10 LET X = 1
    20 LET Y = 2 * X
    30 PRINT "X + Y = "; X + Y
    40 INPUT A, B

