#include <locale>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/utsname.h>

#import "app/AppDelegate.h"
#import "app/Log.h"
#import "app/NSNetServiceAddress.h"
#import "app/NSNumberTimeFormat.h"
#import "app/NSMutableArrayInsert.h"
#import "app/NSStringDigest.h"
#import "app/Pthread.h"
#import "app/RAOP.h"
#import "app/RemoteLibrary.h"
#import "app/Signals.h"
#import "app/Util.h"
#import "app/WebPlugin.h"
#import "app/TableView.h"

static const int64_t kLibraryRefreshInterval = 2 * 1000000;
static NSSize kStartupSize = {1300, 650};
static NSString * const kDefaultWindowTitle = @"Mariposa";
static NSString * const kGeneralPreferenceTab = @"GeneralPreferenceTab";
static NSString * const kNextButton = @"NextButton";
static NSString * const kPath = @"Path";
static NSString * const kPlayButton = @"PlayButton";
static NSString * const kPreviousButton = @"PreviousButton";
static NSString * const kProgressControl = @"ProgressControl";
static NSString * const kRAOPServiceType = @"_raop._tcp.";
static NSString * const kSearchControl = @"SearchControl";
static NSString * const kStatus = @"status";
static NSString * const kVolumeControl = @"VolumeControl";
static  const int kBottomEdgeMargin = 25;
static NSString *LibraryDir();
static NSString *LibraryPath();

static NSPredicate *ParseSearchQuery(NSString *query);

static NSPredicate *ParseSearchQuery(NSString *query) {
  NSPredicate *ret = nil;
  if (query && query.length) {
    NSArray *tokens = [query 
      componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    for (NSString *token in tokens)  {
      if (token.length == 0)
        continue;
      NSPredicate *predicate = [NSPredicate 
        predicateWithFormat:
          @"(artist CONTAINS[cd] %@)"
          " OR (album CONTAINS[cd] %@)"
          " OR (title CONTAINS[cd] %@)"
          " OR (url CONTAINS[cd] %@)"
          " OR (year CONTAINS[cd] %@)"
          " OR (genre CONTAINS[cd] %@)",
        token, token, token, token, token, token, nil];
      if (!ret)
        ret = predicate;
      else
        ret = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray 
          arrayWithObjects:predicate, ret, nil]];
    }
  }
  return ret;
}

static NSString *LibraryDir() { 
  NSArray *paths = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory,
      NSUserDomainMask,
      YES);
  NSString *path = [paths objectAtIndex:0];
  path = [path stringByAppendingPathComponent:@"Mariposa"];
  mkdir(path.UTF8String, 0755);
  return path;
}

static NSString *LibraryPath() {
  return [LibraryDir() stringByAppendingPathComponent:@"library.db"];
}

static NSString *CoverArtPath() { 
  return [LibraryDir() stringByAppendingPathComponent:@"coverart.db"];
}

static NSString *GetWindowTitle(Track *t) { 
  NSString *title = t.title;
  NSString *artist = t.artist;
  NSString *album = t.album;
  NSString *url = t.url;

  if ([title length] && [artist length] && [album length])
    return [NSString stringWithFormat:@"%@ - %@ - %@ ", title, artist, album, nil];
  else if ([title length])
    return title;
  else if (url) 
    return url;
  else 
    return kDefaultWindowTitle;
}

@implementation AppDelegate
@synthesize addToLibraryMenuItem = addToLibraryMenuItem_;
@synthesize appleCoverArtClient = appleCoverArtClient_;
@synthesize audioOutputPopUp = audioOutputPopUp_;
@synthesize automaticallyScanPathsButton = automaticallyScanPathsButton_;
@synthesize contentHorizontalSplit = contentHorizontalSplit_;
@synthesize contentVerticalSplit = contentVerticalSplit_;
@synthesize contentView = contentView_;
@synthesize copyMenuItem = copyMenuItem_;
@synthesize cutMenuItem = cutMenuItem_;
@synthesize daemon = daemon_;
@synthesize deleteMenuItem = deleteMenuItem_;
@synthesize emptyImage = emptyImage_;
@synthesize libraryPopUp = libraryPopUp_;
@synthesize localLibrary = localLibrary_;
@synthesize mainWindow = mainWindow_;
@synthesize libraries = libraries_;
@synthesize daemonBrowser = daemonBrowser_;
@synthesize movie = movie_;
@synthesize needsLibraryRefresh = needsLibraryRefresh_;
@synthesize needsReload = needsReload_; 
@synthesize nextButton = nextButton_;
@synthesize nextButtonItem = nextButtonItem_;
@synthesize nextMenuItem = nextMenuItem_;
@synthesize pasteMenuItem = pasteMenuItem_;
@synthesize playButton = playButton_;
@synthesize playButtonItem = playButtonItem_;
@synthesize playImage = playImage_;
@synthesize playMenuItem = playMenuItem_;
@synthesize plugins = plugins_;
@synthesize pollLibraryTimer = pollLibraryTimer_;
@synthesize pollMovieTimer = pollMovieTimer_;
@synthesize predicateChanged = predicateChanged_;
@synthesize preferencesWindow = preferencesWindow_;
@synthesize prevMenuItem = prevMenuItem_;
@synthesize previousButton = previousButton_;
@synthesize previousButtonItem = previousButtonItem_;
@synthesize progressSliderItem = progressSliderItem_;
@synthesize progressControl = progressControl_;
@synthesize raopServiceBrowser = raopServiceBrowser_;
@synthesize audioOutputs = audioOutputs_;
@synthesize requestClearSelection = requestClearSelection_;
@synthesize requestNext = requestNext_;
@synthesize requestPlayTrackAtIndex = requestPlayTrackAtIndex_;
@synthesize requestPrevious = requestPrevious_;
@synthesize requestTogglePlay = requestTogglePlay_;
@synthesize scanPathsTable = scanPathsTable_;
@synthesize searchField = searchField_;
@synthesize searchItem = searchItem_;
@synthesize seekToRow = seekToRow_;
@synthesize selectAllMenuItem = selectAllMenuItem_;
@synthesize selectedAudioOutput = selectedAudioOutput_;
@synthesize selectedLibrary = selectedLibrary_;
@synthesize selectNoneMenuItem = selectNoneMenuItem_;
@synthesize sortFields = sortFields_;
@synthesize startImage = startImage_;
@synthesize statusBarText = statusBarText_;
@synthesize stopImage = stopImage_;
@synthesize stopMenuItem = stopMenuItem_;
@synthesize track = track_;
@synthesize trackEnded = trackEnded_;
@synthesize trackTableFont = trackTableFont_;
@synthesize trackTablePlayingFont = trackTablePlayingFont_;
@synthesize trackTableView = trackTableView_;
@synthesize tracks = tracks_;
@synthesize volumeControl = volumeControl_;
@synthesize volumeItem = volumeItem_;
@synthesize pollStatsTimer = pollStatsTimer_;
@synthesize artists = artists_;
@synthesize albums = albums_;
@synthesize requestReloadPathsTable = requestReloadPathsTable_;

