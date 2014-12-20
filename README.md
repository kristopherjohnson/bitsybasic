# FinchBasic

Copyright 2014 Kristopher Johnson


## Overview

FinchBasic is a dialect of [Tiny BASIC](http://en.wikipedia.org/wiki/Tiny_BASIC), implemented in [Swift](https://developer.apple.com/swift/).

Note: the `INPUT` statement is not yet implemented.  (I'll get to it eventually.)

The syntax and implementation are based upon these online sources:

- The Wikipedia page: <http://en.wikipedia.org/wiki/Tiny_BASIC>
- ["The Return of Tiny Basic"](http://www.drdobbs.com/web-development/the-return-of-tiny-basic/184406381)
- [Tiny Basic User's Manual](http://www.ittybittycomputers.com/IttyBitty/TinyBasic/TBuserMan.htm)
- [TinyBasic.c](http://www.ittybittycomputers.com/IttyBitty/TinyBasic/TinyBasic.c)


## Building

To build the `finchbasic` executable, `cd` to the project directory and do this:

    xcodebuild

The `finchbasic` executable will be in the `build/Release` directory.


## Using

`finchbasic` currently only reads from standard input, writes to standard output, and sends error messages to standard error.

If you want to "load a program" into `finchbasic`, you can do something like this:

    ./finchbasic < myprogram.basic

If you want to "load a program" and then interact, you can do this:

    cat myprogram.basic - | ./finchbasic


## Syntax

FinchBasic supports this syntax:

    line ::= number statement CR | statement CR

    statement ::= PRINT expr-list | PR expr-list | ? expr-list
                  IF expression relop expression THEN statement
                  GOTO expression
                  INPUT var-list
                  LET var = expression
                  GOSUB expression
                  RETURN
                  CLEAR
                  LIST
                  RUN
                  END

    expr-list ::= (string|expression) (, (string|expression) )*

    var-list ::= var (, var)*

    expression ::= (+|-|ε) term ((+|-) term)*

    term ::= factor ((*|/) factor)*

    factor ::= var | number | (expression)

    var ::= A | B | C ... | Y | Z

    number ::= digit digit*

    digit ::= 0 | 1 | 2 | 3 | ... | 8 | 9

    relop ::= < (>|=|ε) | > (<|=|ε) | =
