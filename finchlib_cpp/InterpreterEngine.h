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

#ifndef __finchbasic__InterpreterEngine__
#define __finchbasic__InterpreterEngine__

#import "Interpreter.h"
#import "syntax.h"


namespace finchlib_cpp
{

typedef std::vector<Char> InputLine;

/// Values for `kind` field of `InterpreterEngine::Line`
typedef NS_ENUM(NSInteger, LineKind)
{
    LineKindNumberedStatement,
    LineKindUnnumberedStatement,
    LineKindEmpty,
    LineKindEmptyNumberedLine,
    LineKindError
};

/// Result of attempting to read a line of input
struct InputLineResult
{
    InputResultKind kind;
    InputLine value; // only used when kind == InputResultKindValue

    static InputLineResult inputLine(const InputLine &input)
    {
        return {InputResultKindValue, input};
    }

    static InputLineResult endOfStream()
    {
        return {InputResultKindEndOfStream};
    }

    static InputLineResult waiting()
    {
        return {InputResultKindWaiting};
    }
};


#pragma mark - InterpreterEngine

class InterpreterEngine
{
public:
    /// Constructor
    InterpreterEngine(Interpreter *interpreter, id<InterpreterIO> interpreterIO);

    /// Display prompt and read input lines and interpret them until end of input.
    ///
    /// This method should only be used when `InterpreterIO.getInputChar()`
    /// will never return `InputCharResult.Waiting`.
    /// Otherwise, host should call `next()` in a loop.
    void runUntilEndOfInput();

    /// Perform next operation.
    ///
    /// The host can drive the interpreter by calling `next()`
    /// in a loop.
    void next();

    /// Return interpreter state
    InterpreterState state();

    /// Execute a PRINT statement with arguments
    void PRINT(const PrintList &printList);

    /// Execute a PRINT statement that takes no arguments
    void PRINT();

    /// Execute an INPUT statement
    void INPUT(const Lvalues &lvalues);

    /// Execute a LIST statement
    void LIST(const Expression &lowExpr, const Expression &highExpr);

    /// Execute an IF statement
    void IF(const Expression &lhs, const RelOp &op, const Expression &rhs, const Statement &consequent);

    /// Execute a RUN statement
    void RUN();

    /// Execute END statement
    void END();

    /// Execute GOTO statement
    void GOTO(const Expression &lineNumber);

    /// Execute GOSUB statement
    void GOSUB(const Expression &lineNumber);

    /// Execute RETURN statement
    void RETURN();

    /// Execute CLEAR statement
    void CLEAR();

    /// Execute BYE statement
    void BYE();

    /// Execute HELP statement
    void HELP();

    /// Execute a DIM statement
    void DIM(const Expression &expr);

    /// Execute a SAVE statement
    void SAVE(std::string filename);

    /// Execute a LOAD statement
    void LOAD(std::string filename);

    /// Execute a FILES statement
    void FILES();

    /// Execute a TRON statement
    void TRON();

    /// Execute a TROFF statement
    void TROFF();

    /// Evaluate an expression
    Number evaluate(const Expression &expr);

    Number getVariableValue(VariableName variableName) const;
    void setVariableValue(VariableName variableName, Number value);

    Number getArrayElementValue(Number index);
    void setArrayElementValue(Number index, Number value);
    void setArrayElementValue(const Expression &indexExpression, Number value);

private:
#pragma mark - Private data members

    /// Interpreter instance that owns this engine
    Interpreter *interpreter;

    /// Low-level I/O interface
    id<InterpreterIO> io;

    /// Interpreter state
    InterpreterState st{InterpreterStateIdle};

    /// Variable values
    VariableBindings v;

    /// Array of numbers, addressable using the syntax "@(i)"
    Numbers a;

    /// Characters that have been read from input but not yet been returned by readInputLine()
    InputLine inputLineBuffer;

    /// Array of program lines
    Program program;

    /// Index of currently executing line in program
    size_t programIndex{0};

    /// Return stack used by GOSUB/RETURN
    ReturnStack returnStack;

    /// If true, print line numbers while program runs
    bool isTraceOn{false};

    /// If true, have encountered EOF while processing input
    bool hasReachedEndOfInput{false};

    /// Lvalues being read by current INPUT statement
    Lvalues inputLvalues;

    /// State that interpreter was in when INPUT was called
    InterpreterState stateBeforeInput{InterpreterStateIdle};

#pragma mark - Private methods

    /// Set values of all variables and array elements to zero
    void clearVariablesAndArray();

    /// Remove program from memory
    void clearProgram();

    /// Remove all items from the return stack
    void clearReturnStack();

    /// Parse an input line and execute it or add it to the program
    void processInput(const InputLine &input);

    struct Line parseInputLine(const InputLine &input);

    void insertLineIntoProgram(Number lineNumber, Statement statement);

    /// Delete the line with the specified number from the program.
    ///
    /// No effect if there is no such line.
    void deleteLineFromProgram(Number lineNumber);

    Program::iterator programLineWithNumber(Number lineNumber);

    /// Return line number of the last line in the program.
    ///
    /// Returns 0 if there is no program.
    Number getLastProgramLineNumber();

    void execute(Statement s);

    void executeNextProgramStatement();

    /// Display error message and stop running
    ///
    /// Call this method if an unrecoverable error happens while executing a statement
    void abortRunWithErrorMessage(std::string message);

    /// Send a single character to the output stream
    void writeOutput(Char c);

    /// Send characters to the output stream
    void writeOutput(const std::vector<Char> &chars);

    /// Send string to the output stream
    void writeOutput(std::string s);

    /// Print an object that conforms to the PrintTextProvider protocol
    void writeOutput(const PrintTextProvider &p);

    /// Display error message
    void showError(std::string message);

    /// Read a line using the InterpreterIO interface.
    ///
    /// Return array of characters, or nil if at end of input stream.
    ///
    /// Result does not include any non-graphic characters that were in the input stream.
    /// Any horizontal tab ('\t') in the input will be converted to a single space.
    ///
    /// Result may be an empty array, indicating an empty input line, not end of input.
    InputLineResult readInputLine();

    /// Get a line of input, using specified function to retrieve characters.
    ///
    /// Result does not include any non-graphic characters that were in the input stream.
    /// Any horizontal tab ('\t') in the input will be converted to a single space.
    InputLineResult getInputLine(std::function<InputCharResult()> getChar);

    /// Perform an INPUT operation
    ///
    /// This may be called by INPUT(), or by next() if resuming an operation
    /// following a .Waiting result from readInputLine()
    void continueInput();

    /// Display error message to user during an INPUT operation
    void showInputHelpMessage();
};

} // namespace finchlib_cpp

#endif /* defined(__finchbasic__InterpreterEngine__) */
