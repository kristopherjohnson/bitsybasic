---
layout: page
title: FILES statement
---

List available files


## Syntax Diagram

![Syntax diagram](/diagram/FILES-statement.png)


## Details

The `FILES` command prints a list of the files in the interpreter's working directory. The user can `LOAD` these files.

`FL` is an abbreviation for `FILES`.

On iOS, the working directory is the Documents directory in the app's private sandbox.

On OS X, the working directory is whatever the working directory was when the interpreter started.


## Examples

    FILES
    LOAD "example.bas"
