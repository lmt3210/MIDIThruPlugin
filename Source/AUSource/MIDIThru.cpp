// 
// MIDIThru.cpp
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

#include "MIDIThru.h"


AUDIOCOMPONENT_ENTRY(AUMIDIEffectFactory, MIDIThru)

MIDIThru::MIDIThru(AudioUnit component) : AUMIDIEffectBase(component),
    mOutputPacketFIFO(LockFreeFIFO<MIDIPacket>(32))
{
    mLog = os_log_create("com.larrymtaylor.au.MIDIThru", "AU");
    os_log_with_type(mLog, OS_LOG_TYPE_INFO, "MIDIThru::MIDIThru");

    CreateElements();
    
    mMIDIOutCB.midiOutputCallback = nullptr;
    mUICB.midiOutputCallback = nullptr;
}

MIDIThru::~MIDIThru()
{
    os_log_with_type(mLog, OS_LOG_TYPE_INFO, "MIDIThru::~MIDIThru");
}

OSStatus MIDIThru::GetPropertyInfo(AudioUnitPropertyID inID,
    AudioUnitScope inScope, AudioUnitElement inElement,
    UInt32 & outDataSize, Boolean & outWritable)
{
    OSStatus status = kAudioUnitErr_InvalidProperty;

    if (inScope == kAudioUnitScope_Global)
    {
        switch (inID)
        {
            case kAudioUnitProperty_CocoaUI:
                outWritable = false;
                outDataSize = sizeof(AudioUnitCocoaViewInfo);
                status = noErr;
                break;
            case kAudioUnitProperty_MIDIOutputCallbackInfo:
                outWritable = false;
                outDataSize = sizeof(CFArrayRef);
                status = noErr;
                break;
            case kAudioUnitProperty_MIDIOutputCallback:
                outWritable = true;
                outDataSize = sizeof(AUMIDIOutputCallbackStruct);
                status = noErr;
                break;
        }
    }
    else
    {
        status = kAudioUnitErr_InvalidScope;
    }

    char str1[LT_AU_MESSAGE_LENGTH] = { 0 };
    char str2[LT_AU_MESSAGE_LENGTH] = { 0 };
    parameterIDToString(inID, str1);
    statusToString(status, str2);
    
    os_log_with_type(mLog, OS_LOG_TYPE_INFO,
                    "MIDIThru::GetPropertyInfo ID = %{public}s, "
                    "returning %{public}s", str1, str2);

    return status;
}

OSStatus MIDIThru::GetProperty(AudioUnitPropertyID inID,
    AudioUnitScope inScope, AudioUnitElement inElement, void *outData)
{
    OSStatus status = kAudioUnitErr_InvalidProperty;

    if (inScope == kAudioUnitScope_Global) 
    {
        switch (inID)
        {
            case kAudioUnitProperty_MIDIOutputCallbackInfo:
            {
                CFStringRef string = CFSTR("MIDIThruOut");
                CFArrayRef array =
                CFArrayCreate(kCFAllocatorDefault,
                              (const void **)&string, 1, nullptr);
                CFRelease(string);
                *((CFArrayRef*)outData) = array;
                status = noErr;
            }
            break;
            case kAudioUnitProperty_CocoaUI:
            {
                // Look for a resource in the main bundle by name and type.
                CFBundleRef bundle =
                CFBundleGetBundleWithIdentifier
                    (CFSTR("com.larrymtaylor.au.MIDIThru"));
 
                if (bundle == NULL)
                {
                    os_log_with_type(mLog, OS_LOG_TYPE_ERROR,
                                     "MIDIThru bundle == NULL");
                    return -1;
                }
                
                CFURLRef bundleURL =
                CFBundleCopyResourceURL(bundle, CFSTR("MIDIThruView"),
                                        CFSTR("bundle"), NULL);
                
                if (bundleURL == NULL)
                {
                    os_log_with_type(mLog, OS_LOG_TYPE_ERROR,
                                     "MIDIThru bundleURL == NULL");
                    return -1;
                }
                
                // Name of the main class that implements
                // the AUCocoaUIBase protocol
                CFStringRef className = CFSTR("MIDIThru_ViewFactory");
                AudioUnitCocoaViewInfo cocoaInfo =
                    { bundleURL, { className } };
                *((AudioUnitCocoaViewInfo *)outData) = cocoaInfo;
                status = noErr;
            }
            break;
        }
    }
    else
    {
        status = kAudioUnitErr_InvalidScope;
    }

    char str1[LT_AU_MESSAGE_LENGTH] = { 0 };
    char str2[LT_AU_MESSAGE_LENGTH] = { 0 };
    parameterIDToString(inID, str1);
    statusToString(status, str2);
    os_log_with_type(mLog, OS_LOG_TYPE_INFO,
                    "MIDIThru::GetProperty ID = %{public}s, "
                    "returning %{public}s", str1, str2);

    return status;
}

