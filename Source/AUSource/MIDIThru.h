// 
// MIDIThru.h 
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

#ifndef __MIDIThru_h__
#define __MIDIThru_h__

#include <CoreMIDI/CoreMIDI.h>
#include "AUMIDIEffectBase.h"
#include "LockFreeFIFO.h"
#include <os/log.h>

#define LT_NO_COCOA
#include "LTLog.h"

#define kMIDIThruVersion 65538

#define kMIDIPacketListSize 2048

// Custom properties IDs must be 64000 or greater
// See AudioUnit/AudioUnitProperties.h for a list of
// Apple-defined standard properties
#define kAudioUnitCustomPropertyUICB 64056

class MIDIThru : public AUMIDIEffectBase
{
public:
    MIDIThru(AudioUnit component);
    virtual ~MIDIThru();

    virtual OSStatus GetPropertyInfo(AudioUnitPropertyID inID,
                                     AudioUnitScope inScope,
                                     AudioUnitElement inElement,
                                     UInt32& outDataSize,
                                     Boolean& outWritable);

    virtual OSStatus GetProperty(AudioUnitPropertyID inID,
                                 AudioUnitScope inScope,
                                 AudioUnitElement inElement, void *outData);
  
    virtual OSStatus SetProperty(AudioUnitPropertyID inID,
                                 AudioUnitScope inScope,
                                 AudioUnitElement inElement,
                                 const void *inData, UInt32 inDataSize);

    virtual bool SupportsTail() { return false; }

    virtual OSStatus Version() { return kMIDIThruVersion; }

    virtual OSStatus HandleMidiEvent(UInt8 status, UInt8 channel,
                                     UInt8 data1, UInt8 data2,
                                     UInt32 inOffsetSampleFrame);
  
    virtual OSStatus Render(AudioUnitRenderActionFlags &ioActionFlags,
                            const AudioTimeStamp& inTimeStamp, UInt32 nFrames);

private:
    AUMIDIOutputCallbackStruct mMIDIOutCB;
    AUMIDIOutputCallbackStruct mUICB;
    LockFreeFIFO<MIDIPacket> mOutputPacketFIFO;
    os_log_t mLog;
};

#endif
