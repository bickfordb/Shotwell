#import "AudioSource.h"
#import "Util.h"


@protocol AudioSink <NSObject>
@property double volume;
@property (retain, atomic) id <AudioSource> audioSource;
@property BOOL isPaused;
@property BOOL isDone;
@property (copy) On0 onDone;

- (int64_t)elapsed;
- (int64_t)duration;
- (void)seek:(int64_t)usec;
- (bool)isSeeking;
- (void)setOutputDeviceID:(NSString *)outputID;

@end
