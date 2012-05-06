#import <Cocoa/Cocoa.h>
#import "app/Loop.h"
#import "app/SortField.h"
#import "app/TableView.h"
#import "app/ViewController.h"

typedef int (^TableViewControllerGetRowCount)(void);
typedef id (^TableViewControllerGetCellValue)(int row, NSTableColumn *column);
typedef void (^TableViewControllerDoubleAction)(int row);
typedef void (^TableViewControllerSortComparatorChanged)();

@interface TableViewController : ViewController <NSTableViewDataSource, NSTableViewDelegate> {
  NSMutableArray *sortFields_;
  NSScrollView *scrollView_;
  TableView *tableView_;
  TableViewControllerDoubleAction onDoubleAction_;
  TableViewControllerGetCellValue onCellValue_;
  TableViewControllerGetRowCount onRowCount_;
  TableViewControllerSortComparatorChanged onSortComparatorChanged_;
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
@property (copy) TableViewControllerSortComparatorChanged onSortComparatorChanged;
@property (retain) NSMutableArray *sortFields;

- (void)seekTo:(int)row;
- (void)reload;
- (NSComparator)sortComparator;
- (NSComparator)comparatorForKey:(NSString *)key;
- (void)updateTableColumnHeaders;
@end
// vim: filetype=objcpp
