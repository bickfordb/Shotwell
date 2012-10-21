
#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>
//#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioQueue.h>

#import "app/AudioSink.h"


@interface CoreAudioSink : NSObject <AudioSink> {
  id <AudioSource, NSObject> audioSource_;
  AudioQueueRef queue_;
  UInt64 packetIndex_;
  UInt32 numPacketsToRead_;
  int numBuffers_;
  AudioQueueBufferRef buffers_[3];
  double volume_;
  bool isPaused_;
}

@end
