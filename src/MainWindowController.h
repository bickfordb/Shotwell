#import <Cocoa/Cocoa.h>
#import "NavTable.h"
#import "ProgressControl.h"
#import "ServiceBrowser.h"
#import "ServicePopUpButton.h"
#import "SplitView.h"
#import "TableViewController.h"
#import "Track.h"
#import "TrackBrowser.h"
#import "VolumeControl.h"
#import "WindowController.h"

@interface MainWindowController : WindowController <NSToolbarDelegate>
- (void)setupMenu;

@property (retain) ViewController *content;
+ (MainWindowController *)shared;

@end
// vim: filetype=objcpp
