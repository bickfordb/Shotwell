#import <Cocoa/Cocoa.h>
#import "app/Track.h"


@class Library;
typedef void (^OnTrackChange)(Library *, Track *t);


extern NSString * const kLibraryTrackChanged;
extern NSString * const kLibraryTrackSaved;
extern NSString * const kLibraryTrackAdded;
extern NSString * const kLibraryTrackDeleted;

@interface Library : NSObject {
  int64_t lastUpdatedAt_;
}

- (int)count;
- (void)delete:(Track *)track;
- (void)each:(void (^)(Track *))block; 
- (void)notifyTrack:(Track *)t change:(NSString *)change;
- (NSURL *)urlForTrack:(Track *)t;
- (NSURL *)coverArtURLForTrack:(Track *)t;
@property int64_t lastUpdatedAt;
@end
// vim: filetype=objcpp
