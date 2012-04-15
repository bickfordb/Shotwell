#import "md0/RTSPResponse.h"

@implementation RTSPResponse
@synthesize status = status_;
@synthesize body = body_;
@synthesize headers = headers_;

- (NSString *)description {
  NSMutableString *s = [NSMutableString string];
  NSString *body0 = [[[NSString alloc] initWithData:body_ encoding:NSUTF8StringEncoding] autorelease];
  [s appendFormat:@"<RTSPResponse status:%d, body:%@, headers:%@>", status_, body0, headers_];
  return s;
}
- (void)dealloc { 
  [headers_ release];
  [body_ release];
  [super dealloc];
}

- (id)init { 
  self = [super init];
  if (self) { 
    status_ = 0;
    self.headers = [NSMutableDictionary dictionary];
    self.body = [NSData data];
  }
  return self;
}
@end

