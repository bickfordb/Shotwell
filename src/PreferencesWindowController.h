#import <Cocoa/Cocoa.h>
#import "WindowController.h"
#import "TableViewController.h"
#import "AutomaticPathsEditor.h"

@interface PreferencesWindowController : WindowController  <NSToolbarDelegate> {
  AutomaticPathsEditor *automaticPathsEditor_;
}
- (id)initWithLocalLibrary:(LocalLibrary *)localLibrary;
+ (PreferencesWindowController *)shared;
@property (retain) AutomaticPathsEditor *automaticPathsEditor;
@end
// vim: filetype=objcpp
