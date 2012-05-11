#import "app/Loop.h"
#import "app/PThread.h"
#import "app/TableViewController.h"

static int64_t kReloadInterval = 500000;

@implementation TableViewController 

@synthesize loop = loop_;
@synthesize onCellValue = onCellValue_;
@synthesize onDoubleAction = onDoubleAction_;
@synthesize onRowCount = onRowCount_;
@synthesize scrollView = scrollView_;
@synthesize tableView = tableView_;

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  return NO;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
  NSPasteboard *pasteboard = [info draggingPasteboard];
  NSArray *paths = [pasteboard propertyListForType:NSFilenamesPboardType];
  //[localLibrary_ scan:paths];
  return [paths count] ? YES : NO;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {  

  return operation;
}
- (id)init { 
  self = [super init];
  if (self) { 
    requestReload_ = false;
    self.loop = [Loop loop];
    self.tableView = [[[TableView alloc] init] autorelease];
    self.tableView.allowsMultipleSelection = YES;
    self.tableView.focusRingType = NSFocusRingTypeNone;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.delegate = self;
    self.tableView.target = self;
    self.tableView.doubleAction = @selector(doubleAction:);
    self.tableView.gridStyleMask = NSTableViewSolidVerticalGridLineMask;
    self.tableView.allowsMultipleSelection = YES;
    self.tableView.focusRingType = NSFocusRingTypeNone;
    self.tableView.allowsEmptySelection = NO;
    self.tableView.columnAutoresizingStyle = NSTableViewNoColumnAutoresizing;
    self.scrollView = [[[NSScrollView alloc] init] autorelease];
    self.scrollView.focusRingType = NSFocusRingTypeNone;
    self.scrollView.autoresizesSubviews = YES;
    self.scrollView.borderType = NSBezelBorder;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.scrollView.focusRingType = NSFocusRingTypeNone;
    CGRect frame = self.view.frame;
    frame.origin.x = 0;
    frame.origin.y = 0;
    self.scrollView.frame = frame;
    [self.view addSubview:self.scrollView];
    self.scrollView.documentView = self.tableView;
    [self.tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, NSFilenamesPboardType, nil]];
    self.tableView.dataSource = self;
    __block TableViewController *weakSelf = self;
    [loop_ every:kReloadInterval with:^{ 
      if (requestReload_) {
        weakSelf->requestReload_ = false;
        ForkToMainWith(^{
          [weakSelf.tableView reloadData];
        });
      }
    }];
  }
  return self;
}

- (void)doubleAction:(id)sender { 
  if (onDoubleAction_ && tableView_.clickedRow >= 0) {
    onDoubleAction_(tableView_.clickedRow);
  }
}

- (NSTableColumn *)appendColumn:(NSString *)name key:(NSString *)key {
  return nil;
}

- (void)dealloc {
  [loop_ release];
  [onCellValue_ release];
  [onDoubleAction_ release];
  [onRowCount_ release];
  [scrollView_ release];
  [tableView_ release];
  [super dealloc];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { 
  return self.onRowCount ? self.onRowCount() : 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  return onCellValue_ ? onCellValue_(rowIndex, aTableColumn) : nil;
}

- (void)reload { 
  requestReload_ = true;
}

- (void)seekTo:(int)row { 
  ForkToMainWith(^{
    [self.tableView scrollRowToVisible:row];
  });
}

@end
