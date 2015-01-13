---
layout: page
title: RUN statement
---

Execute the program in memory.


## Syntax Diagram

![Syntax diagram](/diagram/RUN-statement.png)


## Also See

- [END](/reference/end)


## Details

`RUN` starts running the program at its first line.

The interpreter runs the program until it reaches an [END](/reference/end) statement, an error occurs, or the user kills the program with Break/Ctrl-C.


## Examples

    10 PRINT "Hello, world!"
    20 END
    RUN

