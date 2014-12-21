# FinchBasic

Copyright 2014 Kristopher Johnson


## Overview

FinchBasic is a dialect of [Tiny BASIC](http://en.wikipedia.org/wiki/Tiny_BASIC), implemented in [Swift](https://developer.apple.com/swift/).

The syntax and implementation are based upon these online sources:

- The Wikipedia page: <http://en.wikipedia.org/wiki/Tiny_BASIC>
- [Dr. Dobb's Journal of Tiny BASIC Calisthenics & Orthodontia: Running Light Without Overbyte, Volume 1, Issue 1](http://www.drdobbs.com/architecture-and-design/sourcecode/dr-dobbs-journal-30/30000144)
- ["The Return of Tiny Basic"](http://www.drdobbs.com/web-development/the-return-of-tiny-basic/184406381)
- [Tiny Basic User's Manual](http://www.ittybittycomputers.com/IttyBitty/TinyBasic/TBuserMan.htm)
- [TinyBasic.c](http://www.ittybittycomputers.com/IttyBitty/TinyBasic/TinyBasic.c)


## Building

To build the `finchbasic` executable, `cd` to the project directory and do this:

    xcodebuild

The `finchbasic` executable will be in the `build/Release` directory.


## Using

`finchbasic` currently only reads from standard input, writes to standard output, and sends error messages to standard error.

To run the interpreter and enter commands, do this:

    ./finchbasic

If you want to "load a program" into `finchbasic` and run it, you can do something like this:

    ./finchbasic < myprogram.basic

If you want to "load a program" and then interact, you can do this:

    cat myprogram.basic - | ./finchbasic

`finchbasic` expects input to be a list of BASIC statements. If a line starts with a line number, then the line is added to the program stored in memory, overwriting any existing line with that same line number. If a line does not start with a line number, then it is executed immediately.

For example:

    10 PRINT "Hello, world"
    20 LET A = 2
    30 LET B = 3
    40 PRINT "a + b = ", A + B
    50 IF A < B THEN PRINT "a is less than b"
    60 END
    LIST
    RUN

You can use lowercase letters for BASIC keywords and variable names.  The interpreter will automatically convert them to uppercase.

Another example:

    10 print "Enter first number"
    20 input a
    30 print "Enter second number"
    40 input b
    50 print a, "+", b, "=", a + b
    60 end
    run


## Syntax

FinchBasic supports this syntax:

    line ::= number statement CR | statement CR

    statement ::= PRINT expr-list | PR expr-list | ? expr-list
                  IF expression relop expression THEN statement
                  GOTO expression
                  INPUT var-list | IN var-list
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

## Code Organization

- `finchbasic/` - source for `finchbasic` executable
   - `main.swift` - main entry point for the command-line tool
- `finchlib/` - source for `finchbasic` executable and `finchlib` framework
   - `Interpreter.swift` - defines the `Interpreter` class
   - `syntax.swift` - defines the parse-tree data structures
   - `char.swift` - ASCII character constants and functions for converting between String and arrays of ASCII/UTF8 characters
   - `util.swift` - miscellaneous
- `finchlibTests/` - unit tests that exercise `finchlib`

## To-Do

- Reject input lines that have invalid trailing characters. (Currently the parser just stops when it is happy with a complete statement, and ignores anything else on the line.)
- Support `;` separators for `PRINT`, allowing consecutive values to be printed with no intervening whitespace.
- Support trailing separator for `PRINT`, suppressing output of the end-of-line character.
- `RND()` function
- Command-line options to load files, send output to a log, suppress prompts, etc.
- `TRON`/`TROFF`
