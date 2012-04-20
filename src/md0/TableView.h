#import <Cocoa/Cocoa.h>

typedef bool (^EventHandler)(NSEvent *);

@interface TableView : NSTableView {
  id onKeyDown_;
}

@property (copy) EventHandler onKeyDown;

@end

// vim: filetype=objcpp

