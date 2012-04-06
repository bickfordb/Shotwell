#import <Cocoa/Cocoa.h>

#import "md0/Track.h"

@interface Plugin : NSObject { 
  NSView *content_;
}
- (void)start;
- (void)stop;
- (void)showVertical:(bool)isVertical;
- (void)hide;
- (void)hideTrackTable;
- (void)trackStarted:(NSDictionary *)t;
- (void)trackEnded:(NSDictionary *)t;
- (void)trackUpdated:(NSDictionary *)t;
- (NSView *)content;

@end
