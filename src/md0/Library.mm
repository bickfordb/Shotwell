#import "Library.h"

NSString * const TrackSavedLibraryNotification = @"TrackSavedLibraryNotification";
NSString * const TrackAddedLibraryNotification = @"TrackAddedLibraryNotification";
NSString * const TrackDeletedLibraryNotification = @"TrackDeletedLibraryNotification";

@implementation Library
@synthesize lastUpdatedAt = lastUpdatedAt_;
- (void)each:(void (^)(Track *t)) t { }; 
- (int)count { return 0; };
@end

