#import <Cocoa/Cocoa.h>
#import "app/WindowController.h"
#import "app/TableViewController.h"
#import "app/AutomaticPathsEditor.h"

@interface PreferencesWindowController : WindowController  <NSToolbarDelegate> {
  AutomaticPathsEditor *automaticPathsEditor_;
}
- (id)initWithLocalLibrary:(LocalLibrary *)localLibrary;
@property (retain) AutomaticPathsEditor *automaticPathsEditor;
@end
// vim: filetype=objcpp
