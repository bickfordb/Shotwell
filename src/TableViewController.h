#import <Cocoa/Cocoa.h>
#import "Loop.h"
#import "TableView.h"
#import "ViewController.h"

typedef int (^TableViewControllerGetRowCount)(void);
typedef id (^TableViewControllerGetCellValue)(int row, NSTableColumn *column);
typedef void (^TableViewControllerDoubleAction)(int row);

@interface TableViewController : ViewController <NSTableViewDataSource, NSTableViewDelegate> {
  NSScrollView *scrollView_;
  TableView *tableView_;
  TableViewControllerDoubleAction onDoubleAction_;
  TableViewControllerGetCellValue onCellValue_;
  TableViewControllerGetRowCount onRowCount_;
  int seekToRow_;
  bool requestReload_;
  Loop *loop_;
}

@property (retain) TableView *tableView;
@property (retain) Loop *loop;
@property (retain) NSScrollView *scrollView;
@property (copy) TableViewControllerGetCellValue onCellValue;
@property (copy) TableViewControllerGetRowCount onRowCount;
@property (copy) TableViewControllerDoubleAction onDoubleAction;

- (void)seekTo:(int)row;
- (void)reload;
//- (void)updateTableColumnHeaders;
@end
// vim: filetype=objcpp
