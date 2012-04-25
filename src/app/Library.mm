#import "app/Library.h"


@implementation Library
@synthesize lastUpdatedAt = lastUpdatedAt_;
@synthesize onAdded = onAdded_;
@synthesize onSaved = onSaved_;
@synthesize onDeleted = onDeleted_;

- (void)each:(void (^)(Track *t)) t { }; 
- (int)count { return 0; };
@end

