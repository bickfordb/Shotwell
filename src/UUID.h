#import <Cocoa/Cocoa.h>

@interface NSData (UUID)
+ (NSData *)randomUUIDLike;
- (NSString *)UUIDDescription;
- (NSString *)hex;

@end

