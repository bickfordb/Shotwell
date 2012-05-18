#import <Cocoa/Cocoa.h>

@interface NSScanner (HTTP) 
- (BOOL)scanHeader:(NSString **)key value:(NSString **)value;
@end
