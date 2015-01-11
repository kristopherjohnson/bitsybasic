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

#include "pasteboard.h"

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

namespace finchlib_cpp
{

static NSString *getPasteboardContentsAsNSString()
{
#if TARGET_OS_IPHONE
    const auto pasteboard = [UIPasteboard generalPasteboard];
    return [pasteboard string];
#else
    const auto pasteboard = [NSPasteboard generalPasteboard];
    return [pasteboard stringForType:NSPasteboardTypeString];
#endif
}

static void setPasteboardContents(NSString *s)
{
#if TARGET_OS_IPHONE
    const auto pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = s;
#else
    const auto pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:s forType:NSPasteboardTypeString];
#endif
}

/// Return contents of the system clipboard as a string,
/// or empty string if no text on clipboard.
std::string getPasteboardContents()
{
    NSString *nsString = getPasteboardContentsAsNSString();

    if (!nsString)
    {
        return {};
    }

    return {[nsString UTF8String]};
}

/// Copy the specified text to the system clipboard,
/// replacing any existing contents of the clipboard.
void copyToPasteboard(std::string text)
{
    NSString *nsString = [NSString stringWithCString:text.c_str()
                                            encoding:NSUTF8StringEncoding];
    setPasteboardContents(nsString);
}

}  // namespace finchlib_cpp
