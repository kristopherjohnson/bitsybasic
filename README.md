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
    40 PRINT "a + b = "; A + B
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
    50 print a; "+"; b; "="; a + b
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
                  TRON
                  TROFF

    expr-list ::= (string|expression) ((,|;) (string|expression) )* (,|;|ε)

    var-list ::= var (, var)*

    expression ::= (+|-|ε) term ((+|-) term)*

    term ::= factor ((*|/) factor)*

    factor ::= var | number | (expression)

    var ::= A | B | C ... | Y | Z

    number ::= digit digit*

    digit ::= 0 | 1 | 2 | 3 | ... | 8 | 9

    relop ::= < (>|=|ε) | > (<|=|ε) | =

The statements and expressions have the traditional Tiny BASIC behaviors, which are described elsewhere.  Here are some peculiarities of the FinchBasic implementation:


`PRINT`

If expressions are separated by commas, then a tab character is output between them. If expressions are separated by semicolons, then there is no separator output between them.

`PRINT` usually outputs a newline character after the expressions.  You can suppress this behavior by ending the statement with a semicolon.  End the statement with a comma to output a tab character rather than a newline.


`INPUT`

The `INPUT` command reads a single line and then tries to assign an expression to each variable in the list.  So, for example, if these statements is executed:

    100 PRINT "Enter three numbers:"
    110 INPUT A, B, C

then the user should respond with something like

    123, 456, 789

If there are too few expressions, or a syntax error, then an error message is printed and the program stops executing.

If there are too many expressions, then the extra expressions are ignored.


`TRON`/`TROFF`

The `TRON` command enables statement tracing. Line numbers are printed as each statement is executed.  `TROFF` disables statement tracing.


## Code Organization

- `finchbasic/` - source for `finchbasic` executable
   - `main.swift` - main entry point for the command-line tool
- `finchlib/` - source for `finchbasic` executable and `finchlib` framework
   - `Interpreter.swift` - defines the `Interpreter` class
   - `syntax.swift` - defines the parse-tree data structures
   - `char.swift` - ASCII character constants and functions for converting between String and arrays of ASCII/UTF8 characters
   - `util.swift` - miscellaneous
- `finchlibTests/` - unit tests that exercise `finchlib`


## Hacking FinchBasic

One of the goals of FinchBasic is that it should be easily "hackable", meaning that it is easy for programmers to modify it to support new statement types, new expression types, and so on.  You are encouraged to experiment with the code.

### Parsing and Evaluation

To add a new statement or new type of expression, there are basically three steps:

1. Add a new definition or modify an existing definition in `syntax.swift` to represent the syntax of the new construct.
2. Add code to parse the new construct.
3. Add code to execute/evaluate the new construct.

Start by studying the enum types in `syntax.swift`. These implement the [parse trees](http://en.wikipedia.org/wiki/Parse_tree) that represent the syntactic structure of each statement.

Study the `parse` methods in `Interpreter.swift` to determine where to add your new parsing code.  For example, if you are adding a new statement type, you will probably add something to `parseStatement()`, whereas if you are adding a new kind of expression or changing the way an expression is parsed, you will probably change something in `parseExpression()`, `parseTerm()`, or `parseFactor()`.

Finally, to handle the execution or evaluation of the new construct, study the `execute` methods in `Interpreter.swift` and the `evaluate` methods in `syntax.swift`.

Some things to remember while writing parsing code:

- The `readInputLine()` method strips out all non-graphic characters, and converts tabs to spaces. So your parsing code won't need to deal with this.
- The parser can only see the current input line. It cannot read the next line while parsing the current line.
- In general, spaces should be ignored/skipped.  So "GO TO 10 11" is equivalent to "GOTO 1011", and "1 0P R I N T" is equivalent to "10 PRINT".  The only place where spaces are significant is in string literals.
- In general, lowercase alphabetic characters should be treated in a case-insensitive manner or automatically converted to uppercase.  The only place where this is not appropriate is in string literals.
- Any incorrect syntax detected must result in a `Statement.Error(String)` element being returned by `parseStatement()`, so that the error will be reported properly.
- `char.swift` contains methods and definitions that may be useful for classifying input characters or for converting text between ASCII/UTF8 bytes and Swift Strings.


### Control Flow

If you are adding a new control structure (like a `FOR...NEXT` or a `REPEAT...UNTIL`), then you will need to understand how the `RUN` statement works.

The `Interpreter` class has an instance member `program` that is an array that holds all the program statements, each of which is a `(Number, Statement)` pair.  The instance member `programIndex` is an Int that is the index of the next element of `program` to be executed. There is also a Boolean instance member `isRunning` that indicates whether the interpreter is in the running state (that is, `RUN` is being executed).

When `RUN` starts, it sets `isRunning` to true, sets `programIndex` to 0, and then starts executing statements sequentially.  It reads a statement from `program[programIndex]`, then increments `programIndex` to point to the next statement, then executes the statement it just read by calling the `execute(Statement)` method.  Then it reads `program[programIndex]`, increments `programIndex`, and executes the statement it just read, and continues in that loop as long as `isRunning` is true.

Some control-flow statements have an effect on this process:

- The `GOTO` statement finds the index in `program` of the statement with a specified line number, then sets `programIndex` to that index.  So when control returns to `RUN`, it will execute the statement referenced by the new value of `programIndex`.
- The `GOSUB` statement pushes the current value of `programIndex` (which will be the index of the following statement) to the `returnStack`, then does the same thing `GOTO` does to look up the target statement and jump to it.
- The `RETURN` statement pops an index off of the `returnStack` and sets the `programIndex` to that value, so `RUN` will resume at the statement following the `GOSUB`.
- The `END` statement sets `isRunning` false, so that `RUN` will exit its loop.

So, if you want to implement your own control-flow statements, you probably just need to figure out how to manipulate `programIndex`, `returnStack`, and `isRunning`.


## To-Do

These fixes/changes/enhancements are planned:

- Reject input lines that have invalid trailing characters. (Currently the parser just stops when it is happy with a complete statement, and ignores anything else on the line.)
- `RND()` function
- Command-line options to load files, send output to a log, suppress prompts, etc.
- iOS app

Contributions are welcome, but the goal is to keep this simple, so if you propose something really ambitious, you may be asked to create your own fork.
