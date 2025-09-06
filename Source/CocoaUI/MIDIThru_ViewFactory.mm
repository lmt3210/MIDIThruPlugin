// 
// MIDIThru_ViewFactory.mm
//
// Copyright (c) 2020-2025 Larry M. Taylor
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software. Permission is granted to anyone to
// use this software for any purpose, including commercial applications, and to
// to alter it and redistribute it freely, subject to 
// the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source
//    distribution.
//

#import "MIDIThru_ViewFactory.h"
#import "MIDIThru_UIView.h"

@implementation MIDIThru_ViewFactory

// Version 0
- (unsigned)interfaceVersion
{
    return 0;
}

// String description of the Cocoa UI
- (NSString *)description
{
    NSLog(@"Cocoa UI description: Larry Taylor: MIDIThru");
    return @"Larry Taylor: MIDIThru";
}

// N.B.: this class is simply a view-factory,
// returning a new autoreleased view each time it's called.
- (NSView *)uiViewForAudioUnit:(AudioUnit)inAU withSize:(NSSize)inPreferredSize
{
    if (![[NSBundle bundleForClass:[MIDIThru_UIView class]]
          loadNibNamed:@"CocoaView" owner:self topLevelObjects:NULL])
    {
        NSLog(@"Unable to load nib for view.");
        return nil;
    }

    // This particular nib has a fixed size, so we don't do 
    // anything with the inPreferredSize argument.
    // It's up to the host application to handle.
    [uiFreshlyLoadedView setAU:inAU withView:(NSView *)uiFreshlyLoadedView];
    NSView *returnView = (NSView *)uiFreshlyLoadedView;

    // Zero out pointer. This is a view factory.
    // Once a view's been created and handed off, the 
    // factory keeps no record of it.
    uiFreshlyLoadedView = nil;

    return returnView;
}

@end
