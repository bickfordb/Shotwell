#import <Cocoa/Cocoa.h>

extern NSString *PlayerTrackChange;


@interface Player : NSObject {
  NSMutableDictionary *track_;
}

- (void)playTrack:(NSMutableDictionary *)track;
+ (Player *)shared;

@end

