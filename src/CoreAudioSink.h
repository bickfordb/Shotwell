#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioQueue.h>
#import "Util.h"
#import "LibAVSource.h"

@interface CoreAudioSink : NSObject
- (bool)isSeeking;
- (int64_t)duration;
- (int64_t)elapsed;
- (void)seek:(int64_t)usec;
- (void)setOutputDeviceID:(NSString *)outputID;

@property (copy) On0 onDone;
@property (retain, atomic) LibAVSource *audioSource;
@property BOOL isDone;
@property BOOL isPaused;
@property double volume;

@end
