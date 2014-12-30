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

    var interpreterIO: ConsoleInterpreterIO!
    var interpreter: Interpreter!
    var interpreterScheduled = false


    /// Text displayed in the console
    ///
    /// Setting this property automatically updates the console display
    /// and scrolls to the bottom.
    var consoleText: NSString = "" {
        didSet {
            if textView != nil {
                textView.text = consoleText
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        inputTextField.text = ""
        inputTextField.delegate = self

        textView.delegate = self

        consoleText = "BitsyBASIC v1.0\n© 2014 Kristopher Johnson\n\nREADY\n"

        interpreterIO = ConsoleInterpreterIO(viewController: self)
        interpreter = Interpreter(interpreterIO: interpreterIO)
        scheduleInterpreter()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "keyboardWillChangeFrameNotification:",
            name: UIKeyboardWillChangeFrameNotification,
            object: nil)

        textView.addObserver(self,
            forKeyPath: "contentSize",
            options: NSKeyValueObservingOptions.New,
            context: nil)

        inputTextField.becomeFirstResponder()
    }

    override func viewDidDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().removeObserver(self)

        textView.removeObserver(self, forKeyPath: "contentSize")

        super.viewDidDisappear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollConsoleToBottom()
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        // textView's contentSize has changed
        scrollConsoleToBottom()
    }

    /// Update the text view so that the end of the text is at the bottom of the screen.
    ///
    /// Call this whenever views are laid out or when content size changes.
    ///
    /// If the content height is smaller than the view height, then contentOffset
    /// will be set to move the text to the bottom.  Otherwise, will call
    /// textView.scrollRangeToVisible with the end of the text as the range.
    func scrollConsoleToBottom() {
        let viewHeight = textView.bounds.height
        let contentHeight = textView.contentSize.height

        if contentHeight > viewHeight {
            textView.contentOffset = CGPointZero
            let text: NSString = textView.text
            textView.scrollRangeToVisible(NSRange(location: text.length, length: 0))
        }
        else {
            textView.contentOffset = CGPointMake(0, contentHeight - viewHeight)
        }
    }

    func keyboardWillChangeFrameNotification(notification: NSNotification) {
        let change = KeyboardNotification(notification)
        let keyboardFrame = change.frameEndForView(self.view)
        let animationDuration = change.animationDuration
        let animationCurve = change.animationCurve

        let viewFrame = self.view.frame
        let newBottomOffset = viewFrame.maxY - keyboardFrame.minY + 8

        UIView.animateWithDuration(animationDuration,
            delay: 0,
            options: UIViewAnimationOptions(UInt(animationCurve << 16)),
            animations: {
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
            if !interpreterScheduled {
                scheduleInterpreter()
            }
        }

        return false
    }


    // MARK: - Interpreter

    /// Drive the interpreter
    ///
    /// Calls interpreter.next() to get it to do its next action.
    /// Then schedules another step, unless the interpreter is
    /// waiting for input and we don't have any to give it.
    func stepInterpreter() {
        interpreterScheduled = false
        interpreter.next()

        switch interpreter.state {
        case .Idle, .Running:
            scheduleInterpreter()
        case .ReadingStatement, .ReadingInput:
            if interpreterIO.inputBuffer.count > 0 {
                scheduleInterpreter()
            }
        }
    }

    func scheduleInterpreter() {
        interpreterScheduled = true
        dispatch_async(dispatch_get_main_queue()) {
            self.stepInterpreter()
        }
    }

    func showCommandPrompt() {
        appendToConsoleText("> ")
    }

    func showInputPrompt() {
        appendToConsoleText("? ")
    }
}

/// Interface between the BASIC interpreter and ConsoleViewController
final class ConsoleInterpreterIO: InterpreterIO {
    weak var viewController: ConsoleViewController?

    var inputBuffer: [Char] = Array()
    var inputIndex: Int = 0

    var outputBuffer: [Char] = Array()

    init(viewController: ConsoleViewController) {
        self.viewController = viewController
    }

    /// Return next input character for the interpreter,
    /// or nil if at end-of-file or an error occurs.
    func getInputChar(interpreter: Interpreter) -> InputCharResult {
        if inputIndex < inputBuffer.count {
            let result: InputCharResult = .Value(inputBuffer[inputIndex])
            ++inputIndex
            if inputIndex == inputBuffer.count {
                inputBuffer = Array()
                inputIndex = 0
            }
            return result
        }

        return .Waiting
    }

    /// Send characters from the console to the interpreter
    func sendInputChars(chars: [Char]) {
        inputBuffer.extend(chars)
    }

    /// Write specified output character
    func putOutputChar(interpreter: Interpreter, _ c: Char) {
        outputBuffer.append(c)
        if c == Ch_Linefeed || outputBuffer.count >= 40 {
            flushOutput()
        }
    }

    func flushOutput() {
        if outputBuffer.count > 0 {
            if let s = NSString(bytes: &self.outputBuffer,
                length: self.outputBuffer.count,
                encoding: NSUTF8StringEncoding)
            {
                viewController!.appendToConsoleText(s)
            }
            else {
                assert(false, "should be able to convert chars to string")
            }
            outputBuffer = Array()
        }
    }

    /// Display a prompt to the user for entering an immediate command or line of code
    func showCommandPrompt(interpreter: Interpreter) {
        flushOutput()
        viewController!.showCommandPrompt()
    }

    /// Display a prompt to the user for entering data for an INPUT statement
    func showInputPrompt(interpreter: Interpreter) {
        flushOutput()
        viewController!.showInputPrompt()
    }

    /// Display error message to user
    func showError(interpreter: Interpreter, message: String) {
        flushOutput()
        let messageWithNewline = "\(message)\n"
        viewController!.appendToConsoleText(messageWithNewline)
    }

    /// Display a debug trace message
    func showDebugTrace(interpreter: Interpreter, message: String) {
        flushOutput()
        viewController!.appendToConsoleText(message)
    }

    /// Called when BYE is executed
    func bye(interpreter: Interpreter) {
        flushOutput()
        viewController!.appendToConsoleText("error: BYE not available in iOS")
    }
}
