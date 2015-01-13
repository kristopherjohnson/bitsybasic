---
layout: page
title: LOAD statement
---

Load a program from a file


## Syntax Diagram

![Syntax diagram](/diagram/LOAD-statement.png)


## Also See

- [string-literal](/reference/string-literal/)
- [SAVE statement](/reference/save)
- [FILES statement](/reference/files)
- [CLEAR statement](/reference/clear)
- [CLIPLOAD statement](/reference/clipload)


## Details

The `LOAD` command reads a program from a file.

`LD` is an abbreviation for `LOAD`.

If there is already a program in memory, then `LOAD` will merge the file's contents into the existing program, replacing any existing lines with matching numbers and inserting lines where those line numbers do not already exist.  Use the [CLEAR](/reference/clear) command before `LOAD` to ensure you start with no loaded program.

Use the [FILES](/reference/files) command to get a list of the files that can be loaded.


## Examples

    CLEAR
    FILES
    LOAD "myprogram.bas"
