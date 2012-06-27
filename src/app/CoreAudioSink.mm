#import "app/CoreAudioSink.h"
#import "app/Log.h"
#define CHECK_RESULT(msg) \
    if (result != noErr) { \
        ERROR(@"Core Audio Initialization Failed"); \
        return; \
    }

static OSStatus GetAudioCallback(void *context,
    AudioUnitRenderActionFlags *flags,
    const AudioTimeStamp *timestamp,
    uint32_t busNumber,
    uint32_t numFrames,
    AudioBufferList *ioData) {
  CoreAudioSink *sink = (CoreAudioSink *)context;
  for (uint32_t i = 0; i < ioData->mNumberBuffers; i++) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    id <AudioSource> src = sink.audioSource;
    [src retain];
    memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
    [src
      getAudio:(uint8_t *)ioData->mBuffers[i].mData
      length:ioData->mBuffers[i].mDataByteSize];
    [src release];
    [pool release];
  }
  return 0;
}

@interface CoreAudioSink (Private)
- (void)stopOutputUnit;
- (void)startOutputUnit;
@end

@implementation CoreAudioSink
@synthesize audioSource = audioSource_;

- (id)init {
  self = [super init];
  if (self) {
    volume_ = 0.5;
    isPaused_ = true;
  }
  return self;
}
- (void)stopOutputUnit {
  AudioOutputUnitStop(outputAudioUnit_);
  struct AURenderCallbackStruct callback;
  callback.inputProc = NULL;
  callback.inputProcRefCon = NULL;
  AudioUnitSetProperty(outputAudioUnit_, kAudioUnitProperty_SetRenderCallback,
      kAudioUnitScope_Input, 0, &callback, sizeof(callback));
  CloseComponent(outputAudioUnit_);
}

- (void)startOutputUnit {
  memset(&outputAudioUnit_, 0, sizeof(outputAudioUnit_));
  Component comp;
  ComponentDescription desc;
  struct AURenderCallbackStruct callback;
  AudioStreamBasicDescription requestedDesc;
  OSStatus result = 0;

  // Hardcode to s16le stereo:
  requestedDesc.mFormatID = kAudioFormatLinearPCM;
  requestedDesc.mFormatFlags = kLinearPCMFormatFlagIsPacked;
  requestedDesc.mChannelsPerFrame = 2;
  requestedDesc.mSampleRate = 44100;
  requestedDesc.mBitsPerChannel = 16;
  requestedDesc.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;

  requestedDesc.mFramesPerPacket = 1;
  requestedDesc.mBytesPerFrame = requestedDesc.mBitsPerChannel * requestedDesc.mChannelsPerFrame / 8;
  requestedDesc.mBytesPerPacket = requestedDesc.mBytesPerFrame * requestedDesc.mFramesPerPacket;

  /* Locate the default output audio unit */
  desc.componentType = kAudioUnitType_Output;
  desc.componentSubType = kAudioUnitSubType_DefaultOutput;
  desc.componentManufacturer = kAudioUnitManufacturer_Apple;
  desc.componentFlags = 0;
  desc.componentFlagsMask = 0;

  comp = FindNextComponent(NULL, &desc);
  if (comp == NULL) {
    ERROR(@"Failed to start CoreAudio: FindNextComponent returned NULL");
    return;
  }
  result = OpenAComponent(comp, &outputAudioUnit_);
  result = AudioUnitInitialize(outputAudioUnit_);
  AudioUnitSetProperty(outputAudioUnit_,
      kAudioUnitProperty_StreamFormat,
      kAudioUnitScope_Input,
      0,
      &requestedDesc,
      sizeof(requestedDesc));
  callback.inputProc = GetAudioCallback;
  callback.inputProcRefCon = self;
  AudioUnitSetProperty(outputAudioUnit_, kAudioUnitProperty_SetRenderCallback,
      kAudioUnitScope_Input, 0, &callback, sizeof(callback));
  AudioOutputUnitStart(outputAudioUnit_);
  AudioUnitSetParameter(outputAudioUnit_,
      kHALOutputParam_Volume, kAudioUnitScope_Output, 0, (AudioUnitParameterValue)volume_, 0);
}

- (void)dealloc {
  if (!isPaused_) {
    [self stopOutputUnit];
    isPaused_ = true;
  }
  [audioSource_ release];
  [super dealloc];
}

- (bool)isPaused {
  return isPaused_;
}

- (void)setIsPaused:(bool)isPaused {
  @synchronized(self) {
    if (isPaused == isPaused_) {
      INFO(@"already %d", (int)isPaused);
      return;
    }
    if (!isPaused) {
      [self startOutputUnit];
    } else {
      [self stopOutputUnit];
    }
    isPaused_ = isPaused;
  }
}

- (double)volume {
  return volume_;
}

- (void)setVolume:(double)pct {
  volume_ = pct;
  if (isPaused_)
    return;
  OSStatus status = AudioUnitSetParameter(outputAudioUnit_,
      kHALOutputParam_Volume, kAudioUnitScope_Output, 0, (AudioUnitParameterValue)pct, 0);
  if (status != 0)
    ERROR(@"failed to set volume (%d)", status);
}

- (int64_t)elapsed {
  return self.audioSource.elapsed;
}

- (int64_t)duration {
  return self.audioSource.duration;
}

- (void)seek:(int64_t)seconds {
  [self.audioSource seek:seconds];
}

- (bool)isSeeking {
  return self.audioSource.isSeeking;
}

@end
