#import <Cocoa/Cocoa.h>
#include <jansson.h>

@interface NSObject (JSON) 
- (NSString *)getJSONEncodedString;
- (json_t *)getJSON;
@end

@interface NSString (JSON) 
- (id)decodeJSON;
@end

@interface NSData (JSON) 
- (id)decodeJSON;
@end

id FromJSONBytes(const char *js);
id FromJSON(json_t *);

// vim: filetype=objcpp
