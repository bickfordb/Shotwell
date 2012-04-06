#import <Cocoa/Cocoa.h>

@interface NSObject (Pthread) 

- (void)runSelectorInThread:(SEL)selector;
@end
// vim: filetype=objcpp
