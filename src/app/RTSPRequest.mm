#import "app/RTSPRequest.h"

@implementation RTSPRequest
@synthesize method = method_;
@synthesize uri = uri_;
@synthesize body = body_;
@synthesize headers = headers_;

- (NSString *)description {
  NSMutableString *s = [NSMutableString string];
  NSString *body0 = [[[NSString alloc] initWithData:body_ encoding:NSUTF8StringEncoding] autorelease];
  [s appendFormat:@"<RTSPRequest method:%@, uri:%@, body:%@, headers:%@>", method_, uri_, body0, headers_];
  return s;
}

- (void)dealloc {
  [method_ release];
  [uri_ release];
  [body_ release];
  [headers_ release];
  [super dealloc];
}

- (id)init {
  self = [super init];
  if (self) {
    self.method = @"";
    self.uri = @"";
    self.body = [NSData data];
    self.headers = [NSMutableDictionary dictionary];
  }
  return self;
}

@end
