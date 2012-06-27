#import <Cocoa/Cocoa.h>
#import "app/TableViewController.h"
#import "app/LocalLibrary.h"

@interface AutomaticPathsEditor : ViewController {
  TableViewController *table_;
  LocalLibrary *localLibrary_;
}
@property (retain) TableViewController *table;
@property (retain) LocalLibrary *localLibrary;

- (id)initWithLocalLibrary:(LocalLibrary *)localLibrary;
@end
// vim: filetype=objcpp

