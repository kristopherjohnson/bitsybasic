/*
Copyright (c) 2014 Kristopher Johnson

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

import Foundation

func runInterpreter() {
    let interpreter = Interpreter()
    interpreter.runUntilEndOfInput()
}

// Put -DUSE_INTERPRETER_THREAD=1 in Build Settings
// to run the interpreter in another thread.
//
// This demonstrates that we get EXC_BAD_ACCESS when
// running the interpreter in another thread.  Do not
// use this for production code.
// 
// See http://www.openradar.me/19353741
#if USE_INTERPRETER_THREAD

    final class InterpreterThread: NSThread {
        let completionSemaphore = dispatch_semaphore_create(0)
        
        override func main() {
            runInterpreter()
            dispatch_semaphore_signal(self.completionSemaphore)
        }
    }

    let thread = InterpreterThread()
    thread.start()

    // Main thread waits for the other thread to finish
    dispatch_semaphore_wait(thread.completionSemaphore, DISPATCH_TIME_FOREVER)

#else

    // Normal case is to run the interpreter in the
    // main thread
    runInterpreter()

#endif
