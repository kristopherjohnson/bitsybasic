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

final class ViewController: UIViewController {

    @IBOutlet weak var inputTextFieldBottomLayoutConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "keyboardWillChangeFrameNotification:",
            name: UIKeyboardWillChangeFrameNotification,
            object: nil)
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
                self.inputTextFieldBottomLayoutConstraint.constant = newBottomOffset
            },
            completion: nil
        )
    }
}

