#import "app/Plugin.h"

@implementation Plugin


- (void)trackStarted:(Track *)track {
}

- (void)trackEnded:(Track *)track { 
}

- (void)trackSaved:(Track *)track {
}

- (void)trackAdded:(Track *)track {
}

- (void)trackDeleted:(Track *)track {
}

+ (NSString *)webScriptNameForKey:(const char *)name {
  return [NSString stringWithUTF8String:name];
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
  return NO;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
  return NO;
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector {
  NSString *s = NSStringFromSelector(aSelector);
  s = [s stringByReplacingOccurrencesOfString:@":" withString:@"_"];
  return s;
}
@end
