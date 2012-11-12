#import <Cocoa/Cocoa.h>
#import "app/Types.h"

@class ViewController;
typedef void (^ViewControllerEvent)(ViewController *v);

@interface ViewController : NSResponder {
  NSView *view_;
  bool isBusy_;
  NSString *lastSearch_;
}

@property (retain) NSView *view;
@property bool isBusy;
@property (retain) NSString *lastSearch;

- (void)search:(NSString *)query after:(On0)block;
- (NSString *)lastSearch;
- (void)reload;
@end
// vim: filetype=objcpp
