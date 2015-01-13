---
layout: page
title: SAVE statement
---

Save the program to a file.


## Syntax Diagram

![Syntax diagram](/diagram/SAVE-statement.png)


## Also See

- [string-literal](/reference/string-literal)
- [LOAD statement](/reference/load)
- [CLIPSAVE statement](/reference/clipsave)


## Details

The `SAVE` statement writes the program to a file.  After a program is saved, the user can reload it with the [LOAD](/reference/load) statement.

`SV` is an abbreviation for `SAVE`.


## Examples

    10 PRINT "Hello, world!"
    20 END
    SAVE "hello.bas"

