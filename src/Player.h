#import <Cocoa/Cocoa.h>

extern NSString *PlayerTrackChange;


@interface Player : NSObject

- (void)playTrack:(NSMutableDictionary *)track;
+ (Player *)shared;
- (int64_t)elapsed;
- (int64_t)duration;
- (BOOL)isSeeking;
- (BOOL)isPlaying;
@property (retain) NSMutableDictionary *track;
@property double volume;
@property (assign) NSString *outputDevice;
@property (readonly) NSDictionary *outputDevices;

- (void)seek:(int64_t)amt;
- (BOOL)isDone;
@property BOOL isPaused;
@end

