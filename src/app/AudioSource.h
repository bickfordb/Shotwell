#include <Cocoa/Cocoa.h>
#include <stdint.h>

typedef enum { 
  // initial or stopped state
  kPausedAudioSourceState = 0,
  // everything else 
  kPlayingAudioSourceState,
  // error or end of file have the same status since they have the same use case
  kEOFAudioSourceState} AudioSourceState;

@protocol AudioSource <NSObject>
- (void)getAudio:(uint8_t *)bytes length:(size_t)len;
- (void)seek:(int64_t)usecs;
- (bool)isSeeking;
- (int64_t)duration;
- (int64_t)elapsed;
- (AudioSourceState)state;
- (NSString *)url;
@property bool isPaused;
@end

