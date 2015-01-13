---
layout: page
title: LIST statement
---

Display the program


## Syntax Diagram

![Syntax diagram](/diagram/LIST-statement.png)


## Also See

- [expression](/reference/expression)


## Details

The `LIST` command displays program text.

`LS` is an abbreviation for `LIST`.

If the statement is used with no arguments, it displays the entire program.

If the statement is used with a single argument, it displays the line with that number.

If the statement is used with two arguments, it displays the lines in the range between the two numbers.


## Examples

    REM - Display entire program
    LIST

    REM - Display line 100
    LIST 100

    REM - Display lines 1000-1500
    LIST 1000,1500

