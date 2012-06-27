#import <Cocoa/Cocoa.h>
int base64_decode(const char *str, void *data);
int base64_encode(const void *data, int size, char **str);

@interface NSString (Base64)
- (NSData *)decodeBase64;
@end

@interface NSData (Base64)
- (NSString *)encodeBase64;
@end
// vim: filetype=objcpp
