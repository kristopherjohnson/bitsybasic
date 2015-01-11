/*
Copyright (c) 2014, 2015 Kristopher Johnson

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
import UIKit

final class ConsoleViewController: UIViewController, UITextFieldDelegate {

    /// Text field at bottom where user enters statements
    @IBOutlet weak var inputTextField: UITextField!

    /// Console view
    @IBOutlet weak var textView: UITextView!

    /// This constraint will be updated when the keyboard appears, disappears,
    /// or changes size.
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!

    /// NSAttributedString attributes used for output from the interpreter
    var outputAttributes: NSDictionary = [:]

    /// NSAttributedString attributes used for input from the user
    var inputAttributes: NSDictionary = [:]

    /// FinchBasic interpreter
    var interpreter: Interpreter!

    /// Delegate for interpreter
    var interpreterIO: ConsoleInterpreterIO!

    /// Set true if we have queued a call to `stepInterpreter()`
    var interpreterScheduled = false

    /// Text displayed in the console
    ///
    /// Setting this property automatically updates the console display
    /// and scrolls to the bottom.
    var consoleText: NSMutableAttributedString = NSMutableAttributedString(string: "") {
        didSet {
            if textView != nil {
                textView.attributedText = consoleText
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let consoleBackgroundPattern = UIImage(named: "ConsoleBackgroundPattern") {
            let patternColor = UIColor(patternImage: consoleBackgroundPattern)
            textView.backgroundColor = patternColor
        }

        outputAttributes = [
            NSForegroundColorAttributeName: textView.textColor,
            NSFontAttributeName: textView.font,
            NSBackgroundColorAttributeName: UIColor.clearColor()
        ]

        inputAttributes = [
            NSForegroundColorAttributeName: inputTextField.textColor,
            NSFontAttributeName: textView.font,
            NSBackgroundColorAttributeName: UIColor.clearColor()
        ]

        inputTextField.text = ""
        inputTextField.tintColor = UIColor.whiteColor()
//        inputTextField.attributedPlaceholder = NSAttributedString(
//            string: inputTextField.placeholder ?? "",
//            attributes: outputAttributes)
        inputTextField.delegate = self

        consoleText = NSMutableAttributedString(
            string: "BitsyBASIC v1.0\nCopyright 2015 Kristopher Johnson\n\nType HELP if you don't know what to do.\n\nREADY\n",
            attributes: outputAttributes)

        interpreterIO = ConsoleInterpreterIO(viewController: self)
        interpreter = Interpreter(interpreterIO: interpreterIO)
        scheduleInterpreter()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        // Call keyboardWillChangeFrameNotification() when keyboard shows/hides
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "keyboardWillChangeFrameNotification:",
            name: UIKeyboardWillChangeFrameNotification,
            object: nil)

        // Scroll console text view to bottom whenever content size changes
        textView.addObserver(self,
            forKeyPath: "contentSize",
            options: NSKeyValueObservingOptions.New,
            context: nil)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        inputTextField.becomeFirstResponder()
    }

    override func viewDidDisappear(animated: Bool) {
        NSNotificationCenter.defaultCenter().removeObserver(self)

        textView.removeObserver(self, forKeyPath: "contentSize")

        super.viewDidDisappear(animated)
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        // textView's contentSize has changed
        scrollConsoleToBottom()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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

        textView.contentOffset = CGPointMake(0, contentHeight - viewHeight)
    }

    /// Handle appearance or disappearance of keyboard
    ///
    /// Updates bottom constraint so that inputTextField shows above the keyboard.
    func keyboardWillChangeFrameNotification(notification: NSNotification) {
        let change = KeyboardNotification(notification)
        let keyboardFrame = change.frameEndForView(self.view)
        let animationDuration = change.animationDuration
        let animationCurve = change.animationCurve

        let viewFrame = self.view.frame
        let newBottomOffset = viewFrame.maxY - keyboardFrame.minY + 8

        self.view.layoutIfNeeded()
        UIView.animateWithDuration(animationDuration,
            delay: 0,
            options: UIViewAnimationOptions(UInt(animationCurve << 16)),
            animations: {
                self.bottomLayoutConstraint.constant = newBottomOffset
                self.view.layoutIfNeeded()
            },
            completion: nil
        )
    }

    /// Append given text to the console display
    func appendToConsoleText(s: NSString, attributes: NSDictionary) {
        let attributedString = NSMutableAttributedString(string: s, attributes: attributes)
        let newConsoleText = NSMutableAttributedString(attributedString: consoleText)
        newConsoleText.appendAttributedString(attributedString)
        consoleText = newConsoleText
    }

    func appendOutputToConsoleText(s: NSString) {
        appendToConsoleText(s, attributes: outputAttributes)
    }

    func appendInputToConsoleText(s: NSString) {
        appendToConsoleText(s, attributes: inputAttributes)
    }

    /// Handle Return key
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        let text = textField.text
        textField.text = ""
        if !text.isEmpty {
            let line: NSString = text.stringByAppendingString("\n")
            appendInputToConsoleText(line)
            let chars = charsFromString(line)
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

        #if BitsyBASIC_Swift
            let state = interpreter.state
        #else
            let state = interpreter.state()
        #endif

        switch state {
        case .Idle, .Running:
            scheduleInterpreter()

        case .ReadingStatement, .ReadingInput:
            if interpreterIO.inputBuffer.count > 0 {
                scheduleInterpreter()
            }

        default:
            assert(false, "unhandled interpreter state value \(state)")
        }
    }

    /// Queue a call to stepInterpreter()
    func scheduleInterpreter() {
        interpreterScheduled = true
        #if false
            dispatch_async(dispatch_get_main_queue()) {
                self.stepInterpreter()
            }
        #else
            let timer = NSTimer.scheduledTimerWithTimeInterval(0,
                target: self,
                selector: "stepInterpreter",
                userInfo: nil,
                repeats: false)
        #endif
    }

    func showCommandPrompt() {
        appendOutputToConsoleText("> ")
    }

    func showInputPrompt() {
        appendOutputToConsoleText("? ")
    }

    @IBAction func onBreakTapped(sender: UIBarButtonItem) {
        interpreter.breakExecution()
        if !interpreterScheduled {
            scheduleInterpreter()
        }
    }
}

/// Interface between the BASIC interpreter and ConsoleViewController
@objc final class ConsoleInterpreterIO: NSObject, InterpreterIO {
    weak var viewController: ConsoleViewController?

    var inputBuffer: [Char] = Array()
    var inputIndex: Int = 0

    var outputBuffer: [Char] = Array()

    init(viewController: ConsoleViewController) {
        self.viewController = viewController
    }

    /// Return next input character for the interpreter,
    /// or nil if at end-of-file or an error occurs.
    func getInputCharForInterpreter(interpreter: Interpreter) -> InputCharResult {
        if inputIndex < inputBuffer.count {
            #if BitsyBASIC_Swift
                let result: InputCharResult = .Value(inputBuffer[inputIndex])
            #else
                let result: InputCharResult = InputCharResult_Value(inputBuffer[inputIndex])
            #endif

            ++inputIndex
            if inputIndex == inputBuffer.count {
                inputBuffer = Array()
                inputIndex = 0
            }
            return result
        }

        #if BitsyBASIC_Swift
            return .Waiting
        #else
            return InputCharResult_Waiting()
        #endif
    }

    /// Send characters from the console to the interpreter
    func sendInputChars(chars: [Char]) {
        inputBuffer.extend(chars)
    }

    /// Write specified output character
    func putOutputChar(c: Char, forInterpreter interpreter: Interpreter) {
        outputBuffer.append(c)
        if c == 10 || outputBuffer.count >= 40 {
            flushOutput()
        }
    }

    func flushOutput() {
        if outputBuffer.count > 0 {
            if let s = NSString(bytes: &self.outputBuffer,
                length: self.outputBuffer.count,
                encoding: NSUTF8StringEncoding)
            {
                viewController!.appendOutputToConsoleText(s)
            }
            else {
                println("to convert chars to string")
            }
            outputBuffer = Array()
        }
    }

    /// Display a prompt to the user for entering an immediate command or line of code
    func showCommandPromptForInterpreter(interpreter: Interpreter) {
        flushOutput()
        viewController!.showCommandPrompt()
    }

    /// Display a prompt to the user for entering data for an INPUT statement
    func showInputPromptForInterpreter(interpreter: Interpreter) {
        flushOutput()
        viewController!.showInputPrompt()
    }

    /// Display error message to user
    func showErrorMessage(message: String, forInterpreter interpreter: Interpreter) {
        flushOutput()
        let messageWithNewline = "\(message)\n"
        viewController!.appendOutputToConsoleText(messageWithNewline)
    }

    /// Display a debug trace message
    func showDebugTraceMessage(message: String, forInterpreter interpreter: Interpreter) {
        flushOutput()
        viewController!.appendOutputToConsoleText(message)
    }

    /// Called when BYE is executed
    func byeForInterpreter(interpreter: Interpreter) {
        flushOutput()
        viewController!.appendOutputToConsoleText("error: BYE has no effect in iOS\n")
    }
}

#if !BitsyBASIC_Swift
/// Given a string, return array of Chars
public func charsFromString(s: String) -> [UInt8] {
    return Array(s.utf8)
}
#endif
