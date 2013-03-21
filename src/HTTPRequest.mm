#import "HTTPRequest.h"

@implementation HTTPRequest
@synthesize method = method_;
@synthesize uri = uri_;
@synthesize body = body_;
@synthesize headers = headers_;

- (id)init {
  self = [super init];
  if (self) {
    self.method = @"GET";
    self.uri = @"/";
    self.body = [NSData data];
    self.headers = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)dealloc {
  [method_ release];
  [body_ release];
  [headers_ release];
  [uri_ release];
  [super dealloc];
}
@end


