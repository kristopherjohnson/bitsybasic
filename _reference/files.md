---
layout: page
title: FILES statement
---

List available files


## Syntax Diagram

![Syntax diagram](/diagram/FILES-statement.png)


## Also See

- [LOAD statement](/reference/load)
- [SAVE statement](/reference/save)


## Details

The `FILES` command prints a list of the files in the interpreter's working directory. The user can use the [LOAD statement](/reference/load) to read a program into memory.

`FL` is an abbreviation for `FILES`.


## Examples

    FILES
    LOAD "example.bas"
