#import "app/NSScannerHTTP.h"

@implementation NSScanner (Headers)
- (BOOL)scanHeader:(NSString **)key value:(NSString **)value {
  NSString *k = nil;  
  BOOL ret = NO;
  if ([self scanUpToString:@":" intoString:&k]) { 
    *key = [k stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    int n = MIN(self.string.length, self.scanLocation + 2);
    NSString *v = [self.string substringFromIndex:n];
    *value = [v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    ret = YES;
  } else { 
    *key = nil;
    *value = nil;
  }
  return ret;
}

@end

