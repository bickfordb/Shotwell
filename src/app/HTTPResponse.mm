#import "app/HTTPResponse.h"

@implementation HTTPResponse
@synthesize status = status_;
@synthesize headers = headers_;
@synthesize body = body_;

- (id)init { 
  self = [super init];
  if (self) {
    self.status = 200;
    self.body = [NSData data];
    self.headers = [NSMutableDictionary dictionary];
  }
  return self;  
}

- (void)dealloc { 
  [body_ release];
  [headers_ release];
  [super dealloc];
}

@end
