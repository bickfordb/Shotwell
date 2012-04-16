#import <Cocoa/Cocoa.h>
#import "md0/Loop.h"
#import "md0/Track.h"

@interface AppleCoverArtClient : NSObject {
  Loop *loop_;
}
@property (retain) Loop *loop;

- (void)search:(NSString *)d entity:(NSString *)entity withResult:(void(^)(NSArray *results))onResults;
- (void)search:(NSString *)term withArtworkData:(void (^)(NSData *d))block;
@end


// vim: filetype=objcpp
