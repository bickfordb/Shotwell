#import <Cocoa/Cocoa.h>

@interface NSNumber (Bits) 

- (NSNumber *)and:(uint32_t)bits;
- (NSNumber *)or:(uint32_t)bits;
@end

// vim: filetype=objcpp