- (void)dealloc { 
  self.appleCoverArtClient = nil;
  self.contentView = nil;
  self.mainWindow = nil;
  self.preferencesWindow = nil;
  self.progressControl = nil;
  self.trackTableView = nil;
  self.tracks = nil;
  [super dealloc];
}

- (void)search:(NSString *)term {
  self.searchField.stringValue = term;
  ForkWith(^{
    self.tracks.predicate = ParseSearchQuery(term);
    self.needsReload = true;
  });
}

- (void)setupMenu {
  NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
  NSMenuItem *editMenuItem = [mainMenu itemWithTitle:@"Edit"];
  NSMenuItem *formatMenuItem = [mainMenu itemWithTitle:@"Format"];
  NSMenuItem *viewMenuItem = [mainMenu itemWithTitle:@"View"];
  NSMenuItem *fileMenuItem = [mainMenu itemWithTitle:@"File"];
  [mainMenu removeItem:formatMenuItem];
  [mainMenu removeItem:viewMenuItem];
  NSMenu *fileMenu = [fileMenuItem submenu];
  [fileMenu removeAllItems];
  // Edit Menu:
  NSMenu *editMenu = [editMenuItem submenu];
  [editMenu removeAllItems];

  self.cutMenuItem = [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  self.cutMenuItem.target = self;
  self.copyMenuItem = [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  self.copyMenuItem.target = self;
  self.pasteMenuItem = [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  self.pasteMenuItem.target = self;
  self.deleteMenuItem = [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:[NSString stringWithFormat:@"%C", NSBackspaceCharacter]];
  [self.deleteMenuItem setKeyEquivalentModifierMask:0];
  self.deleteMenuItem.target = self;
  self.selectAllMenuItem = [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  self.selectAllMenuItem.target = trackTableView_;
  self.selectNoneMenuItem = [editMenu addItemWithTitle:@"Select None" action:@selector(selectNone:) keyEquivalent:@"A"];
  self.selectNoneMenuItem.target = trackTableView_;

  // File Menu
  self.addToLibraryMenuItem = [fileMenu addItemWithTitle:@"Add to Library" action:@selector(addToLibrary:) keyEquivalent:@"o"];
  self.addToLibraryMenuItem.target = self;

  NSMenuItem *appMenu = [mainMenu itemAtIndex:0];
  NSMenuItem *preferences = [appMenu.submenu 
    insertItemWithTitle:@"Preferences" action:@selector(onPreferences:) 
    keyEquivalent:@"," 
    atIndex:1];
  preferences.target = self;

  // Playback Menu

  NSMenuItem *playbackItem = [mainMenu insertItemWithTitle:@"Playback" action:nil keyEquivalent:@"" atIndex:3];
  playbackItem.submenu = [[[NSMenu alloc] initWithTitle:@"Playback"] autorelease];
  NSMenu *playbackMenu = playbackItem.submenu;

  NSMenuItem *playItem = [playbackMenu addItemWithTitle:@"Play" action:@selector(playClicked:) keyEquivalent:@" "];
  [playItem setKeyEquivalentModifierMask:0];
  NSString *leftArrow = [NSString stringWithFormat:@"%C", 0xF702];
  NSString *rightArrow = [NSString stringWithFormat:@"%C", 0xF703];
  NSMenuItem *previousItem = [playbackMenu addItemWithTitle:@"Previous" action:@selector(previousClicked:) keyEquivalent:leftArrow];
  NSMenuItem *nextItem = [playbackMenu addItemWithTitle:@"Next" action:@selector(nextClicked:) keyEquivalent:rightArrow];
}

- (void)onPreferences:(id)sender { 
  [self.preferencesWindow makeKeyAndOrderFront:sender];
};

- (void)addToLibrary:(id)sender { 
  // Create the File Open Dialog class.
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanChooseDirectories:YES];
  [openPanel setAllowsMultipleSelection:YES];

  NSMutableArray *paths = [NSMutableArray array];
  if ([openPanel runModal] == NSOKButton) {
    for (NSURL *p in [openPanel URLs]) { 
      [paths addObject:p.path];
    }
  }
  [localLibrary_ scan:paths];
}

- (void)delete:(id)sender { 
  if (library_ != localLibrary_)
    return;
  NSIndexSet *indices = [trackTableView_ selectedRowIndexes];
  ForkWith(^{
    [self cutTracksAtIndices:indices];  
  });
}

- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices { 
  NSArray *tracks = [self.tracks getMany:indices];
  for (Track *o in tracks) {
    [self.localLibrary delete:o];
    self.needsReload = true;
  }
  return tracks;
}

- (void)paste:(id)sender { 
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  NSArray *items = [pboard readObjectsForClasses:[NSArray arrayWithObjects:[NSURL class], nil]
    options:nil]; 
  NSMutableArray *paths = [NSMutableArray array];
  for (NSURL *u in items) {
    if (![u isFileURL]) {
      continue;
    }
    [paths addObject:u.path];
  }
  [localLibrary_ scan:paths];
  [pool release];
}

- (void)copy:(id)sender { 
  @synchronized(self) { 
    NSIndexSet *indices = [trackTableView_ selectedRowIndexes];
    NSUInteger i = [indices lastIndex];
    NSMutableArray *urls = [NSMutableArray array];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
    for (Track *t in [self.tracks getMany:indices]) {
      NSURL *url = [NSURL fileURLWithPath:t.url];
      [urls addObject:url];
      self.requestClearSelection = true;
    }
    [pb writeObjects:urls];
  }
}

- (void)cut:(id)sender { 
  if (library_ != localLibrary_)
    return;

  @synchronized(self) { 
    NSIndexSet *indices = [trackTableView_ selectedRowIndexes];
    NSUInteger i = [indices lastIndex];
    NSMutableArray *urls = [NSMutableArray array];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
    NSArray *tracks = [self cutTracksAtIndices:indices];
    NSArray *paths = [tracks valueForKey:kURL];

    for (NSString *i in paths) {
      [urls addObject:[NSURL fileURLWithPath:i]];
    }
    requestClearSelection_ = true;
    [pb writeObjects:urls];
  }
}
- (void)setupPreferencesWindow {
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

  self.preferencesWindow = [[[NSWindow alloc] 
    initWithContentRect:windowRect
    styleMask:NSClosableWindowMask | NSTitledWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask 
    backing:NSBackingStoreBuffered
    defer:YES] autorelease];
  self.preferencesWindow.releasedWhenClosed = NO;
  [self.preferencesWindow setAutorecalculatesKeyViewLoop:YES];


  self.preferencesWindow.title = @"Preferences";
  self.scanPathsTable = [[[TableView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)] autorelease];
  self.scanPathsTable.allowsMultipleSelection = YES;
  self.scanPathsTable.focusRingType = NSFocusRingTypeNone;
  self.scanPathsTable.usesAlternatingRowBackgroundColors = YES;

  NSTableColumn *pathColumn = [[[NSTableColumn alloc] initWithIdentifier:kPath] autorelease];
  [pathColumn setWidth:480];
  [[pathColumn headerCell] setStringValue:@"Path"];
  [[pathColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[pathColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];

  [self.scanPathsTable addTableColumn:pathColumn];
  [self.scanPathsTable setDelegate:self];
  [self.scanPathsTable setDataSource:self];
  [self.scanPathsTable setColumnAutoresizingStyle:NSTableViewFirstColumnOnlyAutoresizingStyle];
  [self.scanPathsTable registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, NSFilenamesPboardType, nil]];
  NSScrollView *sv = [[[NSScrollView alloc] initWithFrame:scrollRect] autorelease];
  sv.focusRingType = NSFocusRingTypeNone;
  sv.autoresizesSubviews = YES;
  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  sv.borderType = NSBezelBorder;
  [sv setHasVerticalScroller:YES];
  [sv setHasHorizontalScroller:YES];
  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  sv.focusRingType = NSFocusRingTypeNone;
  [self.preferencesWindow.contentView addSubview:sv];
  [sv setDocumentView:self.scanPathsTable]; 

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

  [self.preferencesWindow.contentView addSubview:label];

  CGRect buttonFrame = CGRectMake(10, sv.frame.origin.y - 32, 23, 25);
  NSButton *addButton = [[[NSButton alloc] initWithFrame:addRect] autorelease];
  addButton.image = [NSImage imageNamed:@"NSAddTemplate"];
  addButton.buttonType = NSMomentaryPushInButton;
  addButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
  addButton.target = self;
  addButton.action = @selector(addScanPath:);
  addButton.bezelStyle = NSSmallSquareBezelStyle;
  [self.preferencesWindow.contentView addSubview:addButton];

  buttonFrame.origin.x += buttonFrame.size.width;
  NSButton *removeButton = [[[NSButton alloc] initWithFrame:removeRect] autorelease];
  removeButton.buttonType = NSMomentaryPushInButton;
  removeButton.image = [NSImage imageNamed:@"NSRemoveTemplate"];
  removeButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
  removeButton.target = self;
  removeButton.action = @selector(removeScanPath:);
  removeButton.bezelStyle = NSSmallSquareBezelStyle;
  [self.preferencesWindow.contentView addSubview:removeButton];
  
  NSToolbar  *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"PreferencesToolbar"] autorelease];
  toolbar.delegate = self;
  [self.preferencesWindow setToolbar:toolbar];
}

- (void)removeScanPath:(id)sender { 
  NSIndexSet *iset = self.scanPathsTable.selectedRowIndexes;
  if (!iset)
    return;
  NSMutableArray *newPaths = [NSMutableArray array];
  NSArray *oldPaths = self.localLibrary.pathsToAutomaticallyScan;
  if (oldPaths)
    [newPaths addObjectsFromArray:oldPaths];
  [newPaths removeObjectsAtIndexes:iset];
  self.localLibrary.pathsToAutomaticallyScan = newPaths;
  self.requestReloadPathsTable = true;
}

- (void)addScanPath:(id)sender { 
  NSIndexSet *iset = self.scanPathsTable.selectedRowIndexes;
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
  self.requestReloadPathsTable = true;
}

- (void)setupWindow {
  self.mainWindow = [[[NSWindow alloc] 
    initWithContentRect:CGRectMake(50, 50, kStartupSize.width, kStartupSize.height)
    styleMask:NSClosableWindowMask | NSTitledWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask 
    backing:NSBackingStoreBuffered
    defer:YES] autorelease];
  [mainWindow_ setAutorecalculatesKeyViewLoop:YES];
  [mainWindow_ display];
  [mainWindow_ makeKeyAndOrderFront:self];
  contentView_ = [mainWindow_ contentView];
  contentView_.autoresizingMask = NSViewMinYMargin | NSViewHeightSizable;
  contentView_.autoresizesSubviews = YES;
  [mainWindow_ setAutorecalculatesContentBorderThickness:YES forEdge:NSMaxYEdge];
  [mainWindow_ setAutorecalculatesContentBorderThickness:YES forEdge:NSMinYEdge];
  [mainWindow_ setContentBorderThickness:kBottomEdgeMargin forEdge:NSMinYEdge];
  mainWindow_.title = kDefaultWindowTitle;
  NSRect splitRect = contentView_.frame;
  splitRect.origin.y += kBottomEdgeMargin;
  splitRect.size.height -= kBottomEdgeMargin;

  self.contentHorizontalSplit = [[[SplitView alloc] initWithFrame:splitRect] autorelease];
  [contentHorizontalSplit_ setDividerStyle:NSSplitViewDividerStyleThin];
  contentHorizontalSplit_.autoresizesSubviews = YES;
  contentHorizontalSplit_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  contentHorizontalSplit_.vertical = NO;
  contentHorizontalSplit_.focusRingType = NSFocusRingTypeNone;
  [contentView_ addSubview:contentHorizontalSplit_];

  self.contentVerticalSplit = [[[SplitView alloc] initWithFrame:splitRect] autorelease];
  [contentVerticalSplit_ setDividerStyle:NSSplitViewDividerStyleThin];
  contentVerticalSplit_.autoresizesSubviews = YES;
  contentVerticalSplit_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  contentVerticalSplit_.focusRingType = NSFocusRingTypeNone;
  contentVerticalSplit_.vertical = YES;
  contentVerticalSplit_.dividerColor = [NSColor blackColor];
  contentVerticalSplit_.dividerThickness = 1;
  [contentHorizontalSplit_ addSubview:contentVerticalSplit_];
}

- (void)setupStatusBarText { 
  CGRect frame;
  int windowWidth = ((NSView *)[mainWindow_ contentView]).bounds.size.width;
  int w = 300;
  int x = (windowWidth / 2.0) - (300.0 / 2.0) + 5.0;

  self.statusBarText = [[[NSTextField alloc] initWithFrame:CGRectMake(x, 3, w, 18)] autorelease];
  self.statusBarText.stringValue = @"booting up!";
  self.statusBarText.editable = NO;
  self.statusBarText.selectable = NO;
  self.statusBarText.bordered = NO;
  self.statusBarText.bezeled = NO;
  self.statusBarText.backgroundColor = [NSColor clearColor];
  self.statusBarText.autoresizingMask = NSViewWidthSizable;
  self.statusBarText.alignment = NSCenterTextAlignment;

  NSTextFieldCell *cell = (NSTextFieldCell *)[self.statusBarText cell];
  cell.font = [NSFont systemFontOfSize:11.0];
  cell.font = [NSFont systemFontOfSize:11.0];
  [cell setControlSize:NSSmallControlSize];
  [cell setBackgroundStyle:NSBackgroundStyleRaised];
  [[mainWindow_ contentView] addSubview:self.statusBarText];
}

- (void)setupAudioSelect { 
  int w = 160;
  int x = ((NSView *)[mainWindow_ contentView]).bounds.size.width;
  x -= w + 10;
  self.audioOutputPopUp = [[[NSPopUpButton alloc] initWithFrame:CGRectMake(x, 3, w, 18)] autorelease];
  audioOutputPopUp_.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
  [audioOutputPopUp_ setTarget:self];
  [audioOutputPopUp_ setAction:@selector(audioOutputSelected:)];
  NSButtonCell *buttonCell = (NSButtonCell *)[audioOutputPopUp_ cell];
  [buttonCell setFont:[NSFont systemFontOfSize:11.0]];
  [buttonCell setControlSize:NSSmallControlSize];

  [[mainWindow_ contentView] addSubview:audioOutputPopUp_];
  [self.audioOutputs addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
    @"Local Audio", @"title", nil]]; 
  self.selectedAudioOutput = [self.audioOutputs objectAtIndex:0];
  [self refreshAudioOutputList];
}

- (void)audioOutputSelected:(id)sender { 
  NSInteger i = [sender indexOfSelectedItem];
  NSMutableDictionary *output = nil;
  @synchronized(audioOutputs_) {
    if (i > 0 && i < audioOutputs_.count) {
      output = [audioOutputs_ objectAtIndex:i];
    }
  }
  if (output) {
    self.selectedAudioOutput = output;
    @synchronized (tracks_) {
      self.requestPlayTrackAtIndex = [tracks_ index:track_];
    }
  }
}

- (void)setupLibrarySelect { 
  int w = 160;
  int x = ((NSView *)[mainWindow_ contentView]).bounds.size.width;
  x -= w + 10;
  self.libraryPopUp = [[[NSPopUpButton alloc] initWithFrame:CGRectMake(5, 3, w, 18)] autorelease];
  libraryPopUp_.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
  NSButtonCell *buttonCell = (NSButtonCell *)[libraryPopUp_ cell];
  [buttonCell setFont:[NSFont systemFontOfSize:11.0]];
  [buttonCell setControlSize:NSSmallControlSize];
  [libraryPopUp_ setTarget:self];
  [libraryPopUp_ setAction:@selector(librarySelected:)];
  [[mainWindow_ contentView] addSubview:libraryPopUp_];
  [self.libraries addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys: 
    @"Local Library", @"title", 
    self.localLibrary, @"library", nil]];
  self.selectedLibrary = [self.libraries objectAtIndex:0];
  [self refreshLibraryList];
}

