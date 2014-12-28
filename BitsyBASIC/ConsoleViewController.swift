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

import UIKit

final class ConsoleViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {

    @IBOutlet weak var inputTextField: UITextField!

    @IBOutlet weak var textView: UITextView!

    // This constraint will be updated when the keyboard appears, disappears,
    // or changes size.
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!

    var interpreterThread: InterpreterThread!
    var interpreterIO: ConsoleInterpreterIO!

    var consoleText: NSString = "" {
        didSet {
            if textView != nil {
                textView.text = consoleText
                let range = NSRange(location: consoleText.length - 1, length: 0)
                textView.scrollRangeToVisible(range)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        inputTextField.text = ""
        inputTextField.delegate = self

        textView.delegate = self

        consoleText = "BitsyBASIC v1.0\n© 2014 Kristopher Johnson\n"

        interpreterIO = ConsoleInterpreterIO(viewController: self)
        interpreterThread = InterpreterThread(interpreterIO: interpreterIO)
        interpreterThread.name = "Interpreter"
        interpreterThread.start()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "keyboardWillChangeFrameNotification:",
            name: UIKeyboardWillChangeFrameNotification,
            object: nil)

        inputTextField.becomeFirstResponder()
    }

    override func viewDidDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        super.viewDidDisappear(animated)
    }

    func keyboardWillChangeFrameNotification(notification: NSNotification) {
        let n = KeyboardNotification(notification)
        let keyboardFrame = n.frameEndForView(self.view)
        let animationDuration = n.animationDuration
        let animationCurve = n.animationCurve

        let viewFrame = self.view.frame
        let newBottomOffset = viewFrame.maxY - keyboardFrame.minY + 8

        UIView.animateWithDuration(animationDuration,
            delay: 0,
            options: UIViewAnimationOptions(rawValue: UInt(animationCurve << 16)),
            animations: { () -> Void in
                self.bottomLayoutConstraint.constant = newBottomOffset
            },
            completion: nil
        )
    }

    func appendToConsoleText(s: NSString) {
        let newConsoleText = consoleText.stringByAppendingString(s)
        consoleText = newConsoleText
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        let text = textField.text
        textField.text = ""
        if !text.isEmpty {
            let line = text.stringByAppendingString("\n")
            appendToConsoleText(line)
            var chars = charsFromString(line)
            interpreterIO.sendInputChars(chars)
        }

        return false
    }

    func showCommandPrompt() {
        appendToConsoleText(":")
    }

    func showInputPrompt() {
        appendToConsoleText("? ")
    }
}

/// Thread in which the interpreter runs
final class InterpreterThread: NSThread {
    let interpreter: Interpreter

    init(interpreterIO: InterpreterIO) {
        interpreter = Interpreter(interpreterIO: interpreterIO)
        super.init()
    }

    override func main() {
        interpreter.interpretInputLines()
    }
}

/// Interface between the BASIC interpreter and ConsoleViewController
///
/// The interpreter runs in its own thread.  This class takes care
/// of passing data between that thread and the UI thread safely.
final class ConsoleInterpreterIO: InterpreterIO {
    let viewController: ConsoleViewController

    let syncQueue: dispatch_queue_t

    let inputAvailable: dispatch_semaphore_t
    var inputBuffer: [Char] = Array()
    var inputIndex: Int = 0
    var nextInputBuffer: [Char] = Array()

    var outputBuffer: [Char] = Array()

    init(viewController: ConsoleViewController) {
        self.viewController = viewController

        inputAvailable = dispatch_semaphore_create(0)

        syncQueue = dispatch_queue_create(
            "ConsoleInterpreterIO".UTF8String,
            DISPATCH_QUEUE_SERIAL)
    }

    /// Return next input character for the interpreter,
    /// or nil if at end-of-file or an error occurs.
    func getInputChar(interpreter: Interpreter) -> Char? {
        // If processing inputBuffer, return the next character
        if inputIndex < inputBuffer.count {
            return inputBuffer[inputIndex++]
        }

        // Otherwise wait for main thread to put something into nextInputBuffer
        dispatch_semaphore_wait(inputAvailable, DISPATCH_TIME_FOREVER)
        dispatch_sync(syncQueue) {
            self.inputBuffer = self.nextInputBuffer
            self.inputIndex = 0
            self.nextInputBuffer = Array()
        }

        if inputIndex < inputBuffer.count {
            return inputBuffer[inputIndex++]
        }
        else {
            return nil
        }
    }

    /// Send characters from the console to the interpreter
    func sendInputChars(chars: [Char]) {
        if chars.count == 0 {
            return
        }

        dispatch_sync(syncQueue) {
            let wasEmpty = self.nextInputBuffer.count == 0
            self.nextInputBuffer.extend(chars)
            if wasEmpty {
                dispatch_semaphore_signal(self.inputAvailable)
            }
        }
    }

    /// Write specified output character
    func putOutputChar(interpreter: Interpreter, _ c: Char) {
        outputBuffer.append(c)
        if c == Ch_Linefeed {
            flushOutput()
        }
    }

    func flushOutput() {
        if outputBuffer.count > 0 {
            dispatch_sync(dispatch_get_main_queue()) {
                if let s = NSString(bytes: &self.outputBuffer, length: 1, encoding: NSUTF8StringEncoding) {
                    self.viewController.appendToConsoleText(s)
                }
                else {
                    assert(false, "should be able to convert chars to string")
                }
                self.outputBuffer = Array()
            }
        }
    }

    /// Display a prompt to the user for entering an immediate command or line of code
    func showCommandPrompt(interpreter: Interpreter) {
        flushOutput()
        dispatch_sync(dispatch_get_main_queue()) {
            self.viewController.showCommandPrompt()
        }
    }

    /// Display a prompt to the user for entering data for an INPUT statement
    func showInputPrompt(interpreter: Interpreter) {
        flushOutput()
        dispatch_sync(dispatch_get_main_queue()) {
            self.viewController.showInputPrompt()
        }
    }

    /// Display error message to user
    func showError(interpreter: Interpreter, message: String) {
        flushOutput()
        dispatch_sync(dispatch_get_main_queue()) {
            self.viewController.appendToConsoleText(message)
        }
    }

    /// Display a debug trace message
    func showDebugTrace(interpreter: Interpreter, message: String) {
        flushOutput()
        dispatch_sync(dispatch_get_main_queue()) {
            self.viewController.appendToConsoleText(message)
        }
    }

    /// Called when BYE is executed
    func bye(interpreter: Interpreter) {
        flushOutput()
        dispatch_sync(dispatch_get_main_queue()) {
            self.viewController.appendToConsoleText("error: BYE not available in iOS")
        }
    }
}
