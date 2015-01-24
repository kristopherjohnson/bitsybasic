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

using namespace finchlib_cpp;


static NSString *InterpreterPropertyListKey = @"InterpreterPropertyList";


InputCharResult InputCharResult_Value(Char c)
{
    return {InputResultKindValue, c};
}

InputCharResult InputCharResult_EndOfStream()
{
    return {InputResultKindEndOfStream, 0};
}

InputCharResult InputCharResult_Waiting()
{
    return {InputResultKindWaiting, 0};
}


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

    self.io = interpreterIO;

    _engine = new InterpreterEngine(self);

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;

    _engine = new InterpreterEngine(self);

    NSDictionary *propertyList = [coder decodeObjectForKey:InterpreterPropertyListKey];
    if (propertyList)
    {
        _engine->restoreStateFromPropertyList(propertyList);
    }
    else
    {
        NSAssert(false, @"unable to decode property list");
    }

    return self;
}

- (void)dealloc
{
    delete _engine;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSDictionary *propertyList = _engine->stateAsPropertyList();
    [coder encodeObject:propertyList forKey:InterpreterPropertyListKey];
}

- (NSDictionary *)stateAsPropertyList
{
    return _engine->stateAsPropertyList();
}

- (void)restoreStateFromPropertyList:(NSDictionary *)propertyList
{
    _engine->restoreStateFromPropertyList(propertyList);
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

- (void)breakExecution
{
    _engine->breakExecution();
}

@end
