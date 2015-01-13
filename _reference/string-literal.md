---
layout: page
title: string-literal
---

A string of characters


## Syntax Diagram

![Syntax diagram](/diagram/string-literal.png)


## Also See

- [PRINT statement](/reference/print)
- [SAVE statement](/reference/save)
- [LOAD statement](/reference/load)


## Details

String literals are used to specify output text for a [PRINT statement](/reference/print), and are also used to specify filenames for the [SAVE](/reference/save) and [LOAD](/reference/load) statements.

The string value consists of the characters between the two double-quote (") characters.  Note that there is no way to include a double-quote character within a string literal, nor any way to include a non-printing character.


## Examples

    10 PRINT "Hello, world!"
    SAVE "file.basic"
    LOAD "file.basic"

