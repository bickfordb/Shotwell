#import "AppDelegate.h"
#import "Log.h"
#import "MainWindowController.h"
#import "PlaybackControls.h"
#import "Player.h"
#import "PreferencesWindowController.h"
#import "Util.h"

static NSString * const kArtistIconName = @"NSEveryone";
static NSString * const kAlbumIconName = @"album-icon";
static NSString * const kTrackIconName = @"NSActionTemplate";
static NSString * const kRemoteLibraryIconName = @"NSNetwork";
static NSString * const kNetworkIconName = @"NSNetwork";
static NSString * const kLocalLibraryIconName = @"NSComputer";
static NSString * const kPlayButton = @"PlayButton";
static NSString * const kProgressControl = @"ProgressControl";
static CGRect kStartupFrame = {{50, 200}, {1300, 650}};
static const double kPollMovieInterval = 0.1;
static const int64_t kPollProgressInterval = 500000;
static NSString * const kDefaultWindowTitle = @"Shotwell";
static NSString * const kSearchControl = @"SearchControl";
static const int kBottomEdgeMargin = 25;
static NSString * const kVolumeControl = @"VolumeControl";
static const double kPollStatsInterval = 5.0;
static MainWindowController *mainWindowController = nil;

@implementation MainWindowController {
  PlaybackControls *playbackControls_;
  NSProgressIndicator *progressIndicator_;
  NSPopUpButton *browserControl_;
  NSSearchField *searchField_;
  NSSet *albums_;
  NSSet *artists_;
  Library *library_;
  NavTable *navTable_;
  NSTextField *statusBarText_;
  NSView *contentView_;
  ProgressControl *progressControl_;
  ServicePopUpButton *audioOutputPopUpButton_;
  ServiceBrowser *libraryServiceBrowser_;
  SplitView *verticalSplit_;
  SplitView *navSplit_;
  TrackBrowser *trackBrowser_;
  ViewController *content_;
  VolumeControl *volumeControl_;
  NSView *navContent_;
  bool isBusy_;
  dispatch_source_t pollStatsTimer_;
  dispatch_source_t pollPlayerTimer_;
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
  NSMenuItem *i = nil;
  i = [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  i.target = self;
  i = [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  i.target = self;
  i = [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  i.target = self;
  i = [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  i.target = self;
  i = [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:[NSString stringWithFormat:@"%C", (unsigned short)NSBackspaceCharacter]];
  i.target = self;
  [i setKeyEquivalentModifierMask:0];
  i = [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  i.target = self;
  i = [editMenu addItemWithTitle:@"Select None" action:@selector(deselectAll:) keyEquivalent:@"A"];
  i.target = self;

  // File Menu
  i = [fileMenu addItemWithTitle:@"Add to Library" action:@selector(addToLibrary:) keyEquivalent:@"o"];
  i.target = self;

  i = [mainMenu itemAtIndex:0];
  i = [i.submenu
    insertItemWithTitle:@"Preferences" action:@selector(makeKeyAndOrderFront:)
    keyEquivalent:@","
    atIndex:1];
  i.target = [PreferencesWindowController shared].window;

  // Playback Menu

  NSMenuItem *playbackItem = [mainMenu insertItemWithTitle:@"Playback" action:nil keyEquivalent:@"" atIndex:3];
  playbackItem.submenu = [[[NSMenu alloc] initWithTitle:@"Playback"] autorelease];
  NSMenu *playbackMenu = playbackItem.submenu;

  NSMenuItem *playItem = [playbackMenu addItemWithTitle:@"Play" action:@selector(playClicked:) keyEquivalent:@" "];
  [playItem setKeyEquivalentModifierMask:0];
  NSString *leftArrow = [NSString stringWithFormat:@"%C", (unsigned short)0xF702];
  NSString *rightArrow = [NSString stringWithFormat:@"%C", (unsigned short)0xF703];
  [playbackMenu addItemWithTitle:@"Previous" action:@selector(previousClicked:) keyEquivalent:leftArrow];
  [playbackMenu addItemWithTitle:@"Next" action:@selector(nextClicked:) keyEquivalent:rightArrow];

}

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
  [[LocalLibrary shared] scan:paths];
}
- (id)init {
  self = [super init];
  if (self) {
    searchField_ = [[NSSearchField alloc] initWithFrame:CGRectMake(0, 0, 300, 22)];
    searchField_.font = [NSFont systemFontOfSize:12.0];
    searchField_.autoresizingMask = NSViewMinXMargin;
    searchField_.action = @selector(onSearch:);
    [searchField_ setRecentsAutosaveName:@"recentSearches"];
    [self setupWindow];
    [self setupStatusBarText];
    [self setupBusyIndicator];
    __block MainWindowController *weakSelf = self;
    pollPlayerTimer_ = CreateDispatchTimer(kPollMovieInterval, dispatch_get_main_queue(), ^{

    });
    isBusy_ = false;
    /*
    [loop_ every:kPollProgressInterval with:^{
      if (weakSelf.content.isBusy && !isBusy_) {
        [progressIndicator_ startAnimation:self];
        isBusy_ = true;
      } else if (!weakSelf.content.isBusy && isBusy_) {
        isBusy_ = false;
        [progressIndicator_ stopAnimation:self];
      }
    }];
    */
    pollStatsTimer_ = CreateDispatchTimer(kPollStatsInterval, dispatch_get_main_queue(), ^{
      [weakSelf pollStats];
    });
    [self bind:@"currentTrack" toObject:[Player shared] withKeyPath:@"track" options:nil];
    trackBrowser_ = [[TrackBrowser alloc] init];
    searchField_.target = trackBrowser_;
    [self setContent:trackBrowser_];
  }
  return self;
}

- (void)removeRemoteLibraryService:(NSNetService *)svc {
}

- (void)addRemoteLibraryService:(NSNetService *)svc {
}

- (void)setContent:(ViewController *)vc {
  @synchronized(self) {
    CGRect f = contentView_.frame;
    f.origin.x = 0;
    f.origin.y = 0;
    for (NSView *view in contentView_.subviews) {
      [view removeFromSuperview];
    }
    self.content.nextResponder = nil;
    vc.view.frame = f;
    [contentView_ addSubview:vc.view];
    vc.view.nextResponder = vc;
    vc.nextResponder = contentView_;
    [content_ autorelease];
    content_ = [vc retain];
  }
}

- (ViewController *)content {
  return content_;
}

- (void)dealloc {
  dispatch_release(pollStatsTimer_);
  dispatch_release(pollPlayerTimer_);
  [albums_ release];
  [artists_ release];
  [audioOutputPopUpButton_ release];
  [browserControl_ release];
  [contentView_ release];
  [content_ release];
  [playbackControls_ release];
  [progressControl_ release];
  [searchField_ release];
  [statusBarText_ release];
  [trackBrowser_ release];
  [verticalSplit_ release];
  [volumeControl_ release];
  [super dealloc];
}

- (void)setupBusyIndicator {
  CGSize sz = ((NSView *)self.window.contentView).frame.size;
  CGRect rect = CGRectMake(sz.width - 5 - 18, 2, 18, 18);
  progressIndicator_ = [[NSProgressIndicator alloc] initWithFrame:rect];
  progressIndicator_.style = NSProgressIndicatorSpinningStyle;
  progressIndicator_.autoresizingMask = NSViewMaxYMargin | NSViewMinXMargin;
  progressIndicator_.displayedWhenStopped = NO;
  [self.window.contentView addSubview:progressIndicator_];
}

- (void)setupWindow {
  [self.window setFrame:kStartupFrame display:YES];
  [self.window display];
  [self.window makeKeyAndOrderFront:self];
  [self.window setAutorecalculatesContentBorderThickness:YES forEdge:NSMaxYEdge];
  [self.window setAutorecalculatesContentBorderThickness:YES forEdge:NSMinYEdge];
  [self.window setContentBorderThickness:kBottomEdgeMargin forEdge:NSMinYEdge];
  self.window.title = kDefaultWindowTitle;
  NSRect splitRect = [self.window.contentView frame];
  splitRect.origin.y += kBottomEdgeMargin;
  splitRect.size.height -= kBottomEdgeMargin;

  navSplit_ = [[SplitView alloc] initWithFrame:splitRect];
  [navSplit_ setDividerStyle:NSSplitViewDividerStyleThin];
  navSplit_.autoresizesSubviews = YES;
  navSplit_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  navSplit_.vertical = YES;
  navSplit_.focusRingType = NSFocusRingTypeNone;
  navSplit_.dividerColor = [NSColor grayColor];
  navSplit_.dividerThickness = 1.0;
  [self.window.contentView addSubview:navSplit_];


  contentView_ = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
  contentView_.autoresizesSubviews = YES;
  contentView_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  contentView_.focusRingType = NSFocusRingTypeNone;

  verticalSplit_ = [[SplitView alloc] initWithFrame:splitRect];
  [verticalSplit_ setDividerStyle:NSSplitViewDividerStyleThin];
  verticalSplit_.autoresizesSubviews = YES;
  verticalSplit_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  verticalSplit_.focusRingType = NSFocusRingTypeNone;
  verticalSplit_.vertical = NO;
  verticalSplit_.dividerColor = [NSColor grayColor];
  verticalSplit_.dividerThickness = 1.0;
  [verticalSplit_ addSubview:contentView_];
  [navSplit_ addSubview:verticalSplit_];
  NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"main"] autorelease];
  toolbar.delegate = self;
  toolbar. displayMode = NSToolbarDisplayModeIconOnly;
  self.window.toolbar = toolbar;
}

- (void)setupStatusBarText {
  int windowWidth = ((NSView *)[self.window contentView]).bounds.size.width;
  int w = 300;
  int x = (windowWidth / 2.0) - (300.0 / 2.0) + 5.0;

  statusBarText_ = [[NSTextField alloc] initWithFrame:CGRectMake(x, 2, w, 18)];
  statusBarText_.stringValue = @"";
  statusBarText_.editable = NO;
  statusBarText_.selectable = NO;
  statusBarText_.bordered = NO;
  statusBarText_.bezeled = NO;
  statusBarText_.backgroundColor = [NSColor clearColor];
  statusBarText_.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
  statusBarText_.alignment = NSCenterTextAlignment;
  NSTextFieldCell *cell = (NSTextFieldCell *)[statusBarText_ cell];
  cell.font = [NSFont systemFontOfSize:11.0];
  cell.font = [NSFont systemFontOfSize:11.0];
  [cell setControlSize:NSSmallControlSize];
  [cell setBackgroundStyle:NSBackgroundStyleRaised];
  [[self.window contentView] addSubview:statusBarText_];
}

- (void)setCurrentTrack:(NSMutableDictionary *)t {
  NSString *result = @"";
  NSString *title = t[kTrackTitle];
  NSString *artist = t[kTrackArtist];
  NSString *album = t[kTrackAlbum];
  NSString *path = t[kTrackPath];
  if (title.length && artist.length && album.length) {
    result = [NSString stringWithFormat:@"%@ - %@ - %@ ", title, artist, album, nil];
  } else if (title.length) {
    result = title;
  } else if (path) {
    result = path;
  } else {
    result = kDefaultWindowTitle;
  }
  ForkToMainWith(^{ self.window.title = result; });
 }

- (id)currentTrack {
  return nil;
}

- (void)setupAudioSelect {
  int w = 160;
  int x = ((NSView *)[self.window contentView]).bounds.size.width;
  x -= w + 10;
  x -= 32;
  audioOutputPopUpButton_ = [[ServicePopUpButton alloc] initWithFrame:CGRectMake(x, 2, w, 18)];
  audioOutputPopUpButton_.onService = ^(id v) {
    NSDictionary *item = (NSDictionary *)v;
    INFO(@"set output to: %@", item);
    [[Player shared] setOutputDevice:item[@"id"]];
  };
  audioOutputPopUpButton_.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
  NSButtonCell *buttonCell = (NSButtonCell *)[audioOutputPopUpButton_ cell];
  [buttonCell setFont:[NSFont systemFontOfSize:11.0]];
  [buttonCell setControlSize:NSSmallControlSize];

  [[self.window contentView] addSubview:audioOutputPopUpButton_];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
  NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
  NSView *view = nil;
  if (itemIdentifier == kPlayButton) {
      playbackControls_ = [[PlaybackControls alloc] initWithFrame:CGRectMake(0, 0, 130, 25)];
      __block MainWindowController *weakSelf = self;
      playbackControls_.onPrevious = ^{
        [weakSelf->trackBrowser_ playPreviousTrack];
      };
      playbackControls_.onPlay = ^{
        Player *player = [Player shared];
        if (player.track && !player.isDone) {
          player.isPaused = !player.isPaused;
        } else {
          [weakSelf->trackBrowser_ playNextTrack];
        }
      };
      playbackControls_.onNext = ^{
        [weakSelf->trackBrowser_ playNextTrack];
      };
      view = playbackControls_;
  } else if (itemIdentifier == kProgressControl) {
    if (!progressControl_) {
      progressControl_ = [[ProgressControl alloc]
        initWithFrame:CGRectMake(0, 0, 5 + 60 + 5 + 300 + 5 + + 60 + 5, 22)];
    }
    view = progressControl_.view;
    [item setMaxSize:NSMakeSize(1000, 22)];
    [item setMinSize:NSMakeSize(400, 22)];
  } else if (itemIdentifier == kVolumeControl) {
    if (!volumeControl_) {
      volumeControl_ = [[VolumeControl alloc] init];
    }
    view = volumeControl_.view;
  } else if (itemIdentifier == kSearchControl) {
    view = searchField_;
  }
  if (view) {
    item.view = view;
    item.enabled = YES;
  }
  return item;

}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
  return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray arrayWithObjects:kPlayButton, kVolumeControl, kProgressControl, kSearchControl, nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray array];
}

