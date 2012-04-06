#import <Cocoa/Cocoa.h>
#include <jansson.h>

@interface NSObject (JSON) 
- (NSString *)getJSONEncodedString;
- (json_t *)getJSON;
@end

@interface NSString (JSON) 
- (NSArray *)decodeJSONArray;
- (NSDictionary *)decodeJSONObject;
@end

id FromJSONBytes(const char *js);

// vim: filetype=objcpp
