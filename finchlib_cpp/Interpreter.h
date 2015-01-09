/*
Copyright (c) 2015 Kristopher Johnson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <Foundation/Foundation.h>

// Note: This file is included by Objective-C and Swift code,
// so it must not contain any C++ declarations.

@class Interpreter;

typedef unsigned char Char;
typedef int Number;

typedef NS_ENUM(NSInteger, InputResultKind)
{
    InputResultKindValue,
    InputResultKindEndOfStream,
    InputResultKindWaiting
};

typedef struct
{
    InputResultKind kind;
    Char value; // only used when kind == InputResultKindValue
} InputCharResult;

// Functions for creating an InputCharResult with the appropriate kind
__BEGIN_DECLS
InputCharResult InputCharResult_Value(Char c);
InputCharResult InputCharResult_EndOfStream();
InputCharResult InputCharResult_Waiting();
__END_DECLS

/// Protocol implemented by object that provides I/O operations for an Interpreter
@protocol InterpreterIO <NSObject>

/// Return next input character, or nil if at end-of-file or an error occurs
- (InputCharResult)getInputCharForInterpreter:(Interpreter *)interpreter;

/// Write specified output character
- (void)putOutputChar:(Char)c forInterpreter:(Interpreter *)interpreter;

/// Display a prompt to the user for entering an immediate command or line of code
- (void)showCommandPromptForInterpreter:(Interpreter *)interpreter;

/// Display a prompt to the user for entering data for an INPUT statement
- (void)showInputPromptForInterpreter:(Interpreter *)interpreter;

/// Display error message to user
- (void)showErrorMessage:(NSString *)message forInterpreter:(Interpreter *)interpreter;

/// Display a debug trace message
- (void)showDebugTraceMessage:(NSString *)message forInterpreter:(Interpreter *)interpreter;

/// Called when BYE is executed
- (void)byeForInterpreter:(Interpreter *)interpreter;

@end


/// State of the interpreter
///
/// The interpreter begins in the `.Idle` state, which
/// causes it to immediately display a statement prompt
/// and then enter the `.ReadingStatement` state, where it
/// will process numbered and unnumbered statements.
///
/// A `RUN` statement will put it into `.Running` state, and it
/// will execute the stored program.  If an `INPUT` statement
/// is executed, the interpreter will go into .ReadingInput
/// state until valid input is received, and it will return
/// to `.Running` state.
///
/// The state returns to `.ReadingStatement` on an `END`
/// statement or if `RUN` has to abort due to an error.
typedef NS_ENUM(NSInteger, InterpreterState)
{
    /// Interpreter is not "doing anything".
    ///
    /// When in this state, interpreter will display
    /// statement prompt and then enter the
    /// `ReadingStatement` state.
    InterpreterStateIdle,

    /// Interpreter is trying to read a statement/command
    InterpreterStateReadingStatement,

    /// Interpreter is running a program
    InterpreterStateRunning,

    /// Interpreter is processing an `INPUT` statement
    InterpreterStateReadingInput
};


@interface Interpreter : NSObject

- (instancetype)initWithInterpreterIO:(id<InterpreterIO>)interpreterIO;

- (void)runUntilEndOfInput;

- (void)next;

- (InterpreterState)state;

@end
