#import "app/PreferencesWindowController.h"

static NSString * const kPath = @"path";

@implementation PreferencesWindowController 
@synthesize automaticPathsTable = automaticPathsTable_;

- (id)init { 
  self = [super init];

  if (self) {
const int kSpace = 5;
  //CGSize windowSize = CGSizeMake(500, 600);
  CGSize buttonSize = CGSizeMake(25, 23);
  CGSize labelSize = CGSizeMake(480, 23);
  //CGSize scrollSize = CGSizeMake(windowSize.width - (10 * 2), windowSize.height - buttonSize.height - labelSize.height - 15);
  CGSize scrollSize = CGSizeMake(480, 300);
  CGSize windowSize = CGSizeMake(500, kSpace + scrollSize.height + kSpace + labelSize.height + kSpace + buttonSize.height + kSpace);

  CGRect addRect = CGRectMake(10, 10, buttonSize.width, buttonSize.height);
  CGRect removeRect = addRect;
  removeRect.origin.x += addRect.size.width;
  CGRect scrollRect = CGRectMake(10, buttonSize.height + removeRect.origin.y + 5, scrollSize.width, scrollSize.height);
  CGRect labelRect = CGRectMake(10, scrollRect.origin.y + scrollRect.size.height, labelSize.width, labelSize.height);
  CGRect windowRect = CGRectMake(100, 100, windowSize.width, windowSize.height);

  [self.window setFrame:windowRect display:YES];
  self.window.title = @"Preferences";
//  self.scanPathsTable = [[[TableView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)] autorelease];
//  self.scanPathsTable.allowsMultipleSelection = YES;
//  self.scanPathsTable.focusRingType = NSFocusRingTypeNone;
//  self.scanPathsTable.usesAlternatingRowBackgroundColors = YES;
//
//  NSTableColumn *pathColumn = [[[NSTableColumn alloc] initWithIdentifier:kPath] autorelease];
//  [pathColumn setWidth:480];
//  [[pathColumn headerCell] setStringValue:@"Path"];
//  [[pathColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
//  [[pathColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
//
//  [self.scanPathsTable addTableColumn:pathColumn];
//  [self.scanPathsTable setDelegate:self];
//  [self.scanPathsTable setDataSource:self];
//  [self.scanPathsTable setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
//  [self.scanPathsTable registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, NSFilenamesPboardType, nil]];
//  NSScrollView *sv = [[[NSScrollView alloc] initWithFrame:scrollRect] autorelease];
//  sv.focusRingType = NSFocusRingTypeNone;
//  sv.autoresizesSubviews = YES;
//  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
//  sv.borderType = NSBezelBorder;
//  [sv setHasVerticalScroller:YES];
//  [sv setHasHorizontalScroller:YES];
//  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
//  sv.focusRingType = NSFocusRingTypeNone;
//  [self.window.contentView addSubview:sv];
//  [sv setDocumentView:self.scanPathsTable]; 
//
//  NSTextField *label = [[[NSTextField alloc] initWithFrame:labelRect] autorelease];
//  label.stringValue = @"Watch these folders:";
//  label.font = [NSFont systemFontOfSize:12.0];
//  label.editable = NO;
//  label.selectable = NO;
//  label.bordered = NO;
//  label.bezeled = NO;
//  label.backgroundColor = [NSColor clearColor];
//  label.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
//  [[label cell] setBackgroundStyle:NSBackgroundStyleRaised];
//
//  [self.window.contentView addSubview:label];
//
//  CGRect buttonFrame = CGRectMake(10, sv.frame.origin.y - 32, 23, 25);
//  NSButton *addButton = [[[NSButton alloc] initWithFrame:addRect] autorelease];
//  addButton.image = [NSImage imageNamed:@"NSAddTemplate"];
//  addButton.buttonType = NSMomentaryPushInButton;
//  addButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
//  addButton.target = self;
//  addButton.action = @selector(addScanPath:);
//  addButton.bezelStyle = NSSmallSquareBezelStyle;
//  [self.window.contentView addSubview:addButton];
//
//  buttonFrame.origin.x += buttonFrame.size.width;
//  NSButton *removeButton = [[[NSButton alloc] initWithFrame:removeRect] autorelease];
//  removeButton.buttonType = NSMomentaryPushInButton;
//  removeButton.image = [NSImage imageNamed:@"NSRemoveTemplate"];
//  removeButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
//  removeButton.target = self;
//  removeButton.action = @selector(removeScanPath:);
//  removeButton.bezelStyle = NSSmallSquareBezelStyle;
//  [self.window.contentView addSubview:removeButton];
//  
//  NSToolbar  *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"PreferencesToolbar"] autorelease];
//  toolbar.delegate = self;
//  [self.window setToolbar:toolbar];
  }
  return self;
}

- (void)setupPreferencesWindow {
  
}

- (void)removeScanPath:(id)sender { 
//  NSIndexSet *iset = self.scanPathsTable.selectedRowIndexes;
//  if (!iset)
//    return;
//  NSMutableArray *newPaths = [NSMutableArray array];
//  NSArray *oldPaths = self.localLibrary.pathsToAutomaticallyScan;
//  if (oldPaths)
//    [newPaths addObjectsFromArray:oldPaths];
//  [newPaths removeObjectsAtIndexes:iset];
//  self.localLibrary.pathsToAutomaticallyScan = newPaths;
//  self.requestReloadPathsTable = true;
}

- (void)addScanPath:(id)sender { 
//  NSIndexSet *iset = self.scanPathsTable.selectedRowIndexes;
//  if (!iset)
//    return;
//// Create the File Open Dialog class.
//  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
//  [openPanel setCanChooseFiles:NO];
//  [openPanel setCanChooseDirectories:YES];
//  [openPanel setAllowsMultipleSelection:YES];
//  NSMutableArray *paths = [NSMutableArray array];
//  if ([openPanel runModal] == NSOKButton) {
//    for (NSURL *p in [openPanel URLs]) { 
//      [paths addObject:p.path];
//    }
//  }
//  [self.localLibrary scan:paths];
//  self.requestReloadPathsTable = true;
}

@end
