#import "NavTable.h"
#import "PThread.h"

NSString * const kNodeIsGroup = @"isGroup";
NSString * const kNodeChildren = @"children";
NSString * const kNodeTitle = @"title";
NSString * const kNodeTitleCell = @"titleCell";
NSString * const kNodeStatusCell = @"statusCell";
NSString * const kNodeStatus = @"status";
NSString * const kNodeOnSelect = @"onSelect";
NSString * const kNodeIsSelectable = @"isSelectable";

id NodeGet(NavNode *l, NSString *k) {
  return [l objectForKey:k];
}

void NodeSet(NavNode *l, NSString *k, id v) {
  [l setObject:v forKey:k];
}

void NodeAppend(NavNode *node, NavNode *r) {
  [NodeGet(node, kNodeChildren) addObject:r];
}

NSTextFieldCell *NodeTextCell() {
  NSTextFieldCell *cell = [[[NSTextFieldCell alloc] init] autorelease];
  cell.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
  return cell;
}

NSTextFieldCell *NodeImageTextCell(NSImage *image) {
  NSTextFieldCell *cell = [[[ImageAndTextCell alloc] init] autorelease];
  cell.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
  cell.image = image;
  return cell;
}

NavNode *NodeCreate() {
  NavNode *d = [NSMutableDictionary dictionary];
  NodeSet(d, kNodeChildren, [NSMutableArray array]);
  NodeSet(d, kNodeTitle, @"");
  NodeSet(d, kNodeStatus, @"");
  NodeSet(d, kNodeTitleCell, NodeTextCell());
  NodeSet(d, kNodeStatusCell, NodeTextCell());
  NodeSet(d, kNodeIsGroup, [NSNumber numberWithBool:NO]);
  return d;
}

@implementation NavTable
@synthesize outlineView = outlineView_;
@synthesize scrollView = scrollView;
@synthesize rootNode = rootNode_;

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.autoresizesSubviews = YES;
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.focusRingType = NSFocusRingTypeNone;
    self.scrollView = [[[NSScrollView alloc] initWithFrame:self.frame] autorelease];
    self.scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.scrollView.focusRingType = NSFocusRingTypeNone;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    [self addSubview:self.scrollView];
    self.outlineView = [[[NSOutlineView alloc] init] autorelease];
    self.outlineView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.outlineView.focusRingType = NSFocusRingTypeNone;
    self.outlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;

    self.outlineView.delegate = self;
    self.outlineView.dataSource = self;

    NSTableColumn *titleCol = [[[NSTableColumn alloc] initWithIdentifier:kNodeTitle] autorelease];
    titleCol.resizingMask = NSTableColumnAutoresizingMask;
    NSTableColumn *statusCol = [[[NSTableColumn alloc] initWithIdentifier:kNodeStatus] autorelease];
    statusCol.width = 32.0;
    statusCol.resizingMask = NSTableColumnNoResizing;
    titleCol.width = self.frame.size.width - 32;

    [self.outlineView addTableColumn:titleCol];
    [self.outlineView addTableColumn:statusCol];
    self.outlineView.outlineTableColumn = titleCol;
    self.outlineView.headerView = nil;

    self.scrollView.documentView = self.outlineView;
    self.rootNode = NodeCreate();
    [self.outlineView reloadData];
    [self.outlineView expandItem:nil];
  }
  return self;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
  id ret = nil;
  if (!item) {
    item = self.rootNode;
  }

  ret = [item valueForKey:tableColumn.identifier];
  //NSLog(@"object value: %@ => %@", item, ret);
  return ret;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
  if (!item) {
    item = self.rootNode;
  }
  NSMutableArray *children = [item valueForKey:kNodeChildren];
  int n = children ? children.count : 0;
  //NSLog(@"number of children: %@: %d", item, n);
  return n;
}

//- (NSRect)frameOfOutlineCellAtRow:(NSInteger)row {
//  return NSZeroRect;
//}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
  id ret = nil;
  if (!item) {
    item = self.rootNode;
  }
  if (item) {
    NSMutableArray *children = [item valueForKey:kNodeChildren];
    if (index >= 0 && index < children.count) {
      ret = [children objectAtIndex:index];
    }
  }
  return ret;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  if (!item) {
    item = self.rootNode;
  }
  return ((NSArray *)NodeGet(item, @"children")).count;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
  NSNumber *n = [item valueForKey:@"isGroup"];
  BOOL ret = n && n.boolValue;
  return ret;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
  return NodeGet(item, kNodeOnSelect) ? YES : NO;
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
  NSCell *ret = nil;
  if ([tableColumn.identifier isEqualToString:@"title"]) {
    ret = NodeGet(item, @"titleCell");
  } else if ([tableColumn.identifier isEqualToString:@"status"]) {
    ret = NodeGet(item, @"statusCell");
  }
  return ret;
}



- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification {
  int row = self.outlineView.selectedRow;
  if (row < 0)
    return;
  NavNode *item = [self.outlineView itemAtRow:row];
  if (!item) {
    return;
  }
  OnAction onClick = NodeGet(item, kNodeOnSelect);
  if (onClick) {
    onClick();
  }
}

- (void)reload {
  ForkToMainWith(^{
   [self.outlineView reloadData];
  });
}
@end
