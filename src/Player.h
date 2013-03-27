#import <Cocoa/Cocoa.h>

extern NSString *PlayerTrackChange;

@interface Player : NSObject

+ (Player *)shared;
- (void)playTrack:(NSMutableDictionary *)track;
- (void)seek:(int64_t)amt;

@property (assign) NSString *outputDevice;
@property (readonly) NSDictionary *outputDevices;
@property (retain) NSMutableDictionary *track;
@property BOOL isPaused;
@property BOOL isDone;
@property BOOL isSeeking;
@property double volume;
@property int64_t duration;
@property int64_t elapsed;
@end

