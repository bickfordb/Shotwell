#import <Cocoa/Cocoa.h>
#import "app/WindowController.h"
#import "app/TableViewController.h"
@interface PreferencesWindowController : WindowController {
  TableViewController *automaticPathsTable_;
}
@property (retain) TableViewController *automaticPathsTable;
@end
// vim: filetype=objcpp
