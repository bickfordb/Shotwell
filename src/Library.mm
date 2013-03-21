#import "Library.h"

NSString * const kLibraryTrackSaved = @"LibraryTrackSaved";
NSString * const kLibraryTrackAdded = @"LibraryTrackAdded";
NSString * const kLibraryTrackDeleted = @"LibraryTrackDeleted";
NSString * const kLibraryTrackChanged = @"LibraryTrackChanged";

@implementation Library
@synthesize lastUpdatedAt = lastUpdatedAt_;

- (id)init {
  self = [super init];
  if (self) {
    self.lastUpdatedAt = [NSDate date];
  }
  return self;
}

- (void)dealloc {
  [lastUpdatedAt_ release];
  [super dealloc];
}

- (void)each:(void (^)(NSMutableDictionary *t)) t { };
- (int)count {
  return 0;
};

- (id)objectForKeyedSubscript:(id)someID {
  return nil;
}

- (void)setObject:(id)o forKeyedSubscript:(id)k {
}

- (void)scan:(NSArray *)paths {

}

- (void)delete:(NSMutableDictionary *)track { }

- (void)notifyTrack:(NSMutableDictionary *)t change:(NSString *)change {
  [[NSNotificationCenter defaultCenter]
    postNotificationName:kLibraryTrackChanged
    object:self
    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
      t, @"track",
      change, @"change", nil]];
}

- (NSURL *)coverArtURL:(NSMutableDictionary *)t {
  return nil;
}

- (NSURL *)url:(id)trackID {
  return nil;
}

@end

