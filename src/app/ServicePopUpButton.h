#import <Cocoa/Cocoa.h>
#import "app/Loop.h"

typedef void (^ServicePopupButtonOnService)(id v);

@interface ServicePopUpButton : NSPopUpButton <NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
  NSMutableArray *services_;
  Loop *loop_;
  ServicePopupButtonOnService onService_;
  NSNetServiceBrowser *browser_;
}

@property (retain) NSMutableArray *services;
@property (retain) Loop *loop;
@property (copy) ServicePopupButtonOnService onService;
@property (retain) NSNetServiceBrowser *browser;

- (void)reload;
- (void)appendItemWithTitle:(NSString *)title value:(id)value;
- (id)initWithFrame:(CGRect)frame serviceTypes:(NSSet *)serviceTypes;

@end
// vim: filetype=objcpp

