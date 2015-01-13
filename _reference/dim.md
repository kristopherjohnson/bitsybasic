---
layout: page
title: DIM statement
---

Set array size and clear the array.


## Syntax Diagram

![Syntax diagram](/diagram/DIM-statement.png)


## Also See

- [array-element](/reference/array-element)
- [expression](/reference/expression).


## Details

This statement sets the size of the [`@()`](/reference/array-element) array to the specified size.  All elements of the array are cleared to zero values.


## Examples

    REM  Set array size to 10,000 elements, and set
    REM  values to 0, 1, 2, 3, ..., 9998, 9999.
    10 DIM @(10000)
    20 LET I = 0
    30 LET @(I) = I
    40 LET I = I + 1
    50 IF I < 10000 THEN GOTO 30
    60 END
