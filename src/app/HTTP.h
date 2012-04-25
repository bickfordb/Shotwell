#import "app/Loop.h"
#import "app/HTTPResponse.h"
#import "app/HTTPRequest.h"

struct evkeyvalq;

@interface Loop (HTTP)
- (bool)fetchRequest:(HTTPRequest *)request address:(NSString *)host port:(uint16_t)port with:(void (^)(HTTPResponse *response))onResponse;
- (bool)fetchURL:(NSURL *)url with:(void (^)(HTTPResponse *response))onResponse;
@end

NSMutableDictionary *FromEvKeyValQ(struct evkeyvalq *kv);

// vim: filetype=objcpp