- (void)librarySelected:(id)sender { 
  DEBUG(@"library selected");
  int i = [sender indexOfSelectedItem];
  if (i >= 0 && i < self.libraries.count) {
    self.selectedLibrary = [self.libraries objectAtIndex:[sender indexOfSelectedItem]];
  }
  if (self.selectedLibrary) {
    self.library = [self.selectedLibrary objectForKey:@"library"];
  }
}

- (void)refreshAudioOutputList {
  [self.audioOutputPopUp removeAllItems];
  for (NSDictionary *d in self.audioOutputs) {
    [self.audioOutputPopUp addItemWithTitle:[d objectForKey:@"title"]];
  }
  int index = self.selectedAudioOutput ? 0 : [self.audioOutputs indexOfObject:self.selectedAudioOutput];
  if (index == NSNotFound)
    index = 0;
  [self.audioOutputPopUp selectItemAtIndex:index];
}

- (void)refreshLibraryList {
  [self.libraryPopUp removeAllItems];
  for (NSDictionary *d in self.libraries) {
    [self.libraryPopUp addItemWithTitle:[d objectForKey:@"title"]];
  }
  int index = self.selectedLibrary ? 0 : [self.libraries indexOfObject:self.selectedLibrary];
  if (index == NSNotFound)
    index = 0;
  [self.libraryPopUp selectItemAtIndex:index];
}

