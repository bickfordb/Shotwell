#import <Cocoa/Cocoa.h>
#import "app/Types.h"

@class ViewController;
typedef void (^ViewControllerEvent)(ViewController *v);

@interface ViewController : NSResponder {
  NSView *view_;
  bool isBusy_;
}

@property (retain) NSView *view;
@property bool isBusy;

- (void)search:(NSString *)query after:(On0)block;
- (void)reload;
@end
// vim: filetype=objcpp
