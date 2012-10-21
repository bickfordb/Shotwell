#import <Cocoa/Cocoa.h>
#import "app/Loop.h"

typedef void (^ServicePopupButtonOnService)(id v);

@interface ServicePopUpButton : NSPopUpButton {
  NSArray *outputs_;
  ServicePopupButtonOnService onService_;
}

@property (retain) NSArray *services;
@property (copy) ServicePopupButtonOnService onService;
@end
// vim: filetype=objcpp

