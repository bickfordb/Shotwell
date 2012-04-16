#include <locale>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/utsname.h>

#import "md0/AppDelegate.h"
#import "md0/NSNetServiceAddress.h"
#import "md0/NSNumberTimeFormat.h"
#import "md0/NSStringDigest.h"
#import "md0/RAOP.h"
#import "md0/RemoteLibrary.h"
#import "md0/Util.h"
#import "md0/WebPlugin.h"

static const int64_t kLibraryRefreshInterval = 2 * 1000000;
static const int kDefaultPort = 6226;
static NSSize kStartupSize = {1100, 600};
static NSString * const kMD0ServiceType = @"_md0._tcp.";
static NSString * const kRAOPServiceType = @"_raop._tcp.";
static NSString * const kNextButton = @"NextButton";
static NSString * const kPlayButton = @"PlayButton";
static NSString * const kPreviousButton = @"PreviousButton";
static NSString * const kProgressControl = @"ProgressControl";
static NSString * const kSearchControl = @"SearchControl";
static NSString * const kStatus = @"status";
static NSString * const kDefaultWindowTitle = @"MD0";
static NSString * const kVolumeControl = @"VolumeControl";
static NSString * const kPathsToScan = @"PathsToScan";
static  const int kBottomEdgeMargin = 25;
static NSString * LibraryDir();
static NSString * LibraryPath();
static NSString *GetString(const string &s);

static NSString *LibraryDir() { 
  NSArray *paths = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory,
      NSUserDomainMask,
      YES);
  NSString *path = [paths objectAtIndex:0];
  path = [path stringByAppendingPathComponent:@"MD0"];
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
@synthesize allTracks = allTracks_;
@synthesize appleCoverArtClient = appleCoverArtClient_;
@synthesize audioOutputPopUp = audioOutputPopUp_;
@synthesize contentHorizontalSplit = contentHorizontalSplit_;
@synthesize contentVerticalSplit = contentVerticalSplit_;
@synthesize contentView = contentView_;
@synthesize copyMenuItem = copyMenuItem_;
@synthesize cutMenuItem = cutMenuItem_;
@synthesize daemon = daemon_;
@synthesize deleteMenuItem = deleteMenuItem_;
@synthesize durationText = durationText_;
@synthesize elapsedText = elapsedText_;
@synthesize emptyImage = emptyImage_;
@synthesize lastLibraryRefresh = lastLibraryRefresh_;
@synthesize library = library_;
@synthesize libraryPopUp = libraryPopUp_;
@synthesize localLibrary = localLibrary_;
@synthesize mainWindow = mainWindow_;
@synthesize libraries = libraries_;
@synthesize mdServiceBrowser = mdServiceBrowser_;
@synthesize movie = movie_;
@synthesize needsLibraryRefresh = needsLibraryRefresh_;
@synthesize needsReload = needsReload_; 
@synthesize netService = netService_;
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
@synthesize prevMenuItem = prevMenuItem_;
@synthesize previousButton = previousButton_;
@synthesize previousButtonItem = previousButtonItem_;
@synthesize progressSlider = progressSlider_;
@synthesize progressSliderItem = progressSliderItem_;
@synthesize raopServiceBrowser = raopServiceBrowser_;
@synthesize audioOutputs = audioOutputs_;
@synthesize requestClearSelection = requestClearSelection_;
@synthesize requestNext = requestNext_;
@synthesize requestPlayTrackAtIndex = requestPlayTrackAtIndex_;
@synthesize requestPrevious = requestPrevious_;
@synthesize requestTogglePlay = requestTogglePlay_;
@synthesize searchField = searchField_;
@synthesize searchItem = searchItem_;
@synthesize searchQuery = searchQuery_;
@synthesize seekToRow = seekToRow_;
@synthesize selectAllMenuItem = selectAllMenuItem_;
@synthesize selectedAudioOutput = selectedAudioOutput_;
@synthesize selectedLibrary = selectedLibrary_;
@synthesize selectNoneMenuItem = selectNoneMenuItem_;
@synthesize sortChanged = sortChanged_;
@synthesize sortFields = sortFields_;
@synthesize startImage = startImage_;
@synthesize stopImage = stopImage_;
@synthesize stopMenuItem = stopMenuItem_;
@synthesize toolbar = toolbar_;
@synthesize track = track_;
@synthesize trackEnded = trackEnded_;
@synthesize trackTableFont = trackTableFont_;
@synthesize trackTablePlayingFont = trackTablePlayingFont_;
@synthesize trackTableScrollView = trackTableScrollView_;
@synthesize trackTableView = trackTableView_;
@synthesize tracks = tracks_;
@synthesize volumeControl = volumeControl_;
@synthesize volumeItem = volumeItem_;
@synthesize volumeSlider = volumeSlider_;