OSStatus MIDIThru::SetProperty(AudioUnitPropertyID inID,
    AudioUnitScope inScope, AudioUnitElement inElement,
    const void *inData, UInt32 inDataSize)
{
    OSStatus status = kAudioUnitErr_InvalidProperty;
    
    if (inScope == kAudioUnitScope_Global)
    {
        switch (inID)
        {
            case kAudioUnitProperty_MIDIOutputCallback:
                mMIDIOutCB = *((AUMIDIOutputCallbackStruct *)inData);
                status = noErr;
                break;
            case kAudioUnitCustomPropertyUICB:
                mUICB = *((AUMIDIOutputCallbackStruct *)inData);
                status = noErr;
                break;
        }
    }
    else
    {
        status = kAudioUnitErr_InvalidScope;
    }

    char str1[LT_AU_MESSAGE_LENGTH] = { 0 };
    char str2[LT_AU_MESSAGE_LENGTH] = { 0 };
    parameterIDToString(inID, str1);
    statusToString(status, str2);
    os_log_with_type(mLog, OS_LOG_TYPE_INFO,
                    "MIDIThru::SetProperty ID = %{public}s, "
                    "returning %{public}s", str1, str2);

    return status;
}

OSStatus MIDIThru::HandleMidiEvent(UInt8 status, UInt8 channel,
    UInt8 data1, UInt8 data2, UInt32 inOffsetSampleFrame)
{
    if (!IsInitialized())
    {
        return kAudioUnitErr_Uninitialized;
    }
  
    MIDIPacket *packet = mOutputPacketFIFO.WriteItem();
    mOutputPacketFIFO.AdvanceWritePtr();
    
    if (packet == NULL)
    {
        return kAudioUnitErr_FailedInitialization;
    }
    
    memset(packet->data, 0, sizeof(Byte) * 256);
    ((status == 0xC0) || (status == 0xD0)) ? packet->length = 2 :
        packet->length = 3;
    packet->data[0] = status | channel;
    packet->data[1] = data1;
    packet->data[2] = data2;
    packet->timeStamp = (MIDITimeStamp)inOffsetSampleFrame;

    return noErr;
}

OSStatus MIDIThru::Render(AudioUnitRenderActionFlags &ioActionFlags,
    const AudioTimeStamp& inTimeStamp, UInt32 nFrames)
{
    // Zero the audio buffers
    AUOutputElement *outputBus = GetOutput(0);
    outputBus->PrepareBuffer(nFrames);
    AudioBufferList& outputBufList = outputBus->GetBufferList();
    AUBufferList::ZeroBuffer(outputBufList);

    // Process the MIDI data
    Byte listBuffer[kMIDIPacketListSize];
    MIDIPacketList *packetList = (MIDIPacketList*)listBuffer;
    MIDIPacket *packetListIterator = MIDIPacketListInit(packetList);
  
    MIDIPacket *packet = mOutputPacketFIFO.ReadItem();
    
    while (packet != NULL)
    {
        // This is where the MIDI packets get processed
        if (packetListIterator == NULL)
        {
            return noErr;
        }

        packet->timeStamp = inTimeStamp.mHostTime;
        packetListIterator =
            MIDIPacketListAdd(packetList, kMIDIPacketListSize,
                              packetListIterator, packet->timeStamp,
                              packet->length, packet->data);
        mOutputPacketFIFO.AdvanceReadPtr();
        packet = mOutputPacketFIFO.ReadItem();
    }
   
    if ((mMIDIOutCB.midiOutputCallback != NULL) &&
        (packetList->numPackets > 0))
    {
        mMIDIOutCB.midiOutputCallback(mMIDIOutCB.userData,
                                      &inTimeStamp, 0, packetList);
    }
      
    if ((mUICB.midiOutputCallback != NULL) && (packetList->numPackets > 0))
    {
        mUICB.midiOutputCallback(mUICB.userData, &inTimeStamp, 0, packetList);
    }
      
    return noErr;
}
