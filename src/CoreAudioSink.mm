#import "CoreAudioSink.h"
#import "Log.h"
#define CHECK_RESULT(msg) \
    if (result != noErr) { \
        ERROR(@"Core Audio Initialization Failed"); \
        return; \
    }

const int kCoreAudioSinkNumBuffers = 3;

@interface CoreAudioSink (Private)
- (BOOL)isRunning;
- (void)onBuffer:(AudioQueueBufferRef)buffer;
@end

OSStatus _CheckStatus(int line, const char *file, const char *fname, OSStatus status) {
  if (status != 0) {
    LogMessage(file ? file : "?", line, ErrorLogLevel, [NSString stringWithFormat:@"%s() failed with status: %@", fname ? fname : "?", @(status)]);
  }
  return status;
}

#define CheckStatus(F, ...) _CheckStatus(__LINE__, __FILE__, #F, F(__VA_ARGS__))

static void BufferCallback(void *inUserData, AudioQueueRef queue, AudioQueueBufferRef buffer) {
  CoreAudioSink *sink = (CoreAudioSink *)inUserData;
  [sink onBuffer:buffer];
}

@implementation CoreAudioSink {
  LibAVSource *audioSource_;
  On0 onDone_;
  AudioQueueRef queue_;
  int numBuffers_;
  BOOL isPaused_;
  BOOL isDone_;
  NSString *outputIdentifier_;
}

@synthesize onDone = onDone_;
@synthesize isDone = isDone_;

- (LibAVSource *)audioSource {
  return audioSource_;
}

- (void)setAudioSource:(LibAVSource *)audioSource {
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
  NSError *err = [self fillBuffer:buffer];
  if (err) {
    NSLog(@"error filling buffer: %@", err);
  }
  if (buffer->mAudioDataByteSize > 0) {
    CheckStatus(AudioQueueEnqueueBuffer, queue_, buffer, 0, NULL);
  } else {
    INFO(@"freeing empty buffer");
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

- (NSError *)fillBuffer:(AudioQueueBufferRef)buffer {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  LibAVSource *src = audioSource_;
  [src retain];
  size_t len = buffer->mAudioDataBytesCapacity;
  // silence is golden
  memset(buffer->mAudioData, 0, len);
  NSError *err = [src getAudio:(uint8_t *)buffer->mAudioData length:&len];
  buffer->mAudioDataByteSize = len;
  buffer->mPacketDescriptionCount = 0;
  [src release];
  [pool release];
  return err;
}

- (id)init {
  self = [super init];
  if (self) {
    queue_ = NULL;
    outputIdentifier_ = nil;
    isPaused_ = YES;
    numBuffers_ = 0;
    //[self newQueue];
  }
  DEBUG(@"done init");
  return self;
}

- (void)newQueue {
  ERROR(@"new queue");
  double volume = 0.5;
  assert(queue_ == NULL);
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
  ERROR(@"start queue");
  assert(queue_ != NULL);
  CheckStatus(AudioQueueStart, queue_, NULL);
  NSError *err = nil;
  while (numBuffers_ < kCoreAudioSinkNumBuffers) {
    INFO(@"prefilling buffer");
    AudioQueueBufferRef buf = NULL;
    if (CheckStatus(AudioQueueAllocateBuffer, queue_, 32768, &buf)) {
      return;
    }
    err = [self fillBuffer:buf];
    if (err) {
      NSLog(@"err filling buffer: %@", err);
    }
    numBuffers_++;
    if (buf->mAudioDataByteSize > 0) {
      INFO(@"enqueueing buffer");
      if (CheckStatus(AudioQueueEnqueueBuffer, queue_, buf, 0, NULL)) {
        return;
      }
    } else {
      DEBUG(@"freeing empty buffer");
      if (CheckStatus(AudioQueueFreeBuffer, queue_, buf))
        return;
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

- (BOOL)isPaused {
  return isPaused_;
}

- (void)setIsPaused:(BOOL)isPaused {
  @synchronized(self) {
    if (isPaused == isPaused_) {
      return;
    }
    ERROR(@"pause: %d", (int)isPaused);
    [self willChangeValueForKey:@"paused"];
    isPaused_ = isPaused;
    if (!isPaused_) {
      ERROR(@"unpausing");
      [self newQueue];
    } else {
      ERROR(@"unpausing");
      [self resetQueue];
    }
    [self didChangeValueForKey:@"paused"];
  }
}

- (void)resetQueue {
  if (queue_)
    CheckStatus(AudioQueueDispose, queue_, true);
  queue_ = NULL;
  numBuffers_ = 0;
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
  return audioSource_.elapsed;
}

- (int64_t)duration {
  return audioSource_.duration;
}

- (void)seek:(int64_t)seconds {
  [audioSource_ seek:seconds];
}

- (bool)isSeeking {
  return audioSource_.isSeeking;
}

- (void)setOutputDeviceID:(NSString *)uid {
  ERROR(@"set output device ID: %@", uid);
  @synchronized(self) {
    [outputIdentifier_ release];
    outputIdentifier_ = [uid retain];
  }
  [self resetQueue];
  [self newQueue];
}

@end
