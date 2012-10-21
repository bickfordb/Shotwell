#import "app/CoreAudioSink.h"
#import "app/Log.h"
#define CHECK_RESULT(msg) \
    if (result != noErr) { \
        ERROR(@"Core Audio Initialization Failed"); \
        return; \
    }

const int kCoreAudioSinkNumBuffers = 3;


@interface CoreAudioSink (Private)
- (void)queue:(AudioQueueRef)aQueue fillBuffer:(AudioQueueBufferRef)buffer;
- (void)stopQueue;
- (void)startQueue;

@end

static void BufferCallback(void *inUserData, AudioQueueRef queue, AudioQueueBufferRef buffer) {
  CoreAudioSink *sink = (CoreAudioSink *)inUserData;
  [sink queue:queue fillBuffer:buffer];
}

@implementation CoreAudioSink
@synthesize audioSource = audioSource_;

- (void)queue:(AudioQueueRef)aQueue fillBuffer:(AudioQueueBufferRef)buffer {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  id <AudioSource> src = self.audioSource;
  [src retain];
  buffer->mAudioDataByteSize = [src getAudio:(uint8_t *)buffer->mAudioData length:buffer->mAudioDataBytesCapacity];
  buffer->mPacketDescriptionCount = 0;
  [src release];
  [pool release];
  AudioQueueEnqueueBuffer(aQueue, buffer, 0, NULL);
}

- (id)init {
  self = [super init];
  if (self) {
    volume_ = 0.5;
    isPaused_ = true;
    queue_ = NULL;
    AudioStreamBasicDescription fmt;
    memset(&fmt, 0, sizeof(fmt));
    // Hardcode to S16LE stereo
    fmt.mFormatID = kAudioFormatLinearPCM;
    fmt.mFormatFlags = kLinearPCMFormatFlagIsPacked;
    fmt.mChannelsPerFrame = 2;
    fmt.mSampleRate = 44100;
    fmt.mBitsPerChannel = 16;
    fmt.mFormatFlags |= kLinearPCMFormatFlagIsSignedInteger;

    fmt.mFramesPerPacket = 1;
    fmt.mBytesPerFrame = fmt.mBitsPerChannel * fmt.mChannelsPerFrame / 8;
    fmt.mBytesPerPacket = fmt.mBytesPerFrame * fmt.mFramesPerPacket;
    OSStatus newStatus = AudioQueueNewOutput(&fmt, BufferCallback, (void *)self, nil, nil, 0, &queue_);
    if (newStatus) {
      ERROR(@"failed to allocate output queue: %d", (int)newStatus);
    }
    numBuffers_ = 0;
  }
  return self;
}

- (void)stopQueue {
  AudioQueueStop(queue_, YES);
  for (int i = 0; i < numBuffers_; i++) {
    AudioQueueFreeBuffer(queue_, buffers_[i]);
    buffers_[i] = NULL;
  }
  numBuffers_ = 0;
}

- (void)startQueue {
  OSStatus startRet = AudioQueueStart(queue_, NULL);
  if (startRet) {
    ERROR(@"failed to start queue: %d", (int)startRet);
    return;
  }
  while (numBuffers_ < 3) {
    AudioQueueBufferRef buf = NULL;
    OSStatus allocStatus = AudioQueueAllocateBuffer(queue_, 32768, &buf);
    if (allocStatus != 0) {
      ERROR(@"failed to allocated buffer: %d", (int)allocStatus);
      return;
    }
    buffers_[numBuffers_] = buf;
    [self queue:queue_ fillBuffer:buf];
    numBuffers_++;
  }
}

- (void)dealloc {
  if (!isPaused_) {
    [self stopQueue];
    isPaused_ = true;
  }
  if (queue_) {
    OSStatus st = AudioQueueDispose(queue_, NO);
    if (st != 0) {
      ERROR(@"failed to dipose of queue: %d", (int)st);
    }
    queue_ = NULL;
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
      [self startQueue];
    } else {
      [self stopQueue];
    }
    isPaused_ = isPaused;
  }
}

- (double)volume {
  Float32 result = 0.0;
  OSStatus status = AudioQueueGetParameter(queue_, kAudioQueueParam_Volume,  &result);
  if (status != 0) {
    ERROR(@"failed to read volume (%d)", (int)status);
  }
  return (double)result;
}

- (void)setVolume:(double)pct {
  volume_ = pct;
  if (isPaused_)
    return;
  OSStatus status = AudioQueueSetParameter(queue_, kAudioQueueParam_Volume, (Float32)pct);
  if (status != 0)
    ERROR(@"failed to set volume (%d)", (int)status);
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

  [self stopQueue];

	OSStatus status = AudioQueueSetProperty(queue_, kAudioQueueProperty_CurrentDevice, &uid, sizeof(uid));
	if (status != noErr) {
		ERROR(@"unexpected error while setting the output device: %d", (int)status);
		if (status == kAudioQueueErr_InvalidRunState) {
			ERROR(@"Invalid run state");
		}
    return;
	}
  [self startQueue];
}

@end
