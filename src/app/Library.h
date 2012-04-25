#import <Cocoa/Cocoa.h>
#import "app/Track.h"


@class Library;
typedef void (^OnTrackChange)(Library *, Track *t);

@interface Library : NSObject {
  int64_t lastUpdatedAt_;
  OnTrackChange onAdded_;
  OnTrackChange onSaved_;
  OnTrackChange onDeleted_;
}

@property (copy) OnTrackChange onAdded;
@property (copy) OnTrackChange onSaved;
@property (copy) OnTrackChange onDeleted;

- (void)each:(void (^)(Track *))block; 
- (int)count;
@property int64_t lastUpdatedAt;
@end
// vim: filetype=objcpp
