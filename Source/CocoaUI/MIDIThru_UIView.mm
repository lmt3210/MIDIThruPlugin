// 
// MIDIThru_UIView.mm
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

#import <CoreMIDI/CoreMIDI.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "MIDIThru_UIView.h"
#import "MIDIThru_ViewFactory.h"


// This callback happens on a separate, high-priority thread
OSStatus midiMonProc(void *userData, const AudioTimeStamp *timeStamp,
                     UInt32 midiOutNum, const struct MIDIPacketList *inPktList)
{
    struct LTMIDIControl *mc = (struct LTMIDIControl *)userData;
    MIDIPacket *inPacket = (MIDIPacket *)inPktList->packet;
    
    for (int i = 0; i < inPktList->numPackets; i++)
    {
        UInt16 inPacketLength = inPacket->length;

        for (int j = 0; j < inPacketLength;)
        {
            Byte status = inPacket->data[0];
            Byte message = status & 0xF0;
            Byte data1 = 0;
            Byte data2 = 0;
            UInt16 eventLength = inPacketLength;
            BOOL saveEvent = false;
            
            switch (message)
            {
                case MIDI_NOTE_OFF:
                    eventLength = 3;
                    saveEvent = true;
                    break;
                case MIDI_NOTE_ON:
                    data1 = inPacket->data[j + 1];
                    data2 = inPacket->data[j + 2];
                    eventLength = 3;
                    saveEvent = true;
                    break;
                case MIDI_AFTER_TOUCH:
                case MIDI_PITCH_WHEEL:
                    eventLength = 3;
                    break;
                case MIDI_CONTROL_CHANGE:
                    eventLength = 3;
                    break;
                case MIDI_SET_PROGRAM:
                    eventLength = 2;
                    break;
                case MIDI_SET_PRESSURE:
                    eventLength = 2;
                    break;
                case MIDI_SYSTEM_MSG:

                    switch (status)
                    {
                        case MIDI_SYSEX:
                            eventLength = inPacketLength;
                            break;
                        case MIDI_TCQF:
                        case MIDI_SONG_SELECT:
                            eventLength = 2;
                            break;
                        case MIDI_SONG_POS:
                            eventLength = 3;
                            break;
                        case MIDI_CLOCK:
                        case MIDI_ACTIVE_SENSE:
                        case MIDI_EOX:
                        case MIDI_TUNE_REQ:
                        case MIDI_SEQ_START:
                        case MIDI_SEQ_CONTINUE:
                        case MIDI_SEQ_STOP:
                        case MIDI_SYS_RESET:
                            eventLength = 1;
                            break;
                    }

                    break;
            }

            if ((saveEvent == true) && (mc->recordEnable == 1))
            {
                mc->recordData[mc->writeIndex].timeStamp =
                    inPacket->timeStamp;
                mc->recordData[mc->writeIndex].length = eventLength;
                mc->recordData[mc->writeIndex].data[0] = status;
                mc->recordData[mc->writeIndex].data[1] = data1;
                mc->recordData[mc->writeIndex].data[2] = data2;
                mc->writeIndex++;
                
                if (mc->writeIndex == kMaximumEvents)
                {
                    mc->writeIndex = 0;
                }
            }
            
            j += eventLength;
        }

        inPacket = MIDIPacketNext(inPacket);
    }

    return noErr;
}

@implementation MIDIThru_UIView

-(void)awakeFromNib
{
    // Setup background
    mBackground = [NSColor colorWithSRGBRed:(61.0 / 255.0) green:(39.0 / 255.0)
                   blue:(93.0 / 255.0) alpha:1.0];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [mBackground set];
    NSRectFill(dirtyRect);
    [mIndicatorColor setFill];
    [mActivityIndicator fill];

    // Draw all other controls after filling the background
    [super drawRect:dirtyRect];
}

- (void)dealloc
{
    mMIDIControl.recordEnable = 0;
    
    // Stop timer
    if (mMonitorTimer)
    {
        [mMonitorTimer invalidate];
        mMonitorTimer = nil;
    }
}

