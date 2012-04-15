#import <Cocoa/Cocoa.h>
#import "md0/Loop.h"
#import "md0/Track.h"

@interface AppleCoverArtClient : NSObject {
  Loop *loop_;
  NSMutableArray *queries_;
}
@property (retain) Loop *loop;
@property (retain) NSMutableArray *queries;

- (void)queryTrack:(Track *)track block:(void (^)(NSString *artworkURL))block; 
@end


// vim: filetype=objcpp
