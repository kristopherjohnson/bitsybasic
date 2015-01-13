---
layout: page
title: array-element
---

An element of the array


## Syntax Diagram

![Syntax diagram](/diagram/array-element.png)


## Also See

- [expression](/reference/expression/)
- [LET statement](/reference/let)
- [INPUT statement](/reference/input)
- [variable](/reference/variable)


## Details

BitsyBASIC provides an array of numbers whose elements are accessed using the notation `@( index )`, where `index` is a zero-based index into the array. `@(0)` is the first element, `@(1)` is the second element, and so on.

By default, there are 1024 elements in the array, so the last element is `@(1023)`. Use the [DIM statement](/reference/dim) to change the size of the array.

Negative subscripts refer to elements as an offset from the end. `@(-1)` is the last element, `@(-2)` is the next-to-last element, and so on.

Results are undefined if the `index` is too large or too small for the array size.


## Examples

    INPUT @(0), @(1)
    PRINT @(0) ; " + " ; @(1) ; " = " ; @(0) + @(1)
    IF X < 1024 THEN LET @(X) = Y
