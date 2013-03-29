#import <Cocoa/Cocoa.h>

extern NSString *PlayerTrackChange;

@interface Player : NSObject

+ (Player *)shared;
- (void)playTrack:(NSMutableDictionary *)track;
- (void)seek:(int64_t)amt;

@property (copy) NSString *outputDevice;
@property (readonly) NSDictionary *outputDevices;
@property (readonly) NSMutableDictionary *track;
@property BOOL isPaused;
@property (readonly) BOOL isDone;
@property (readonly) BOOL isSeeking;
@property double volume;
@property (readonly) int64_t duration;
@property (readonly) int64_t elapsed;
@end

