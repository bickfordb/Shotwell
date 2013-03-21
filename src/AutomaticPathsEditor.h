#import <Cocoa/Cocoa.h>
#import "TableViewController.h"
#import "LocalLibrary.h"

@interface AutomaticPathsEditor : ViewController {
  TableViewController *table_;
  LocalLibrary *localLibrary_;
}
@property (retain) TableViewController *table;
@property (retain) LocalLibrary *localLibrary;

- (id)initWithLocalLibrary:(LocalLibrary *)localLibrary;
@end
// vim: filetype=objcpp

