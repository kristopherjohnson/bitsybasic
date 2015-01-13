---
layout: page
title: LET statement
---

Assign value to variable or array element


## Syntax Diagram

![Syntax diagram](/diagram/LET-statement.png)


## Also See

- [variable](/reference/variable)
- [array-element](/reference/array-element)
- [expression](/reference/expression)
- [INPUT statement](/reference/input)

## Details

The `LET` statement stores a numeric value to a [variable](/reference/variable) or an [array element](/reference/array-element).

The `LET` keyword is optional. That is, these two statements are equivalent:

    LET X = 1
    X = 1


## Examples

    LET A = B + C
    LET @(20) = A + @(21)
    LET Z = -123 * 456