- (void)toolbarWillAddItem:(NSNotification *)notification {
}

- (void)toolbarWillRemoveItem:(NSNotification *)notification {
}

- (void)pollStats {
  NSMutableSet *artists = [NSMutableSet set];
  NSMutableSet *albums = [NSMutableSet set];
  int i = 0;
  NSMutableDictionary *stats = [NSMutableDictionary dictionary];
  NSArray *fields = @[kTrackArtist, kTrackAlbum];
  for (id field in fields) {
    stats[field] = [NSMutableSet set];
  }
  for (NSMutableDictionary *track in trackBrowser_.tracks.array) {
    for (id field in fields) {
      NSString *val = track[field];
      if (!val || !val.length) continue;
      [stats[field] addObject:val];
    }
    i++;
  }
  statusBarText_.stringValue = [NSString stringWithFormat:@"%d Tracks, %d Artists, %d Albums", i, (int)[((NSSet *)stats[kTrackArtist]) count], (int)[((NSSet *)stats[kTrackAlbum]) count]];
}


+ (MainWindowController *)shared {
  if (!mainWindowController)
    mainWindowController = [[MainWindowController alloc] init];
  return mainWindowController;
}

- (void)paste:(id)sender {
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  NSArray *items = [pboard readObjectsForClasses:[NSArray arrayWithObjects:[NSURL class], nil]
    options:nil];
  NSMutableArray *paths = [NSMutableArray array];
  for (NSURL *u in items) {
    if (!u.isFileURL) {
      continue;
    }
    [paths addObject:u.path];
  }
  if (paths.count > 0) {
    [[LocalLibrary shared] scan:paths];
  }
}
@end


