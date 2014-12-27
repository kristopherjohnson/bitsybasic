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

/// Wrapper for the NSNotification userInfo values associated with a keyboard notification.
///
/// It provides properties retrieve userInfo dictionary values with these keys:
///
/// - UIKeyboardFrameBeginUserInfoKey
/// - UIKeyboardFrameEndUserInfoKey
/// - UIKeyboardAnimationDurationUserInfoKey
/// - UIKeyboardAnimationCurveUserInfoKey

public struct KeyboardNotification {

    let notification: NSNotification
    let userInfo: NSDictionary

    /// Initializer
    ///
    /// :param: notification Keyboard-related notification
    public init(_ notification: NSNotification) {
        self.notification = notification
        if let userInfo = notification.userInfo {
            self.userInfo = userInfo
        }
        else {
            self.userInfo = NSDictionary()
        }
    }

    /// Start frame of the keyboard in screen coordinates
    public var screenFrameBegin: CGRect {
        if let value = userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue {
            return value.CGRectValue()
        }
        else {
            return CGRectZero
        }
    }

    /// End frame of the keyboard in screen coordinates
    public var screenFrameEnd: CGRect {
        if let value = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue {
            return value.CGRectValue()
        }
        else {
            return CGRectZero
        }
    }

    /// Keyboard animation duration
    public var animationDuration: Double {
        if let number = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber {
            return number.doubleValue
        }
        else {
            return 0.25
        }
    }

    /// Keyboard animation curve
    ///
    /// Note that the value returned by this method may not correspond to a
    /// UIViewAnimationCurve enum value.  For example, in iOS 7 and iOS 8,
    /// this returns the value 7.
    public var animationCurve: Int {
        if let number = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber {
            return number.integerValue
        }
        return UIViewAnimationCurve.EaseInOut.rawValue
    }

    /// Start frame of the keyboard in coordinates of specified view
    ///
    /// :param: view UIView to whose coordinate system the frame will be converted
    /// :returns: frame rectangle in view's coordinate system
    public func frameBeginForView(view: UIView) -> CGRect {
        return view.convertRect(screenFrameBegin, fromView: view.window)
    }

    /// End frame of the keyboard in coordinates of specified view
    ///
    /// :param: view UIView to whose coordinate system the frame will be converted
    /// :returns: frame rectangle in view's coordinate system
    public func frameEndForView(view: UIView) -> CGRect {
        return view.convertRect(screenFrameEnd, fromView: view.window)
    }
}
