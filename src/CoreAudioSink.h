
#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>
//#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioQueue.h>

#import "AudioSink.h"

@interface CoreAudioSink : NSObject <AudioSink> {
  id <AudioSource, NSObject> audioSource_;
  On0 onDone_;
  AudioQueueRef queue_;
  int numBuffers_;
  BOOL isPaused_;
  BOOL isDone_;
  NSString *outputIdentifier_;
}

@property (copy) On0 onDone;
@property BOOL isDone;

@end
