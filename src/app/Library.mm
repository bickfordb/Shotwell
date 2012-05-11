#import "app/Library.h"


NSString * const kLibraryTrackSaved = @"LibraryTrackSaved";
NSString * const kLibraryTrackAdded = @"LibraryTrackAdded";
NSString * const kLibraryTrackDeleted = @"LibraryTrackDeleted";
NSString * const kLibraryTrackChanged = @"LibraryTrackChanged";

@implementation Library
@synthesize lastUpdatedAt = lastUpdatedAt_;

- (void)each:(void (^)(Track *t)) t { }; 
- (int)count { return 0; };

- (void)delete:(Track *)track { }

- (void)notifyTrack:(Track *)t change:(NSString *)change {
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:kLibraryTrackChanged
    object:self
    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
      t, @"track",
      change, @"change", nil]];
}

- (NSURL *)coverArtURLForTrack:(Track *)t {
  return nil;
}

- (NSURL *)urlForTrack:(Track *)t {
  return nil;
}
@end