// Public functions
- (void)setAU:(AudioUnit)inAU withView:(NSView *)view
{
    mLog = os_log_create("com.larrymtaylor.au.MIDIThru", "View");
    
    mAU = inAU;
    mView = view;
    mWindowSet = false;
    
    // Monitor timer
    mMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                     target:self selector:@selector(monitorTimer:)
                     userInfo:nil repeats:YES];

    // Set up for saving MIDI events
    mMIDIControl.recordEnable = 1;
    mMIDIControl.readIndex = 0;
    mMIDIControl.writeIndex = 0;
    
    // Set up for receiving MIDI
    AUMIDIOutputCallbackStruct midiOutputCallbackStruct;
    memset(&midiOutputCallbackStruct, 0, sizeof(midiOutputCallbackStruct));
    midiOutputCallbackStruct.midiOutputCallback = midiMonProc;
    midiOutputCallbackStruct.userData = &mMIDIControl;
    
    OSStatus err = AudioUnitSetProperty(mAU, kAudioUnitCustomPropertyUICB,
                                        kAudioUnitScope_Global, 0,
                                        &midiOutputCallbackStruct,
                                        sizeof(midiOutputCallbackStruct));
    
    if (err != noErr)
    {
        LTLog(mLog, LTLOG_NO_FILE, OS_LOG_TYPE_ERROR,
              @"Error setting the UICB Callback, error = %i (%@)",
              err, statusToString(err));
    }
}

