#import "app/CoreAudioSink.h"
#import "app/Log.h"
#define CHECK_RESULT(msg) \
    if (result != noErr) { \
        ERROR(@"Core Audio Initialization Failed"); \
        return; \
    }

const int kCoreAudioSinkNumBuffers = 3;

@interface CoreAudioSink (Private)
- (void)fillBuffer:(AudioQueueBufferRef)buffer;
- (void)startQueue;
- (BOOL)isRunning;
- (void)onBuffer:(AudioQueueBufferRef)buffer;
@end

OSStatus _CheckStatus(int line, const char *file, const char *fname, const char *args, OSStatus status) {
  if (status) {
    LogMessage(file, line, ErrorLogLevel, @"%s() failed with status: %d", fname, args, (int)status);
  }
  return status;
}

#define CheckStatus(F, ...) _CheckStatus(__LINE__, __FILE__, #F, #__VA_ARGS__, F(__VA_ARGS__))

static void BufferCallback(void *inUserData, AudioQueueRef queue, AudioQueueBufferRef buffer) {
  CoreAudioSink *sink = (CoreAudioSink *)inUserData;
  [sink onBuffer:buffer];
}

@implementation CoreAudioSink
//@synthesize audioSource = audioSource_;
@synthesize onDone = onDone_;
@synthesize isDone = isDone_;

- (id <AudioSource>)audioSource {
  return audioSource_;
}

- (void)setAudioSource:(id <AudioSource>)audioSource {
  [self willChangeValueForKey:@"audioSource"];
  @synchronized (self) {
    [audioSource retain];
    [audioSource_ release];
    audioSource_ = audioSource;
  }
  self.isDone = NO;
  if (!isPaused_) {
    [self startQueue];
  }
  [self didChangeValueForKey:@"audioSource"];
}

- (void)onBuffer:(AudioQueueBufferRef)buffer {
  [self fillBuffer:buffer];
  if (buffer->mAudioDataByteSize > 0) {
    CheckStatus(AudioQueueEnqueueBuffer, queue_, buffer, 0, NULL);
  } else {
    // Free the buffer since we're done with it.
    CheckStatus(AudioQueueFreeBuffer, queue_, buffer);
    numBuffers_--;
    isDone_ = YES;
    if (onDone_) {
      onDone_();
    }
  }
}

- (AudioStreamBasicDescription)stereoFormat {
  AudioStreamBasicDescription format;
  memset(&format, 0, sizeof(format));
  // Hardcode to S16LE stereo
  format.mFormatID = kAudioFormatLinearPCM;
  format.mFormatFlags = kLinearPCMFormatFlagIsPacked;
  format.mChannelsPerFrame = 2;
  format.mSampleRate = 44100;
  format.mBitsPerChannel = 16;
  format.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;

  format.mFramesPerPacket = 1;
  format.mBytesPerFrame = format.mBitsPerChannel * format.mChannelsPerFrame / 8;
  format.mBytesPerPacket = format.mBytesPerFrame * format.mFramesPerPacket;
  return format;
}

- (void)fillBuffer:(AudioQueueBufferRef)buffer {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  id <AudioSource> src = self.audioSource;
  [src retain];
  buffer->mAudioDataByteSize = [src getAudio:(uint8_t *)buffer->mAudioData length:buffer->mAudioDataBytesCapacity];
  buffer->mPacketDescriptionCount = 0;
  [src release];
  [pool release];
}

- (id)init {
  self = [super init];
  if (self) {
    queue_ = NULL;
    outputIdentifier_ = nil;
    isPaused_ = YES;
    numBuffers_ = 0;
    [self newQueue];
  }
  DEBUG(@"done init");
  return self;
}

- (void)newQueue {
  DEBUG(@"new queue");
  double volume = 0.5;
  if (queue_) {
    volume = self.volume;
    CheckStatus(AudioQueueDispose, queue_, true);
    queue_ = NULL;
    numBuffers_ = 0;
  }
  AudioStreamBasicDescription format = [self stereoFormat];
  CheckStatus(AudioQueueNewOutput, &format, BufferCallback, (void *)self, nil, nil, 0, &queue_);
  if (outputIdentifier_) {
    CheckStatus(AudioQueueSetProperty, queue_, kAudioQueueProperty_CurrentDevice, &outputIdentifier_, sizeof(outputIdentifier_));
  }
  self.volume = volume;
}

- (BOOL)isRunning {
  UInt32 isRunning = 0;
  UInt32 sz = sizeof(isRunning);
  if (queue_)
    CheckStatus(AudioQueueGetProperty, queue_, kAudioQueueProperty_IsRunning, &isRunning, &sz);
  return isRunning != 0;
}

- (void)startQueue {
  DEBUG(@"starting queue");
  CheckStatus(AudioQueueStart, queue_, NULL);
  while (numBuffers_ < (kCoreAudioSinkNumBuffers - 1)) {
    AudioQueueBufferRef buf = NULL;
    if (CheckStatus(AudioQueueAllocateBuffer, queue_, 32768, &buf)) {
      return;
    }
    [self fillBuffer:buf];
    numBuffers_++;
    if (buf->mAudioDataByteSize > 0) {
      CheckStatus(AudioQueueEnqueueBuffer, queue_, buf, 0, NULL);
      INFO(@"enqueueing buffer");
    } else {
      DEBUG(@"freeing empty buffer");
      CheckStatus(AudioQueueFreeBuffer, queue_, buf);
      numBuffers_--;
      break;
    }
  }
  INFO(@"is running: %d", (int)self.isRunning);
}

- (void)dealloc {
  DEBUG(@"dealloc: %d", self);
  if (queue_) {
    CheckStatus(AudioQueueDispose, queue_, NO);
    queue_ = NULL;
  }
  [outputIdentifier_ release];
  [audioSource_ release];
  [onDone_ release];
  [super dealloc];

}

- (bool)isPaused {
  return isPaused_;
}

- (void)setIsPaused:(bool)isPaused {
  INFO(@"paused: %d", (int)isPaused);
  @synchronized(self) {
    if (!isPaused) {
      [self startQueue];
    } else {
      if (queue_) {
        INFO(@"pausing");
        CheckStatus(AudioQueuePause, queue_);
      }
    }
    isPaused_ = isPaused;
  }
}

- (double)volume {
  Float32 result = 0.0;
  if (queue_) {
    CheckStatus(AudioQueueGetParameter, queue_, kAudioQueueParam_Volume,  &result);
  }
  return (double)result;
}

- (void)setVolume:(double)pct {
  if (queue_) {
    CheckStatus(AudioQueueSetParameter, queue_, kAudioQueueParam_Volume, (Float32)pct);
  }
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

- (void)setOutputDeviceID:(NSString *)uid {
  INFO(@"set output device ID: %@", uid);
  @synchronized(self) {
    [outputIdentifier_ release];
    outputIdentifier_ = [uid retain];
  }
  [self newQueue];
  if (!isPaused_) {
    [self startQueue];
  }
}

@end