- (void)setupTrackTable {
  self.trackTableFont = [NSFont systemFontOfSize:11.0];
  self.trackTablePlayingFont = [NSFont boldSystemFontOfSize:11.0];
  NSScrollView *sv = [[[NSScrollView alloc] initWithFrame:CGRectMake(0, kBottomEdgeMargin, 
      contentView_.frame.size.width, contentView_.frame.size.height - kBottomEdgeMargin)] autorelease];
  sv.autoresizesSubviews = YES;
  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  sv.focusRingType = NSFocusRingTypeNone;
  self.trackTableView = [[[TableView alloc] initWithFrame:CGRectMake(0, 0, 364, 200)] autorelease];
  __block AppDelegate *weakSelf = self;
  self.trackTableView.onKeyDown = ^(NSEvent *e) {
    if (e.keyCode == 49) {
      [weakSelf playClicked:nil];
      return false;
    }
    return true;
  };
  NSMenu *tableMenu = [[[NSMenu alloc] initWithTitle:@"Track Menu"] autorelease];
  NSMenuItem *copy = [tableMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  NSMenuItem *cut = [tableMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"c"];
  NSMenuItem *delete_ = [tableMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
  self.trackTableView.menu = tableMenu;

  [trackTableView_ setUsesAlternatingRowBackgroundColors:YES];
  [trackTableView_ setGridStyleMask:NSTableViewSolidVerticalGridLineMask];
  [trackTableView_ setAllowsMultipleSelection:YES];
  trackTableView_.focusRingType = NSFocusRingTypeNone;

  NSTableColumn *statusColumn = [[[NSTableColumn alloc] initWithIdentifier:kStatus] autorelease];
  NSTableColumn *artistColumn = [[[NSTableColumn alloc] initWithIdentifier:kArtist] autorelease];
  NSTableColumn *albumColumn = [[[NSTableColumn alloc] initWithIdentifier:kAlbum] autorelease];
  NSTableColumn *titleColumn = [[[NSTableColumn alloc] initWithIdentifier:kTitle] autorelease];
  NSTableColumn *trackNumberColumn = [[[NSTableColumn alloc] initWithIdentifier:kTrackNumber] autorelease];
  NSTableColumn *genreColumn = [[[NSTableColumn alloc] initWithIdentifier:kGenre] autorelease];
  NSTableColumn *durationColumn = [[[NSTableColumn alloc] initWithIdentifier:kDuration] autorelease];
  NSTableColumn *yearColumn = [[[NSTableColumn alloc] initWithIdentifier:kYear] autorelease];
  NSTableColumn *pathColumn = [[[NSTableColumn alloc] initWithIdentifier:kURL] autorelease];

  self.emptyImage = [[[NSImage alloc] initWithSize:NSMakeSize(22, 22)] autorelease];
  self.playImage = [NSImage imageNamed:@"dot"];
  self.startImage = [NSImage imageNamed:@"start"];
  self.stopImage = [NSImage imageNamed:@"stop"];
  [statusColumn setDataCell:[[[NSImageCell alloc] initImageCell:emptyImage_] autorelease]];
  [statusColumn setDataCell:[[[NSImageCell alloc] initImageCell:emptyImage_] autorelease]];
  [statusColumn setWidth:30];
  [statusColumn setMaxWidth:30];
  [artistColumn setWidth:180];
  [albumColumn setWidth:180];
  [titleColumn setWidth:252];
  [trackNumberColumn setWidth:50];
  [genreColumn setWidth:150];
  [yearColumn setWidth:50];
  [durationColumn setWidth:50];
  [pathColumn setWidth:1000];

  [[statusColumn headerCell] setStringValue:@""];
  [[artistColumn headerCell] setStringValue:@"Artist"];
  [[artistColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[artistColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[albumColumn headerCell] setStringValue:@"Album"];
  [[albumColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[titleColumn headerCell] setStringValue:@"Title"];
  [[titleColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[yearColumn headerCell] setStringValue:@"Year"];
  [[yearColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[genreColumn headerCell] setStringValue:@"Genre"];
  [[genreColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[durationColumn headerCell] setStringValue:@"Duration"];
  [[durationColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[trackNumberColumn headerCell] setStringValue:@"#"];
  [[trackNumberColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];
  [[pathColumn headerCell] setStringValue:@"URL"];
  [[pathColumn headerCell] setFont:[NSFont boldSystemFontOfSize:11.0]];

  [[artistColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[albumColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[titleColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[genreColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[durationColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[yearColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[pathColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];
  [[trackNumberColumn dataCell] setFont:[NSFont systemFontOfSize:11.0]];

  [trackTableView_ addTableColumn:statusColumn];
  [trackTableView_ addTableColumn:trackNumberColumn];
  [trackTableView_ addTableColumn:titleColumn];
  [trackTableView_ addTableColumn:artistColumn];
  [trackTableView_ addTableColumn:albumColumn];
  [trackTableView_ addTableColumn:yearColumn];
  [trackTableView_ addTableColumn:durationColumn];
  [trackTableView_ addTableColumn:genreColumn];
  [trackTableView_ addTableColumn:pathColumn];
  [trackTableView_ setDelegate:self];
  [trackTableView_ setDataSource:self];
  [trackTableView_ reloadData];
  // embed the table view in the scroll view, and add the scroll view
  // to our window.
  [sv setHasVerticalScroller:YES];
  [sv setHasHorizontalScroller:YES];
  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  [trackTableView_ setDoubleAction:@selector(trackTableDoubleClicked:)];
  [trackTableView_ setTarget:self];
  [contentVerticalSplit_ addSubview:sv];
  [sv setDocumentView:trackTableView_];
  [trackTableView_ registerForDraggedTypes:[NSArray arrayWithObjects:NSURLPboardType, NSFilenamesPboardType, nil]];
}

- (void)setupToolbar { 
  // Setup the toolbar items and the toolbar.
  self.playButton = [[[NSButton alloc] initWithFrame:CGRectMake(0, 0, 40, 22)] autorelease];
  [playButton_ setTarget:self];
  [playButton_ setTitle:@""];
  [playButton_ setImage:startImage_];
  [playButton_ setBezelStyle:NSTexturedRoundedBezelStyle];

  [playButton_ setAction:@selector(playClicked:)];
  self.playButtonItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kPlayButton] autorelease];
  [playButtonItem_ setEnabled:YES];
  [playButtonItem_ setView:playButton_];

  self.nextButton = [[[NSButton alloc] initWithFrame:CGRectMake(0, 0, 40, 22)] autorelease];
  [nextButton_ setTarget:self];
  [nextButton_ setTitle:@""];
  [nextButton_ setImage:[NSImage imageNamed:@"right"]];
  [nextButton_ setAction:@selector(nextClicked:)];
  [nextButton_ setBezelStyle:NSTexturedRoundedBezelStyle];
  self.nextButtonItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kNextButton] autorelease];
  [nextButtonItem_ setEnabled:YES];
  [nextButtonItem_ setView:nextButton_];


  // Previous button
  self.previousButton = [[[NSButton alloc] initWithFrame:CGRectMake(0, 0, 40, 22)] autorelease];
  [previousButton_ setTarget:self];
  [previousButton_ setTitle:@""];
  [previousButton_ setBezelStyle:NSTexturedRoundedBezelStyle];
  [previousButton_ setImage:[NSImage imageNamed:@"left"]];
  [previousButton_ setAction:@selector(previousClicked:)];
  self.previousButtonItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kPreviousButton] autorelease];
  [previousButtonItem_ setEnabled:YES];
  [previousButtonItem_ setView:previousButton_];

  [[nextButton_ cell] setImageScaling:0.8];
  [[playButton_ cell] setImageScaling:0.8];
  [[previousButton_ cell] setImageScaling:0.8];

  // Volume
  self.volumeControl = [[[VolumeControl alloc] init] autorelease];
  __block AppDelegate *weakSelf = self;
  self.volumeControl.onVolume = ^(double amt) {
    if (weakSelf.movie) 
      [weakSelf.movie setVolume:amt];
  };
  self.volumeItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kVolumeControl] autorelease];
  [self.volumeItem setView:self.volumeControl.view];

  self.progressControl = [[[ProgressControl alloc]
    initWithFrame:CGRectMake(0, 0, 5 + 60 + 5 + 300 + 5 + + 60 + 5, 22)] autorelease];
  // Progress Bar

  self.progressControl.onElapsed = ^(int64_t amt) {
    [self.movie seek:amt];
  };

  self.progressSliderItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kProgressControl] autorelease];
  [progressSliderItem_ setEnabled:YES];
  [progressSliderItem_ setView:self.progressControl.view];
  [progressSliderItem_ setMaxSize:NSMakeSize(1000, 22)];
  [progressSliderItem_ setMinSize:NSMakeSize(400, 22)];

  self.searchField = [[[NSSearchField alloc] initWithFrame:CGRectMake(0, 0, 300, 22)] autorelease];
  self.searchField.font = [NSFont systemFontOfSize:12.0];
  self.searchField.autoresizingMask = NSViewMinXMargin;
  self.searchField.target = self;
  self.searchField.action = @selector(onSearch:);
  [self.searchField setRecentsAutosaveName:@"recentSearches"];

  self.searchItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kSearchControl] autorelease];
  [searchItem_ setView:self.searchField];

  NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"toolbar"] autorelease];
  [toolbar setDelegate:self];
  [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
  [toolbar insertItemWithItemIdentifier:kPlayButton atIndex:0];
  self.mainWindow.toolbar = toolbar;

}

- (void)setupDockIcon {
  [NSApp setApplicationIconImage:[NSImage imageNamed:@"dock"]];
}


- (void)parseDefaults { 
  [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
  __block AppDelegate *weakSelf = self;
  [self setupDockIcon];
  [self parseDefaults];
  self.audioOutputs = [NSMutableArray array];
  self.libraries = [NSMutableArray array];

  self.trackEnded = false;
  self.requestPrevious = false;
  self.requestTogglePlay = false;
  self.requestNext = false;
  self.needsLibraryRefresh = false;
  self.requestReloadPathsTable = true;
  self.tracks = [[[SortedSeq alloc] init] autorelease];
  self.appleCoverArtClient = [[[AppleCoverArtClient alloc] init] autorelease];
  self.localLibrary = [[[LocalLibrary alloc] initWithPath:LibraryPath()] autorelease];
  self.localLibrary.onScanPathsChange = ^{
    self.requestReloadPathsTable = true;  
    
  };
  
  self.library = self.localLibrary;
  self.movie = nil;
  self.track = nil;
  self.seekToRow = -1;
  self.needsReload = false;

  [self setupSharing];
  [self setupRAOP]; 

  [self.localLibrary prune];
  [self setupWindow];
  [self setupToolbar];
  [self setupTrackTable];
  [self setupAudioSelect];
  [self setupLibrarySelect];
  [self setupStatusBarText];
  [self setupMenu];
  [self setupPreferencesWindow];

  self.sortFields = [NSMutableArray array];

  for (NSString *key in [NSArray arrayWithObjects:kArtist, kAlbum, kTrackNumber, kTitle, kURL, nil]) { 
    SortField *s = [[[SortField alloc] initWithKey:key direction:Ascending comparator:NaturalComparison] autorelease];
    [sortFields_ addObject:s];
  }
  [self updateTableColumnHeaders];
  self.tracks.comparator = GetSortComparatorFromSortFields(self.sortFields);
  self.needsReload = true;

  self.requestPlayTrackAtIndex = -1;
  pollMovieTimer_ = [NSTimer timerWithTimeInterval:.15 target:self selector:@selector(onPollMovieTimer:) userInfo:nil repeats:YES];

  [[NSRunLoop mainRunLoop] addTimer:pollMovieTimer_ forMode:NSDefaultRunLoopMode];
  pollLibraryTimer_ = [NSTimer timerWithTimeInterval:10.0 target:self selector:@selector(onPollLibraryTimer:) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:pollLibraryTimer_ forMode:NSDefaultRunLoopMode];
  self.pollStatsTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(onPollStatsTimer:) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:self.pollStatsTimer forMode:NSDefaultRunLoopMode];
  [self setupPlugins];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

  [self.localLibrary checkITunesImport];
  [self.localLibrary checkAutomaticPaths];
}

- (void)onPollStatsTimer:(NSTimer *)timer { 
  NSMutableSet *artists = [NSMutableSet set];
  NSMutableSet *albums = [NSMutableSet set];

  for (Track *t in self.tracks.array) {
    if (t.artist)
      [artists addObject:t.artist];
    if (t.album) 
      [albums addObject:t.album];
  }
  self.artists = artists;
  self.albums = albums;
}

- (void)setupRAOP { 
  self.raopServiceBrowser = [[[NSNetServiceBrowser alloc] init] autorelease];
  [raopServiceBrowser_ setDelegate:self];
  [raopServiceBrowser_ searchForServicesOfType:kRAOPServiceType inDomain:@"local."];
}

- (void)setupSharing { 
  self.daemon = [[[Daemon alloc] 
    initWithHost:@"0.0.0.0" 
    port:kDaemonDefaultPort
    library:self.localLibrary] autorelease];
  self.daemonBrowser = [[[NSNetServiceBrowser alloc] init] autorelease];
  [self.daemonBrowser setDelegate:self];
  [self.daemonBrowser searchForServicesOfType:kDaemonServiceType inDomain:@"local."];
}

- (void)setupPlugins {
  self.plugins = [NSMutableArray array];
  NSString *resourceDir = [NSBundle mainBundle].resourcePath;
  NSString *pluginsDir = [resourceDir stringByAppendingPathComponent:@"Plugins"];
  NSArray *pluginDirs = GetSubDirectories([NSArray arrayWithObjects:pluginsDir, nil]);
  for (NSString *p in pluginDirs) {
    p = [p stringByAppendingPathComponent:@"index.html"];
    NSURL *u = [NSURL fileURLWithPath:p];
    WebPlugin *webPlugin = [[[WebPlugin alloc] initWithURL:u] autorelease];
    [plugins_ addObject:webPlugin]; 
  }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing {
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {  

  return operation;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
  NSPasteboard *pasteboard = [info draggingPasteboard];
  NSArray *paths = [pasteboard propertyListForType:NSFilenamesPboardType];
  [localLibrary_ scan:paths];
  return [paths count] ? YES : NO;
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
  [netService retain];
  [netService setDelegate:self];
  [netService resolveWithTimeout:10.0];
}

- (void)netServiceDidResolveAddress:(NSNetService *)netService {
  NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    netService, @"service", 
    netService.name, @"title", 
    nil]; 
  NSMutableArray *arr = nil;
  if ([netService.type isEqualToString:kRAOPServiceType]) {
    arr = self.audioOutputs;
  } else { 
    arr = self.libraries;
    RemoteLibrary *remoteLibrary = [[[RemoteLibrary alloc] initWithNetService:netService] autorelease];
    [d setObject:remoteLibrary forKey:@"library"];
  }  

  @synchronized(arr) {
    if (![arr containsObject:d]) {
      [arr addObject:d];
    }
  }
  [self refreshLibraryList];
  [self refreshAudioOutputList];
  [netService release];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSMutableDictionary *)errorDict {
}

- (NSComparator)getComparatorForKey:(NSString *)key { 
  if (key == kDuration)
    return DefaultComparison;
  else
    return NaturalComparison;   
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
  if (tableView != self.trackTableView)
    return;
  NSString *ident = tableColumn.identifier;
  if (!ident || ident == kStatus) { 
    return;
  }
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
    NSComparator comparator = [self getComparatorForKey:ident];
    if (found < 0) {
      SortField *s = [[[SortField alloc] 
        initWithKey:ident
        direction:Ascending
        comparator:comparator] autorelease];
      [sortFields_ insertObject:s atIndex:0];
    } else if (found > 0) {
      // Pop the field off a non-zero index, set the direction to ascending
      SortField *s = [[[SortField alloc] 
        initWithKey:ident
        direction:Ascending
        comparator:comparator] autorelease];
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
    self.tracks.comparator = GetSortComparatorFromSortFields(self.sortFields);
    self.needsReload = true;
  });
}

- (void)updateTableColumnHeaders {
  for (NSTableColumn *c in trackTableView_.tableColumns) { 
    [trackTableView_ setIndicatorImage:nil inTableColumn:c];
  }
  for (SortField *f in sortFields_) {
    Direction d = f.direction;
    NSImage *img = [NSImage imageNamed:d == Ascending ? @"NSAscendingSortIndicator" : @"NSDescendingSortIndicator"];
    [trackTableView_ setIndicatorImage:img inTableColumn:[trackTableView_ tableColumnWithIdentifier:f.key]];
    break;
  }
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
  NSToolbarItem *item;
  if (itemIdentifier == kPlayButton) { 
    item = playButtonItem_;  
  } else if (itemIdentifier == kProgressControl) { 
    item = progressSliderItem_;
  } else if (itemIdentifier == kVolumeControl) { 
    item = volumeItem_;
  } else if (itemIdentifier == kSearchControl) { 
    item = searchItem_;
  } else if (itemIdentifier == kPreviousButton) { 
    item = previousButtonItem_;
  } else if (itemIdentifier == kNextButton)  {
    item = nextButtonItem_;
  } else if (itemIdentifier == kGeneralPreferenceTab) { 
    item = [[[NSToolbarItem alloc] initWithItemIdentifier:kGeneralPreferenceTab] autorelease];
    item.label = @"General";
    item.enabled = true;
    item.target = self;
    item.action = @selector(generalSelected:);
    NSImageView *view = [[[NSImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)] autorelease];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view.image = [NSImage imageNamed:@"NSPreferencesGeneral"];
    item.view = view;
  }
  return item;
}

- (void)generalSelected:(id)sender { 
  
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
  return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar { 
  NSArray *ret = [NSArray array];
  if (toolbar == mainWindow_.toolbar)
    ret = [NSArray arrayWithObjects:kPreviousButton, kPlayButton, kNextButton, kVolumeControl, kProgressControl, kSearchControl, nil];
  else if (toolbar == preferencesWindow_.toolbar) 
    ret = [NSArray arrayWithObjects:kGeneralPreferenceTab, nil];
  return ret;     
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray array];
}

- (void)toolbarWillAddItem:(NSNotification *)notification {

}

- (void)toolbarWillRemoveItem:(NSNotification *)notification {
}

- (void)onSearch:(id)sender { 
  [self search:[sender stringValue]];
}

- (void)onPollMovieTimer:(id)sender { 

  if (self.requestReloadPathsTable) {
    [self.scanPathsTable reloadData];
    self.requestReloadPathsTable = false;
  }

  if (requestPlayTrackAtIndex_ >= 0) {
    [self playTrackAtIndex:requestPlayTrackAtIndex_];
    requestPlayTrackAtIndex_ = -1;
  }

  mainWindow_.title = GetWindowTitle(track_);
  int numTracks = 0;
  @synchronized (tracks_) {
    numTracks = tracks_.count;
  }
  self.statusBarText.stringValue = [NSString stringWithFormat:@"%d Tracks, %d Artists, %d Albums", numTracks, self.artists.count, self.albums.count]; 

  if (movie_ && ([movie_ state] == kEOFAudioSourceState)) {
    requestNext_ = true;
  }

  if (requestNext_) {
    [self playNextTrack];
    requestNext_ = false;
  }

  if (requestPrevious_) {
    [self playPreviousTrack];
    requestPrevious_ = false;
  }

  if (requestClearSelection_) { 
    [trackTableView_ deselectAll:self];
    requestClearSelection_ = false;
  }
  IgnoreSigPIPE();

  if (requestTogglePlay_) {
    @synchronized (self) {
      if (movie_) { 
        bool playing = movie_.state == kPlayingAudioSourceState;
        if (playing) { 
          [movie_ stop];
        } else { 
          [movie_ start]; 
        } 
      } else { 
        [self playNextTrack]; 
      } 
      requestTogglePlay_ = false; 
    } 
  }

  if (movie_) {
    if (!movie_.isSeeking) {
      self.progressControl.isEnabled = true;
      self.progressControl.duration = movie_.duration;
      self.progressControl.elapsed = movie_.elapsed;
    }
    if (movie_.state == kPlayingAudioSourceState)  {
      playButton_.image = stopImage_;
    } else {
      playButton_.image = startImage_;
    } 
  } else {
    self.progressControl.duration = 0;
    self.progressControl.elapsed = 0;
    self.progressControl.isEnabled = false;
    playButton_.image = startImage_;
  }

  if (self.needsLibraryRefresh) {
    [self.tracks clear];
    [library_ each:^(Track *t) {
        [self.tracks add:t];
    }];
    self.needsLibraryRefresh = false;
    self.needsReload = true;
  }
   
  if (self.needsReload) { 
    [self.trackTableView reloadData]; 
    self.needsReload = false;
  }

  if (self.seekToRow >= 0) { 
    [self.trackTableView scrollRowToVisible:seekToRow_];
    self.seekToRow = -1; 
  } 
}

- (Library *)library { 
  return library_;
}

- (void)setLibrary:(Library *)library { 
  __block AppDelegate *weakSelf = self;
  library.onAdded = ^(Library *l, Track *t) {
    [weakSelf library:l addedTrack:t];
  };
  library.onDeleted = ^(Library *l, Track *t) {
    [weakSelf library:l deletedTrack:t];
  };
  library.onSaved = ^(Library *l, Track *t) {
    [weakSelf library:l savedTrack:t];
  };
  @synchronized(self) {
    Library *o = library_;
    library_.onDeleted = nil;
    library_.onAdded = nil;
    library_.onSaved = nil;
    library_ = [library retain];
    [o autorelease];
  }
  self.needsLibraryRefresh = true;
};

- (void)library:(Library *)l addedTrack:(Track *)t {
  if (l != library_)
    return;
  [self.tracks add:t];
  self.needsReload = true;
}

- (void)library:(Library *)l savedTrack:(Track *)t {
  if (l != library_) {
    DEBUG(@"other library");
    return;
  }
  [self.tracks remove:t];
  [self.tracks add:t];
  self.needsReload = true;
  @synchronized (plugins_) {
    for (Plugin *p in plugins_) {
      [p trackSaved:t];
    }
  }
}

- (void)library:(Library *)l deletedTrack:(Track *)t {
  if (l != library_)
    return;
  [self.tracks remove:t];
  self.needsReload = true;
}

- (void)onPollLibraryTimer:(id)sender { 
  [raopServiceBrowser_ searchForServicesOfType:kRAOPServiceType inDomain:@"local."];
  [self.daemonBrowser searchForServicesOfType:kDaemonServiceType inDomain:@"local."]; 
}

- (void)trackTableDoubleClicked:(id)sender { 
  int row = [trackTableView_ clickedRow]; 
  requestPlayTrackAtIndex_ = row;
}

- (void)playTrackAtIndex:(int)index {
  if (movie_) {
    [movie_ stop];
    @synchronized (plugins_) {
      for (Plugin *p in plugins_) {
        [p trackEnded:track_];
      }
    }
  }
  self.track = [self.tracks get:index];
  NSNetService *netService = [self.selectedAudioOutput objectForKey:@"service"];

  self.movie = self.track ? [[[Movie alloc] initWithURL:self.track.url
    address:netService.ipv4Address port:netService.port] autorelease] : nil;
  self.movie.volume = self.volumeControl.level;
  [self.movie start];

  self.seekToRow = index;
  self.needsReload = true;
  if (self.track) {
    @synchronized(self.plugins) {
      for (Plugin *p in self.plugins) {
        [p trackStarted:track_];
      }
    }
  }
  // Load the cover art if it isn't loaded already.
  [self loadCoverArt:self.track];
}

- (void)loadCoverArt:(Track *)track {
  if (!track)
    return;
  if (track.coverArtURL && track.coverArtURL.length)
    return;
  if (!track.artist.length || !track.album.length) 
    return;
  NSString *term = [NSString stringWithFormat:@"%@ %@", track.artist, track.album];
  if (self.library != self.localLibrary) 
    return;

  [self.appleCoverArtClient search:term withArtworkData:^(NSData *data) { 
    if (!data || !data.length)
      return;
    NSString *covertArtDir = CoverArtPath();
    mkdir(covertArtDir.UTF8String, 0755);
    NSString *path = [covertArtDir stringByAppendingPathComponent:term.sha1];
    if (![data writeToFile:path atomically:YES]) {
      DEBUG(@"failed to write to %@", path);
      return;
    }
         
    NSString *url = [[NSURL fileURLWithPath:path] absoluteString];
    NSMutableArray *tracksToUpdate = [NSMutableArray array];
    for (Track *t in [self.tracks all]) {
      if ([t.artist isEqualToString:track.artist] 
          && [t.album isEqualToString:track.album] 
          && (!t.coverArtURL || !t.coverArtURL.length)) {
        [tracksToUpdate addObject:t];
      }
    }
    
    for (Track *t in tracksToUpdate) {
      t.coverArtURL = url;
      [localLibrary_ save:t];
    }
  }];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView { 
  if (aTableView == trackTableView_) {
    return self.tracks.count;
  } else { 
    return self.localLibrary.pathsToAutomaticallyScan.count;
  }
}

/*
 * Play the next track.
 */
- (void)playNextTrack { 
  int idx = 0;
  int found = -1;
  if (movie_) {
    for (Track *t in tracks_) {
      if ([t isEqual:track_]) {
        found = idx;
        break;
      }
      idx++;
    }
  } 
  requestPlayTrackAtIndex_ = found + 1;
}

- (void)playPreviousTrack { 
  int idx = 0;
  int found = -1;
  int req = 0;
  if (movie_) {
    for (Track *t in tracks_ ) {
      if ([t isEqual:track_]) {
        found = idx;
        break;
      }
      idx++;
    }
    if (found > 0) 
      req = found - 1;
  } 
  requestPlayTrackAtIndex_ = req;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
row:(NSInteger)rowIndex { 
  if (aTableView == trackTableView_)  {
    Track *t = [self.tracks get:rowIndex];;

    NSString *identifier = aTableColumn.identifier;
    id result = nil;
    NSString *s = nil;
    bool isPlaying = movie_ && [t isEqual:track_];
    if (identifier == kDuration) 
      s = [((NSNumber *)[t valueForKey:kDuration]) formatSeconds];
    else if (identifier == kStatus) {
      if (isPlaying) {
        result = playImage_;
        [[aTableColumn dataCell] setImageScaling:0.5];
      }
    } else if (identifier == kArtist
        || identifier == kAlbum
        || identifier == kGenre
        || identifier == kURL 
        || identifier == kTitle
        || identifier == kYear
        || identifier == kTrackNumber) {
      s = [t valueForKey:identifier];
    }
    if (s) {
      result = s;
      [[aTableColumn dataCell] setFont:isPlaying ? trackTablePlayingFont_ : trackTableFont_];
    } else { 

    }
    return result;
  } else { 
    NSArray *p = self.localLibrary.pathsToAutomaticallyScan;
    if (rowIndex >= 0 && rowIndex < p.count)
      return [self.localLibrary.pathsToAutomaticallyScan objectAtIndex:rowIndex];
    else
      return @"";
  }
}

- (void)playClicked:(id)sender { 
  DEBUG(@"play clicked");
  requestTogglePlay_ = true;
}

- (void)nextClicked:(id)sender { 
  DEBUG(@"next clicked");
  requestNext_ = true;
}

- (void)previousClicked:(id)sender { 
  DEBUG(@"previous clicked");
  requestPrevious_ = true;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  return NO;
}

// Make everything available via javascript:
+ (NSString *)webScriptNameForKey:(const char *)name {
  return [NSString stringWithUTF8String:name];
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
  return NO;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
  return NO;
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector {
  NSString *s = NSStringFromSelector(aSelector);
  s = [s stringByReplacingOccurrencesOfString:@":" withString:@"_"];
  return s;
}

@end

