#import <Cocoa/Cocoa.h>


@interface NSString (Base64) 
- (NSData *)base64Decode;
@end

@interface NSData (Base64) 
- (NSString *)base64Encode;
@end
// vim: filetype=objcpp
