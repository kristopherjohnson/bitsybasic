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

#import "Interpreter.h"
#import "InterpreterEngine.h"

#include <memory>

using namespace finchlib_cpp;

InputCharResult InputCharResult_Value(Char c)
{
    InputCharResult result = {InputResultKindValue, c};
    return result;
}

InputCharResult InputCharResult_EndOfStream()
{
    InputCharResult result = {InputResultKindEndOfStream, 0};
    return result;
}

InputCharResult InputCharResult_Waiting()
{
    InputCharResult result = {InputResultKindWaiting, 0};
    return result;
}

@interface Interpreter ()
@property id<InterpreterIO> interpreterIO;
@end

@implementation Interpreter
{
    // The real implementation is in the C++ InterpreterEngine class.
    InterpreterEngine *_engine;
}

- (instancetype)initWithInterpreterIO:(id<InterpreterIO>)interpreterIO
{
    self = [super init];
    if (!self)
        return nil;

    // Keep a reference to the InterpreterIO object
    self.interpreterIO = interpreterIO;

    _engine = new InterpreterEngine(self, interpreterIO);

    return self;
}

- (void)dealloc
{
    delete _engine;
}

- (void)runUntilEndOfInput
{
    _engine->runUntilEndOfInput();
}

- (void)next
{
    _engine->next();
}

- (InterpreterState)state
{
    return _engine->state();
}

@end
