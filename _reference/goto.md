---
layout: page
title: GOTO statement
---

Jump to another program location


## Syntax Diagram

![Syntax diagram](/diagram/GOTO-statement.png)


## Also See

- [expression](/reference/expression)
- [GOSUB statement](/reference/gosub)


## Details

The `GOTO` statement causes the interpreter to jump to the specified location in the program, rather than executing the following statement.

`GOTO` is usually used in conjunction with [IF](/reference/if) to conditionally branch to another section of code.

## Examples

    10 REM - Roll die until we get a six
    20 LET D = RND(6) + 1
    30 PRINT "Rolled a " ; D
    30 IF D = 6 THEN GOTO 50
    40 GOTO 20
    50 PRINT "We're done!"
    60 END

    10 REM - This program will not stop until user hits Break
    20 PRINT "BitsyBASIC is cool!  ";
    30 GOTO 20

    10 REM - The line number can be an evaluated expression
    20 GOTO 100 + N * 10
    100 PRINT "N is 0"
    101 GOTO 200
    110 PRINT "N is 1"
    111 GOTO 200
    120 PRINT "N is 2"
    121 GOTO 200
    200 PRINT "We're done"
    210 END
