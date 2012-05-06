#import "app/AudioSource.h"

@protocol AudioSink <NSObject>
@property double volume;
@property (retain, atomic) id <AudioSource> audioSource;
@property bool isPaused;
- (void)flush;
@end
