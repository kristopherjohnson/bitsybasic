---
layout: page
title: CLIPLOAD statement
---

Read program from clipboard


## Syntax Diagram

![Syntax diagram](/diagram/CLIPLOAD-statement.png)


## Also See

- [LOAD statement](/reference/load)


## Details

Loads a program from the system clipboard.

This statement is similar to [LOAD](/reference/load), but instead of reading a program from a file it reads it from the clipboard.  This allows the user to copy a program from another app by selecting its text and choosing the Copy command, and then "pasting" it into BitsyBASIC by executing `CLIPLOAD`.


## Examples

    REM Clear program, load new program, and show it
    CLEAR
    CLIPLOAD
    LIST

