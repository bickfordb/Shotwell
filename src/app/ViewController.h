#import <Cocoa/Cocoa.h>

@class ViewController;
typedef void (^ViewControllerEvent)(ViewController *v);

@interface ViewController : NSResponder {
  NSView *view_;
}
@property (retain) NSView *view;
- (void)search:(NSString *)query;
- (void)reload;
@end
// vim: filetype=objcpp
