#import <Cocoa/Cocoa.h>

NSData *ToJSONData(id obj);
NSString *ToJSON(id obj);

@interface NSObject (JSON)
- (NSString *)getJSONEncodedString;
@end

id FromJSONBytes(const char *js);
id FromJSONData(NSData *data);

// vim: filetype=objcpp
