#import "app/AutomaticPathsEditor.h"

static const int kSpace = 5;
static NSString * const kAutomaticPath = @"path";

@implementation AutomaticPathsEditor
@synthesize table = table_;
@synthesize localLibrary = localLibrary_;

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [table_ release];
  [localLibrary_ release];
  [super dealloc];
}

- (void)onScanPathsChange:(NSNotification *)notification {
  [self.table reload];
}

- (id)initWithLocalLibrary:(LocalLibrary *)localLibrary {
  self = [super init];
  if (self) {
    self.localLibrary = localLibrary;
    CGSize buttonSize = CGSizeMake(25, 23);
    CGSize labelSize = CGSizeMake(480, 23);
    CGSize tableSize = CGSizeMake(480, 300);
    CGSize contentSize = CGSizeMake(500, kSpace + tableSize.height + kSpace + labelSize.height + kSpace + buttonSize.height + kSpace);
    CGRect addRect = CGRectMake(10, 10, buttonSize.width, buttonSize.height);
    CGRect removeRect = addRect;
    removeRect.origin.x += addRect.size.width;
    CGRect tableRect = CGRectMake(10, buttonSize.height + removeRect.origin.y + 5, tableSize.width, tableSize.height);
    CGRect labelRect = CGRectMake(10, tableRect.origin.y + tableRect.size.height, labelSize.width, labelSize.height);
    CGRect contentRect = CGRectMake(0, 0, contentSize.width, contentSize.height);
    NSTableColumn *pathColumn = [[[NSTableColumn alloc] initWithIdentifier:kAutomaticPath] autorelease];
    [pathColumn setWidth:480];
    [[pathColumn headerCell] setStringValue:@"Path"];
    [[pathColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
    [[pathColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
    self.view.frame = contentRect;

    self.table = [[[TableViewController alloc] init] autorelease];
    self.table.view.frame = tableRect;
    self.table.view.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable | NSViewHeightSizable | NSViewMaxXMargin;
    self.table.tableView.columnAutoresizingStyle = NSTableViewFirstColumnOnlyAutoresizingStyle;
    [self.table.tableView addTableColumn:pathColumn];
    [self.table.tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, NSFilenamesPboardType, nil]];

    [self.view addSubview:self.table.view];
    self.table.view.nextResponder = self.table;
    self.table.nextResponder = self.view;

    NSTextField *label = [[[NSTextField alloc] initWithFrame:labelRect] autorelease];
    label.stringValue = @"Watch these folders:";
    label.font = [NSFont systemFontOfSize:12.0];
    label.editable = NO;
    label.selectable = NO;
    label.bordered = NO;
    label.bezeled = NO;
    label.backgroundColor = [NSColor clearColor];
    label.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
    [[label cell] setBackgroundStyle:NSBackgroundStyleRaised];
    [self.view addSubview:label];

    CGRect buttonFrame = CGRectMake(10, tableRect.origin.y - 32, 23, 25);
    NSButton *addButton = [[[NSButton alloc] initWithFrame:addRect] autorelease];
    addButton.image = [NSImage imageNamed:@"NSAddTemplate"];
    addButton.buttonType = NSMomentaryPushInButton;
    addButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    addButton.target = self;
    addButton.action = @selector(addScanPath:);
    addButton.bezelStyle = NSSmallSquareBezelStyle;
    [self.view addSubview:addButton];

    buttonFrame.origin.x += buttonFrame.size.width;
    NSButton *removeButton = [[[NSButton alloc] initWithFrame:removeRect] autorelease];
    removeButton.buttonType = NSMomentaryPushInButton;
    removeButton.image = [NSImage imageNamed:@"NSRemoveTemplate"];
    removeButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
    removeButton.target = self;
    removeButton.action = @selector(removeScanPath:);
    removeButton.bezelStyle = NSSmallSquareBezelStyle;
    [self.view addSubview:removeButton];

    self.table.onCellValue = ^(int row, NSTableColumn *tableColumn) {
      NSArray *items = self.localLibrary.pathsToAutomaticallyScan;
      return (row >= 0 && row < items.count) ? [items objectAtIndex:row] : nil;
    };
    self.table.onRowCount = ^{
      NSArray *items = self.localLibrary.pathsToAutomaticallyScan;
      return (int)items.count;
    };
    [[NSNotificationCenter defaultCenter]
      addObserver:self
      selector:@selector(onScanPathsChange:)
      name:kScanPathsChanged
      object:self.localLibrary];
    [self.table reload];
  }
  return self;
}

- (void)removeScanPath:(id)sender {
  NSIndexSet *iset = self.table.tableView.selectedRowIndexes;
  if (!iset)
    return;
  NSMutableArray *newPaths = [NSMutableArray array];
  NSArray *oldPaths = self.localLibrary.pathsToAutomaticallyScan;
  if (oldPaths)
    [newPaths addObjectsFromArray:oldPaths];
  [newPaths removeObjectsAtIndexes:iset];
  self.localLibrary.pathsToAutomaticallyScan = newPaths;
}

- (void)addScanPath:(id)sender {
  NSIndexSet *iset = self.table.tableView.selectedRowIndexes;
  if (!iset)
    return;
  // Create the File Open Dialog class.
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseFiles:NO];
  [openPanel setCanChooseDirectories:YES];
  [openPanel setAllowsMultipleSelection:YES];
  NSMutableArray *paths = [NSMutableArray array];
  if ([openPanel runModal] == NSOKButton) {
    for (NSURL *p in [openPanel URLs]) {
      [paths addObject:p.path];
    }
  }
  [self.localLibrary scan:paths];
}

@end