- (void)setupWindow
{
    // Create indicator
    NSRect mainFrame = [mView frame];
    NSRect bounds = NSMakeRect((mainFrame.size.width / 2) - 25,
                               (mainFrame.size.height / 2) - 25, 50, 50);
    mActivityIndicator = [NSBezierPath bezierPath];
    [mActivityIndicator appendBezierPathWithOvalInRect:bounds];
    mIndicatorColor = [NSColor clearColor];
    mActivity = false;
    mLightOn = false;
    mLightOnCount = 0;
    mLightOffCount = 5;
    
    // Setup main window
    [[mView window] setStyleMask:(NSWindowStyleMaskTitled)];
    [[mView window] setMinSize:NSMakeSize(305, 210)];  // w, h
    [[mView window] setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [[mView window] setReleasedWhenClosed:NO];
    NSButton *menuButton = [NSButton buttonWithTitle:@"" target:self
                            action:@selector(menuButton:)];
    [menuButton setButtonType:NSButtonTypeMomentaryPushIn];
    [menuButton setFrame:CGRectMake(0, 0, 50, 50)];
    NSString *path = [[NSBundle bundleForClass: [MIDIThru_UIView class]]
                      pathForImageResource:@"ThreeLines"];
    NSImage *pattern = [[NSImage alloc] initByReferencingFile:path];
    [pattern setSize:NSMakeSize(35, 35)];
    [menuButton setImage:pattern];
    [menuButton setBordered:false];
    
    // Create the menu
    mContextMenu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *item1 = [[NSMenuItem alloc] initWithTitle:@"Help"
                         action:@selector(helpButton:) keyEquivalent:@""];
    NSMenuItem *item2 = [[NSMenuItem alloc] initWithTitle:@"About"
                         action:@selector(aboutButton:) keyEquivalent:@""];

    // Add items to the menu
    [mContextMenu addItem:item1];
    [mContextMenu addItem:[NSMenuItem separatorItem]];
    [mContextMenu addItem:item2];

    NSArray *array = [NSArray arrayWithObjects:menuButton, nil];
    [mView setSubviews:array];
}

- (void)menuButton:(id)sender
{
    // Get the current event (mouse down event)
    NSEvent *event = [NSApp currentEvent];
    
    // Show the menu at the location of the button
    [NSMenu popUpContextMenu:mContextMenu withEvent:event forView:sender];
}

- (void)helpButton:(id)sender
{
    if (mHelpWindow == nil)
    {
        [self createHelpWindow];
    }

    [mHelpWindow center];
    [mHelpWindow makeKeyAndOrderFront:self];
}

- (void)createHelpWindow
{
    NSBundle *bundle =
        [NSBundle bundleForClass:[MIDIThru_UIView class]];
    NSURL *helpPath = [bundle URLForResource:@"Help"
                          withExtension:@"html"];
    NSString *text = [NSString stringWithContentsOfURL:helpPath
                      encoding:NSASCIIStringEncoding error:nil];
    NSAttributedString *helpText = [[NSAttributedString alloc]
        initWithData:[text dataUsingEncoding:NSUnicodeStringEncoding]
        options:@{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType}
        documentAttributes:nil error:nil];
    
    NSRect windowFrame = NSMakeRect(200, 200, 400, 400);  // x, y, w, h
    mHelpWindow = [[NSWindow alloc] initWithContentRect:windowFrame
                styleMask:(NSWindowStyleMaskTitled |
                           NSWindowStyleMaskResizable |
                           NSWindowStyleMaskClosable)
                backing:NSBackingStoreBuffered defer:NO];
    
    [mHelpWindow setMinSize:NSMakeSize(400, 200)];  // w, h
    [mHelpWindow setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [mHelpWindow setReleasedWhenClosed:NO];
    
    NSRect textFrame = NSMakeRect(200, 200, 380, 600);
    NSTextView *mTextView = [[NSTextView alloc] initWithFrame:textFrame];
    
    NSScrollView *mScrollView = [[NSScrollView alloc]
                   initWithFrame:[[mHelpWindow contentView] frame]];
    NSSize contentSize = [mScrollView contentSize];
     
    [mScrollView setBorderType:NSNoBorder];
    [mScrollView setHasVerticalScroller:YES];
    [mScrollView setHasHorizontalScroller:NO];
    [mScrollView setAutoresizingMask:NSViewHeightSizable];
    
    [mTextView setMinSize:NSMakeSize(0.0, contentSize.height)];
    [mTextView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [mTextView setVerticallyResizable:YES];
    [mTextView setHorizontallyResizable:NO];
    [mTextView setAutoresizingMask:NSViewHeightSizable];
    [mTextView setEditable:NO];
     
    [[mTextView textContainer]
        setContainerSize:NSMakeSize(contentSize.width - 10, FLT_MAX)];
    [[mTextView textContainer] setWidthTracksTextView:YES];
    [mTextView setBackgroundColor:[NSColor colorWithSRGBRed:(61.0 / 255.0)
                                                      green:(39.0 / 255.0)
                                                      blue:(93.0 / 255.0)
                                                      alpha:1.0]];
    
    [mScrollView setDocumentView:mTextView];
    [mHelpWindow setContentView:mScrollView];
    
    [mTextView setTextColor:[NSColor whiteColor]];
    [[mTextView textStorage] setAttributedString:helpText];
}

- (void)aboutButton:(id)sender
{
    if (mAboutBox == nil)
    {
        [self createAboutBox];
    }

    [mAboutBox center];
    [mAboutBox makeKeyAndOrderFront:self];
}

- (void)createAboutBox
{
    NSBundle *bundle =
        [NSBundle bundleForClass:[MIDIThru_UIView class]];
    NSURL *creditsPath = [bundle URLForResource:@"Credits"
                          withExtension:@"html"];
    NSString *text = [NSString stringWithContentsOfURL:creditsPath
                      encoding:NSASCIIStringEncoding error:nil];
    NSAttributedString *aboutText = [[NSAttributedString alloc]
        initWithData:[text dataUsingEncoding:NSUnicodeStringEncoding]
        options:@{NSDocumentTypeDocumentAttribute:NSHTMLTextDocumentType}
        documentAttributes:nil error:nil];
    
    mAboutBox = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 350, 200)
        styleMask:(NSWindowStyleMaskClosable | NSWindowStyleMaskTitled)
        backing:NSBackingStoreBuffered defer:NO];
    [mAboutBox setReleasedWhenClosed:NO];
    [mAboutBox setBackgroundColor:[NSColor colorWithSRGBRed:(61.0 / 255.0)
                                 green:(39.0 / 255.0) blue:(93.0 / 255.0)
                                 alpha:1.0]];
    
    NSView *contentView = [[NSView alloc] initWithFrame:[mAboutBox frame]];
    [mAboutBox setContentView:contentView];

    NSTextField *about =
        [[NSTextField alloc] initWithFrame:[contentView frame]];
    [about setEditable:NO];
    [about setBezeled:NO];
    [about setDrawsBackground:NO];
    
    // Both of these are needed, otherwise hyperlink won't accept mousedown
    [about setAllowsEditingTextAttributes: YES];
    [about setSelectable: YES];
    [about setAttributedStringValue:aboutText];
    [contentView addSubview:about];
}

- (void)monitorTimer:(NSTimer *)timer
{
    if (mWindowSet == false)
    {
        [self setupWindow];
        mWindowSet = true;
    }

    while (mMIDIControl.readIndex != mMIDIControl.writeIndex)
    {
        mActivity = true;
        mMIDIControl.readIndex++;
        
        if (mMIDIControl.readIndex == kMaximumEvents)
        {
            mMIDIControl.readIndex = 0;
        }
    }
    
    if ((mActivity == true) && (mLightOn == false) && (++mLightOffCount > 5))
    {
        mLightOn = true;
        mActivity = false;
        mLightOnCount = 0;
        mLightOffCount = 0;
        mIndicatorColor = [NSColor redColor];
    }
    else if ((mLightOn == true) && (++mLightOnCount > 5))
    {
        mLightOn = false;
        mIndicatorColor = [NSColor clearColor];
    }
    
    [mView display];
}

@end
