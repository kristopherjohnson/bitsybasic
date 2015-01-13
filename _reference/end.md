---
layout: page
title: END statement
---

Stop the program.


## Syntax Diagram

![Syntax diagram](/diagram/END-statement.png)


## Details

The `END` statement stops the running program and returns the interpreter to command mode.

All programs should terminate with an `END` statement.  The interpreter will display an error message it has to terminate because it has executed the last program statement rather than because it encountered `END`


## Examples

    10 REM  Simple program
    20 PRINT "Hello, world!"
    30 END

    10 REM Count to ten
    20 N = 1
    30 PRINT N
    40 N = N + 1
    50 IF N > 10 THEN END
    60 GOTO 30


