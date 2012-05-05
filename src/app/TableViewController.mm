#import "app/TableViewController.h"
#import "app/PThread.h"

@implementation TableViewController 

@synthesize onCellValue = onCellValue_;
@synthesize onDoubleAction = onDoubleAction_;
@synthesize onRowCount = onRowCount_;
@synthesize onSortComparatorChanged = onSortComparatorChanged_;
@synthesize scrollView = scrollView_;
@synthesize sortFields = sortFields_;
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
    self.sortFields = [NSMutableArray array];
    self.tableView.dataSource = self;
  }
  return self;
}

- (void)doubleAction:(id)sender { 
  if (onDoubleAction_ && tableView_.clickedRow >= 0) {
    onDoubleAction_(tableView_.clickedRow);
  }
}
- (NSComparator)comparatorForKey:(NSString *)key {
  return DefaultComparison;
}

- (NSTableColumn *)appendColumn:(NSString *)name key:(NSString *)key {
  return nil;
}

- (void)dealloc {
  [onRowCount_ release];
  [onCellValue_ release];
  [tableView_ release];
  [scrollView_ release];
  [onDoubleAction_ release];
  [super dealloc];
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
  NSString *ident = tableColumn.identifier;
  @synchronized(sortFields_) { 
    int found = -1;
    int idx = 0;
    for (SortField *f in sortFields_) {
      if ([f.key isEqualToString:ident]) {
        found = idx; 
        break;
      }
      idx++;
    }
    if (found < 0) {
      SortField *s = [[[SortField alloc] 
        initWithKey:ident
        direction:Ascending
        comparator:[self comparatorForKey:ident]] autorelease];
      [sortFields_ insertObject:s atIndex:0];
    } else if (found > 0) {
      // Pop the field off a non-zero index, set the direction to ascending
      SortField *s = [[[SortField alloc] 
        initWithKey:ident
        direction:Ascending
        comparator:[self comparatorForKey:ident]] autorelease];
      [sortFields_ removeObjectAtIndex:found];
      [sortFields_ insertObject:s atIndex:0];
    } else { 
      SortField *s = [sortFields_ objectAtIndex:0];
      // Flip the direction
      s.direction = s.direction == Ascending ? Descending : Ascending;
    }
  }
  [self updateTableColumnHeaders];
  ForkWith(^{
    if (onSortComparatorChanged_) {
      onSortComparatorChanged_();
    }
  });
}



- (void)updateTableColumnHeaders {
  for (NSTableColumn *c in tableView_.tableColumns) { 
    [tableView_ setIndicatorImage:nil inTableColumn:c];
  }
  for (SortField *f in sortFields_) {
    Direction d = f.direction;
    NSImage *img = [NSImage imageNamed:d == Ascending ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator"];
    [tableView_ setIndicatorImage:img inTableColumn:[tableView_ tableColumnWithIdentifier:f.key]];
    break;
  }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { 
  return self.onRowCount ? self.onRowCount() : 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  return onCellValue_ ? onCellValue_(rowIndex, aTableColumn) : nil;
}

- (void)reload { 
  ForkToMainWith(^{
    [self.tableView reloadData];
  });
}

- (void)seekTo:(int)row { 
  ForkToMainWith(^{
    [self.tableView scrollRowToVisible:row];
  });
}

- (NSComparator)sortComparator {
  return GetSortComparatorFromSortFields(self.sortFields);
}
@end