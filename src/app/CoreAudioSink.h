
#import <CoreAudio/CoreAudio.h>
#import <CoreServices/CoreServices.h>
#import <AudioUnit/AudioUnit.h>

#import "md0/AudioSink.h"

@interface CoreAudioSink : NSObject <AudioSink> {  
  id <AudioSource, NSObject> audioSource_;
  AudioUnit outputAudioUnit_;
	void *buffer_;
	uint32_t bufferOffset_;
	uint32_t bufferSize_;
  bool opened_;
  double volume_;
}
//@property (retain, atomic) id <AudioSource> audioSource;
- (id)initWithSource:(id <AudioSource>)audioSource;

@end
