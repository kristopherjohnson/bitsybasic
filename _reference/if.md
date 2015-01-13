---
layout: page
title: IF statement
---

Conditional execution


## Syntax Diagram

![Syntax diagram](/diagram/IF-statement.png)


## Also See

- [expression](/reference/expression)


## Details

The `IF` statement evaluates a condition, and if it is true, executes a statement.

The condition consists of two expressions separated by a relational operator.  The relational operators are

- `=` (equal to)
- `<` (less than)
- `<=` (less than or equal to)
- `>` (greater than)
- `>=` (greater than or equal to)
- `<>` or `><` (not equal)

The `THEN` keyword between the condition and the statement is optional.  That is, these two statements are equivalent:

    IF X = Y THEN GOTO 200
    IF X = Y GOTO 200


## Examples

    IF X = Y THEN PRINT "X and Y are equal"
    IF X <> Y THEN PRINT "X and Y are not equal"
    IF X + Z > Y + 100 THEN GOSUB 250
    IF X < Y THEN IF Y < Z THEN PRINT "Y is between X and Z"
