#import "md0/Loop.h"
#import "md0/HTTPResponse.h"
#import "md0/HTTPRequest.h"

@interface Loop (HTTP)
- (bool)fetchRequest:(HTTPRequest *)request address:(NSString *)host port:(uint16_t)port withBlock:(void (^)(HTTPResponse *response))onResponse;
- (bool)fetchURL:(NSURL *)url withBlock:(void (^)(HTTPResponse *response))onResponse;
@end
// vim: filetype=objcpp
