#import "NSURLAdditions.h"

@implementation NSURL (Additions)
- (NSURL *)pushKey:(NSString *)key value:(NSString *)value {

  key = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  value = [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  NSString *s = self.absoluteString;
  if ([s rangeOfString:@"?"].location == NSNotFound) {
    s = [s stringByAppendingFormat:@"?%@=%@", key, value];
  } else {
    s = [s stringByAppendingFormat:@"&%@=%@", key, value];
  }
  return [NSURL URLWithString:s];
}

@end
