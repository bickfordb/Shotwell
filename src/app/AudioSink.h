#import "AudioSource.h"

@protocol AudioSink <NSObject>
@property double volume;
@property (retain, atomic) id <AudioSource> audioSource;
- (void)stop;
- (void)start;
- (void)flush;
@end
