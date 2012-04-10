#import <Cocoa/Cocoa.h>
#import "md0/Track.h"


extern NSString * const TrackSavedLibraryNotification;
extern NSString * const TrackAddedLibraryNotification;
extern NSString * const TrackDeletedLibraryNotification;

@interface Library : NSObject {
  int64_t lastUpdatedAt_;
}

- (void)each:(void (^)(Track *))block; 
- (int)count;
@property int64_t lastUpdatedAt;
@end
// vim: filetype=objcpp
