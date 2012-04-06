#import "AudioSource.h"


@protocol AudioSink <NSObject>
@property double volume;

- (void)stop;
- (void)start;
- (void)flush;
@end