- (void)dealloc { 
  self.tracks = nil;
  self.allTracks = nil;
  self.appleCoverArtClient = nil;
  self.contentView = nil;
  self.mainWindow = nil;
  [super dealloc];
}

- (void)search:(NSString *)term {
  self.searchField.stringValue = term;
  self.searchQuery = term;
  self.predicateChanged = YES;
  self.needsReload = YES;
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
  NSMenu *editMenu = [editMenuItem submenu];
  [editMenu removeAllItems];

  self.selectAllMenuItem = [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  self.selectAllMenuItem.target = trackTableView_;
  self.selectNoneMenuItem = [editMenu addItemWithTitle:@"Select None" action:@selector(selectNone:) keyEquivalent:@"A"];
  self.selectNoneMenuItem.target = trackTableView_;
  self.addToLibraryMenuItem = [fileMenu addItemWithTitle:@"Add to Library" action:@selector(addToLibrary:) keyEquivalent:@"o"];
  self.addToLibraryMenuItem.target = self;
  self.cutMenuItem = [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  self.cutMenuItem.target = self;
  self.copyMenuItem = [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  self.copyMenuItem.target = self;
  self.deleteMenuItem = [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:[NSString stringWithFormat:@"%C", NSBackspaceCharacter]];
  [self.deleteMenuItem setKeyEquivalentModifierMask:0];
  self.deleteMenuItem.target = self;
  self.pasteMenuItem = [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  self.pasteMenuItem.target = self;
}

- (void)addToLibrary:(id)sender { 
  // Create the File Open Dialog class.
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanChooseDirectories:YES];
  NSMutableArray *paths = [NSMutableArray array];
  if ([openPanel runModal] == NSOKButton) {
    for (NSURL *p in [openPanel URLs]) { 
      [paths addObject:[p path]];
    }
  }
  [localLibrary_ scan:paths];
}

- (void)delete:(id)sender { 
  if (library_ != localLibrary_)
    return;
  NSIndexSet *indices = [trackTableView_ selectedRowIndexes];
  [self cutTracksAtIndices:indices];  
}

- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices { 
  NSArray *tracks = [NSArray array];
  @synchronized (tracks_) {
    tracks = [tracks_ objectsAtIndexes:indices];
    [tracks_ removeObjectsAtIndexes:indices];
  }
  @synchronized(allTracks_) {
    [allTracks_ removeObjectsInArray:tracks_];
  }
  for (Track *o in allTracks_) {
    [localLibrary_ delete:o];
    needsReload_ = YES;
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
    while (i != NSNotFound) {
      if (i >= [tracks_ count])
        continue;
      Track *t = [tracks_ objectAtIndex:i];
      NSURL *url = [NSURL fileURLWithPath:t.url];
      [urls addObject:url];
      i = [indices indexLessThanIndex:i];
      requestClearSelection_ = YES;
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
    requestClearSelection_ = YES;
    [pb writeObjects:urls];
  }
}
- (void)setupWindow {
  self.mainWindow = [[[NSWindow alloc] 
    initWithContentRect:CGRectMake(150, 150, kStartupSize.width, kStartupSize.height)
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
      self.requestPlayTrackAtIndex = [tracks_ indexOfObject:track_];
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
  NSLog(@"library selected");
  int i = [sender indexOfSelectedItem];
  if (i >= 0 && i < self.libraries.count) {
    self.selectedLibrary = [self.libraries objectAtIndex:[sender indexOfSelectedItem]];
  }
  if (self.selectedLibrary) {
    self.library = [self.selectedLibrary objectForKey:@"library"];
    self.needsLibraryRefresh = YES;
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
  self.trackTableScrollView = [[[NSScrollView alloc] initWithFrame:CGRectMake(0, kBottomEdgeMargin, 
      contentView_.frame.size.width, contentView_.frame.size.height - kBottomEdgeMargin)] autorelease];
  trackTableScrollView_.autoresizesSubviews = YES;
  trackTableScrollView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  trackTableScrollView_.focusRingType = NSFocusRingTypeNone;
  trackTableView_ = [[NSTableView alloc] initWithFrame:CGRectMake(0, 0, 364, 200)];
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
  [trackTableScrollView_ setHasVerticalScroller:YES];
  [trackTableScrollView_ setHasHorizontalScroller:YES];
  trackTableScrollView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  [trackTableView_ setDoubleAction:@selector(trackTableDoubleClicked:)];
  [trackTableView_ setTarget:self];
  [contentVerticalSplit_ addSubview:trackTableScrollView_];
  [trackTableScrollView_ setDocumentView:trackTableView_];
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
  self.volumeSlider = [[[Slider alloc] initWithFrame:CGRectMake(0, 0, 100, 22)] autorelease];
  [volumeSlider_ setContinuous:YES];
  [volumeSlider_ setTarget:self];
  [volumeSlider_ setAction:@selector(volumeClicked:)];
  volumeSlider_.autoresizingMask = 0;
  [[volumeSlider_ cell] setControlSize: NSSmallControlSize];
  [volumeSlider_ setMaxValue:1.0];
  [volumeSlider_ setMinValue:0.0];
  [volumeSlider_ setDoubleValue:0.5];
  self.volumeItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kVolumeControl] autorelease];
  [volumeItem_ setView:volumeSlider_];

  NSView *progressControl = [[[NSView alloc] 
    initWithFrame:CGRectMake(0, 0, 5 + 60 + 5 + 300 + 5 + + 60 + 5, 22)] autorelease];
  // Progress Bar
  self.progressSlider = [[[Slider alloc] initWithFrame:CGRectMake(5 + 60 + 5, 0, 300, 22)] autorelease];
  [progressSlider_ setContinuous:YES];
  [progressSlider_ setTarget:self];
  [progressSlider_ setAction:@selector(progressClicked:)];
  progressSlider_.autoresizingMask = NSViewWidthSizable;
  [[progressSlider_ cell] setControlSize: NSSmallControlSize];
  [progressSlider_ setMaxValue:1.0];
  [progressSlider_ setMinValue:0.0];
  [progressSlider_ setDoubleValue:0.0];

  self.elapsedText = [[[NSTextField alloc] initWithFrame:CGRectMake(5, 3, 60, 15)] autorelease];
  elapsedText_.font = [NSFont systemFontOfSize:9.0];
  elapsedText_.stringValue = @"";
  elapsedText_.autoresizingMask = NSViewMaxXMargin;
  elapsedText_.alignment = NSRightTextAlignment;
  [elapsedText_ setDrawsBackground: NO];
  [elapsedText_ setEditable: NO];
  [elapsedText_ setBordered:NO];
  [progressControl addSubview:elapsedText_];

  self.durationText = [[[NSTextField alloc] initWithFrame:CGRectMake(5 + 60 + 5 + 300 + 5, 3, 60, 15)] autorelease];
  durationText_.font = [NSFont systemFontOfSize:9.0];
  durationText_.stringValue = @"";
  durationText_.autoresizingMask = NSViewMinXMargin;
  durationText_.alignment = NSLeftTextAlignment;
  [durationText_ setDrawsBackground: NO];
  [durationText_ setBordered:NO];
  [durationText_ setEditable: NO];
  [progressControl addSubview:durationText_];

  [progressControl addSubview:progressSlider_];
  progressControl.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  self.progressSliderItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kProgressControl] autorelease];
  [progressSliderItem_ setEnabled:YES];
  [progressSliderItem_ setView:progressControl];

  [[NSNotificationCenter defaultCenter] 
    addObserver:self selector:@selector(progressSliderIsUp:) name:kSliderIsUpNotification object:progressSlider_];

  [progressSliderItem_ setMaxSize:NSMakeSize(1000, 22)];
  [progressSliderItem_ setMinSize:NSMakeSize(400, 22)];

  self.searchField = [[[NSSearchField alloc] initWithFrame:CGRectMake(0, 0, 100, 22)] autorelease];
  searchField_.font = [NSFont systemFontOfSize:12.0];
  searchField_.autoresizingMask = NSViewMinXMargin;
  searchField_.target = self;
  searchField_.action = @selector(onSearch:);

  [searchField_ setRecentsAutosaveName:@"recentSearches"];

  self.searchItem = [[[NSToolbarItem alloc] initWithItemIdentifier:kSearchControl] autorelease];
  [searchItem_ setView:searchField_];

  self.toolbar = [[[NSToolbar alloc] initWithIdentifier:@"md0toolbar"] autorelease];
  [toolbar_ setDelegate:self];
  [toolbar_ setDisplayMode:NSToolbarDisplayModeIconOnly];
  [toolbar_ insertItemWithItemIdentifier:kPlayButton atIndex:0];
  [mainWindow_ setToolbar:toolbar_];
}

- (void)setupDockIcon {
  [NSApp setApplicationIconImage:[NSImage imageNamed:@"md0dock"]];
}

- (void)onTrackDeleted:(NSNotification *)notification {
  Track *t = [notification.userInfo objectForKey:@"track"];
  @synchronized (plugins_) {
    for (Plugin *p in plugins_) {
      [p trackDeleted:t];
    }
  }
}

- (void)onTrackAdded:(NSNotification *)notification {
  Track *t = [notification.userInfo objectForKey:@"track"];
  @synchronized (plugins_) {
    for (Plugin *p in plugins_) {
      [p trackAdded:t];
    }
  }
}

- (void)onTrackSaved:(NSNotification *)notification {
  Track *t = [notification.userInfo objectForKey:@"track"];
  @synchronized (plugins_) {
    for (Plugin *p in plugins_) {
      [p trackSaved:t];
    }
  }
}

- (NSArray *)pathsToAutomaticallyScan {
  return [[NSUserDefaults standardUserDefaults] arrayForKey:kPathsToScan];
}

- (void)setPathsToAutomaticallyScan:(NSArray *)paths {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  [d setObject:paths forKey:kPathsToScan];
  [d synchronize];
}

- (void)parseDefaults { 
  [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
  [self setupDockIcon];
  [self parseDefaults];
  self.audioOutputs = [NSMutableArray array];
  self.libraries = [NSMutableArray array];

  [[NSNotificationCenter defaultCenter]
    addObserver:self selector:@selector(onTrackSaved:) name:TrackSavedLibraryNotification object:nil];
  [[NSNotificationCenter defaultCenter]
    addObserver:self selector:@selector(onTrackAdded:) name:TrackAddedLibraryNotification object:nil];
  [[NSNotificationCenter defaultCenter]
    addObserver:self selector:@selector(onTrackDeleted:) name:TrackDeletedLibraryNotification object:nil];

  trackEnded_ = NO;
  requestPrevious_ = NO;
  requestTogglePlay_ = NO;
  requestNext_ = NO;
  needsLibraryRefresh_ = NO;
  self.tracks = [NSMutableArray array];
  self.appleCoverArtClient = [[[AppleCoverArtClient alloc] init] autorelease];
  self.allTracks = [NSMutableArray array];
  self.localLibrary = [[[LocalLibrary alloc] initWithPath:LibraryPath()] autorelease];
  self.library = self.localLibrary;
  self.movie = nil;
  self.track = nil;
  self.seekToRow = -1;
  self.needsReload = NO;
  self.lastLibraryRefresh = 0;

  [self setupSharing];
  [self setupRAOP]; 

  [self.localLibrary prune];
  [self setupWindow];
  [self setupToolbar];
  [self setupTrackTable];
  [self setupAudioSelect];
  [self setupLibrarySelect];
  [self setupMenu];

  self.sortFields = [NSMutableArray array];

  for (NSString *key in [NSArray arrayWithObjects:kArtist, kAlbum, kTrackNumber, kTitle, kURL, nil]) { 
    SortField *s = [[[SortField alloc] initWithKey:key direction:Ascending comparator:NaturalComparison] autorelease];
    [sortFields_ addObject:s];
  }
  [self updateTableColumnHeaders];
  predicateChanged_ = YES;
  sortChanged_ = YES;

  requestPlayTrackAtIndex_ = -1;
  pollMovieTimer_ = [NSTimer timerWithTimeInterval:.15 target:self selector:@selector(onPollMovieTimer:) userInfo:nil repeats:YES];

  [[NSRunLoop mainRunLoop] addTimer:pollMovieTimer_ forMode:NSDefaultRunLoopMode];
  pollLibraryTimer_ = [NSTimer timerWithTimeInterval:10.0 target:self selector:@selector(onPollLibraryTimer:) userInfo:nil repeats:YES];
  [[NSRunLoop mainRunLoop] addTimer:pollLibraryTimer_ forMode:NSDefaultRunLoopMode];
  [self setupPlugins];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

  //[self.localLibrary scan:self.pathsToAutomaticallyScan];
}

- (void)setupRAOP { 
  self.raopServiceBrowser = [[[NSNetServiceBrowser alloc] init] autorelease];
  [raopServiceBrowser_ setDelegate:self];
  [raopServiceBrowser_ searchForServicesOfType:kRAOPServiceType inDomain:@"local."];
}

- (void)setupSharing { 
  self.daemon = [[[Daemon alloc] initWithHost:@"0.0.0.0" port:kDefaultPort
    library:self.localLibrary] autorelease];

  struct utsname the_utsname;
  uname(&the_utsname);
  NSString *nodeName = [NSString stringWithUTF8String:the_utsname.nodename];
  self.netService = [[[NSNetService alloc] 
    initWithDomain:@"local."
    type:kMD0ServiceType
    name:nodeName 
    port:kDefaultPort] autorelease];
  [netService_ publish];
  [netService_ scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  mdServiceBrowser_ = [[NSNetServiceBrowser alloc] init];
  [mdServiceBrowser_ setDelegate:self];
  [mdServiceBrowser_ searchForServicesOfType:kMD0ServiceType inDomain:@"local."];


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
  
  for (NSString *p in paths) {
    struct stat status;
    if (stat(p.UTF8String, &status) == 0) {
      if (status.st_mode & S_IFDIR) {
        NSArray *pathsToAutomaticallyScan = self.pathsToAutomaticallyScan;
        if (!pathsToAutomaticallyScan)
          pathsToAutomaticallyScan = [NSArray array];
        NSMutableSet *pset = [NSMutableSet setWithArray:pathsToAutomaticallyScan];
        [pset addObject:p];
        self.pathsToAutomaticallyScan = pset.allObjects;
      }
    }
  }

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

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
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
    if (found < 0) {
      SortField *s = [[[SortField alloc] 
        initWithKey:ident
        direction:Ascending
        comparator:NaturalComparison] autorelease];
      [sortFields_ insertObject:s atIndex:0];
    } else if (found > 0) {
      // Pop the field off a non-zero index, set the direction to ascending
      SortField *s = [[[SortField alloc] 
        initWithKey:ident
        direction:Ascending
        comparator:NaturalComparison] autorelease];
      [sortFields_ removeObjectAtIndex:found];
      [sortFields_ insertObject:s atIndex:0];
    } else { 
      SortField *s = [sortFields_ objectAtIndex:0];
      // Flip the direction
      s.direction = s.direction == Ascending ? Descending : Ascending;
    }
  }
  sortChanged_ = YES;
  [self updateTableColumnHeaders];
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
  if (itemIdentifier == kPlayButton) { 
    return playButtonItem_;  
  } else if (itemIdentifier == kProgressControl) { 
    return progressSliderItem_;
  } else if (itemIdentifier == kVolumeControl) { 
    return volumeItem_;
  } else if (itemIdentifier == kSearchControl) { 
    return searchItem_;
  } else if (itemIdentifier == kPreviousButton) { 
    return previousButtonItem_;
  } else if (itemIdentifier == kNextButton)  {
    return nextButtonItem_;
  }
  return nil;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray arrayWithObjects:kPreviousButton, kPlayButton, kNextButton, kVolumeControl, kProgressControl, kSearchControl, nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar { 
  return [NSArray arrayWithObjects:kPreviousButton, kPlayButton, kNextButton, kVolumeControl, kProgressControl, kSearchControl, nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray array];
}

- (void)toolbarWillAddItem:(NSNotification *)notification {

}

- (void)toolbarWillRemoveItem:(NSNotification *)notification {
}

- (NSPredicate *)parseSearch { 
  NSPredicate *ret = nil;
  if (searchQuery_ ) {
    NSArray *tokens = [searchQuery_ 
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

- (void)executeSearch { 
  NSPredicate *predicate = [self parseSearch];

  @synchronized(allTracks_) {
    [tracks_ removeAllObjects];
    @synchronized(tracks_) {
      for (id t in allTracks_) {
        if (!predicate || [predicate evaluateWithObject:t]) {
          [tracks_ addObject:t];
        }
      } 
    }
  }
  needsReload_ = YES;
}

- (void)onSearch:(id)sender { 
  [self search:searchField_.stringValue];
}

- (void)volumeClicked:(id)sender { 
  [self setVolume:volumeSlider_.doubleValue]; 
}

- (void)setVolume:(double)pct { 
  // FIXME: Store volume pref here.
  if (movie_) 
    [movie_ setVolume:pct];
}

- (void)progressSliderIsUp:(NSNotification *)notification {
  if (movie_)
    [movie_ seek:progressSlider_.doubleValue * movie_.duration];
}

- (void)progressClicked:(id)sender { 
  if (movie_) {
    [self displayElapsed:(progressSlider_.doubleValue * movie_.duration) duration:movie_.duration];
  }
}

- (void)displayElapsed:(int64_t)elapsed duration:(int64_t)duration {
  [progressSlider_ setEnabled:YES];
  double pct = duration > 0 ? ((long double)elapsed) / ((long double)duration) : 0;
  durationText_.stringValue = [[NSNumber numberWithLongLong:duration] formatSeconds];
  elapsedText_.stringValue = [[NSNumber numberWithLongLong:elapsed] formatSeconds];
  if (![progressSlider_ isMouseDown] && ![movie_ isSeeking])
    [progressSlider_ setDoubleValue:pct];
}

- (void)executeSort { 
  @synchronized(self) {
    @synchronized (allTracks_) {
      [allTracks_ sortUsingFunction:CompareWithSortFields context:sortFields_];   
    }
  }
}

- (void)onPollMovieTimer:(id)sender { 
  if (requestPlayTrackAtIndex_ >= 0) {
    [self playTrackAtIndex:requestPlayTrackAtIndex_];
    requestPlayTrackAtIndex_ = -1;
  }

  mainWindow_.title = GetWindowTitle(track_);

  if (movie_ && ([movie_ state] == kEOFAudioSourceState)) {
    requestNext_ = YES;
  }

  if (requestNext_) {
    [self playNextTrack];
    requestNext_ = NO;
  }

  if (requestPrevious_) {
    [self playPreviousTrack];
    requestPrevious_ = NO;
  }

  if (requestClearSelection_) { 
    [trackTableView_ deselectAll:self];
    requestClearSelection_ = NO;
  }

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
      requestTogglePlay_ = NO; 
    } 
  }

  if (movie_ != NULL) {
    if (!progressSlider_.isMouseDown && !movie_.isSeeking) {
      [self displayElapsed:movie_ ? movie_.elapsed : 0 
        duration:movie_ ? movie_.duration : 0];
    } 
    if (movie_.state == kPlayingAudioSourceState)  {
      playButton_.image = stopImage_;
    } else {
      playButton_.image = startImage_;
    } 
  } else {
    [progressSlider_ setEnabled:NO];
    [progressSlider_ setDoubleValue:0];
    durationText_.stringValue = @"";
    elapsedText_.stringValue = @"";
    playButton_.image = startImage_;
  }

  if (lastLibraryRefresh_ == 0) {
    needsLibraryRefresh_ = YES;
  } else if ((library_.lastUpdatedAt > lastLibraryRefresh_)
      && (lastLibraryRefresh_ < (Now() - kLibraryRefreshInterval))) {
    needsLibraryRefresh_ = YES;
  }
  if (needsLibraryRefresh_) {
    NSLog(@"refreshing library");
    @synchronized(allTracks_) { 
      [allTracks_ removeAllObjects];
      [library_ each:^(Track *t) {
        [allTracks_ addObject:t];
      }];
    }
    needsLibraryRefresh_ = NO;
    predicateChanged_ = YES;
    sortChanged_ = YES;
    needsReload_ = YES;
    sortChanged_ = YES;
    lastLibraryRefresh_ = Now(); 
  }
  if (sortChanged_) { 
    [self executeSort];
    predicateChanged_ = YES;
    needsReload_ = YES;
    sortChanged_ = NO; 
  } 
  if (predicateChanged_) { 
    [self executeSearch]; 
    predicateChanged_ = NO; 
    needsReload_ = YES; 
  } 

  if (needsReload_) { 
    [trackTableView_ reloadData]; 
    needsReload_ = NO; 
  }

  if (seekToRow_ >= 0) { 
    [trackTableView_ scrollRowToVisible:seekToRow_];
    seekToRow_ = -1; 
  } 
}

- (void)onPollLibraryTimer:(id)sender { 
  [raopServiceBrowser_ searchForServicesOfType:kRAOPServiceType inDomain:@"local."];
  [mdServiceBrowser_ searchForServicesOfType:kMD0ServiceType inDomain:@"local."]; 
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
  @synchronized(tracks_) {
    self.track = (index > 0 && index < tracks_.count) ? [tracks_ objectAtIndex:index] : nil;
  }
  NSNetService *netService = [self.selectedAudioOutput objectForKey:@"service"];

  self.movie = track_ ? [[[Movie alloc] initWithURL:track_.url
    address:netService.ipv4Address port:netService.port] autorelease] : nil;
  self.movie.volume = self.volumeSlider.doubleValue;
  [self.movie start];

  self.seekToRow = index;
  self.needsReload = YES;
  if (track_) {
    @synchronized(plugins_) {
      for (Plugin *p in plugins_) {
        [p trackStarted:track_];
      }
    }
  }
  // Load the cover art if it isn't loaded already.
  [self loadCoverArt:self.track];
}

- (void)loadCoverArt:(Track *)track {
  NSLog(@"load cover art: %@", track);
  if (!track)
    return;
  if (track.coverArtURL && track.coverArtURL.length)
    return;
  if (!track.artist.length || !track.album.length) 
    return;
  NSString *term = [NSString stringWithFormat:@"%@ %@", track.artist, track.album];
  [appleCoverArtClient_ search:term withArtworkData:^(NSData *data) { 
    if (!data || !data.length)
      return;
    NSString *covertArtDir = CoverArtPath();
    mkdir(covertArtDir.UTF8String, 0755);
    NSString *path = [covertArtDir stringByAppendingPathComponent:term.sha1];
    if (![data writeToFile:path atomically:YES]) {
      NSLog(@"failed to write to %@", path);
      return;
    }
         
    NSString *url = [[NSURL fileURLWithPath:path] absoluteString];
    @synchronized(allTracks_) { 
      for (Track *t in allTracks_) {
        if ([t.artist isEqualToString:track.artist] 
            && [t.album isEqualToString:track.album] 
            && (!t.coverArtURL || !t.coverArtURL.length)) {
          t.coverArtURL = url;
          [self.localLibrary save:t];
        }
      }
    }
  }];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView { 
  @synchronized (tracks_) {
    return tracks_.count;
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
  Track *t = nil;
  @synchronized(tracks_) { 
    if (rowIndex < tracks_.count) 
      t = [tracks_ objectAtIndex:rowIndex];
  }
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
}

- (void)playClicked:(id)sender { 
  NSLog(@"play clicked");
  requestTogglePlay_ = YES;
}

- (void)nextClicked:(id)sender { 
  NSLog(@"next clicked");
  requestNext_ = YES;
}

- (void)previousClicked:(id)sender { 
  NSLog(@"previous clicked");
  requestPrevious_ = YES;
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

