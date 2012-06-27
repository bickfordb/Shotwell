#import "app/AppDelegate.h"
#import "app/AudioSource.h"
#import "app/Log.h"
#import "app/MainWindowController.h"
#import "app/NSNetServiceAddress.h"
#import "app/PThread.h"
#import "app/RemoteLibrary.h"
#import "app/RAOP.h"
#import "app/CoreAudioSink.h"

static NSString * const kArtistIconName = @"album-icon";
static NSString * const kAlbumIconName = @"album-icon";
static NSString * const kTrackIconName = @"album-icon";
static NSString * const kNextButton = @"NextButton";
static NSString * const kRAOPServiceType = @"_raop._tcp.";
static NSString * const kPlayButton = @"PlayButton";
static NSString * const kPreviousButton = @"PreviousButton";
static NSString * const kProgressControl = @"ProgressControl";
static CGRect kStartupFrame = {{50, 200}, {1300, 650}};
static int64_t kPollMovieInterval = 100000;
static int64_t kPollProgressInterval = 500000;
static NSString * const kDefaultWindowTitle = @"Shotwell";
static NSString * const kSearchControl = @"SearchControl";
static  const int kBottomEdgeMargin = 25;
static NSString * const kVolumeControl = @"VolumeControl";
static const int64_t kPollStatsInterval = 5 * 1000000;

static NSString *GetWindowTitle(Track *t) {
  NSString *title = t.title;
  NSString *artist = t.artist;
  NSString *album = t.album;
  NSURL *url = t.url;

  if ([title length] && [artist length] && [album length])
    return [NSString stringWithFormat:@"%@ - %@ - %@ ", title, artist, album, nil];
  else if ([title length])
    return title;
  else if (url)
    return url.absoluteString;
  else
    return kDefaultWindowTitle;
}

@implementation MainWindowController
@synthesize albums = albums_;
@synthesize artists = artists_;
@synthesize audioOutputPopUpButton = audioOutputPopUpButton_;
@synthesize contentView = contentView_;
@synthesize horizontalSplit = horizontalSplit_;
@synthesize libraryServiceBrowser = libraryServiceBrowser_;
@synthesize loop = loop_;
@synthesize navSplit = navSplit_;
@synthesize navTable = navTable_;
@synthesize nextButton = nextButton_;
@synthesize playButton = playButton_;
@synthesize playImage = playImage_;
@synthesize previousButton = previousButton_;
@synthesize progressControl = progressControl_;
@synthesize progressIndicator = progressIndicator_;
@synthesize searchField = searchField_;
@synthesize startImage = startImage_;
@synthesize statusBarText = statusBarText_;
@synthesize stopImage = stopImage_;
@synthesize trackBrowser = trackBrowser_;
@synthesize verticalSplit = verticalSplit_;
@synthesize volumeControl = volumeControl_;
@synthesize albumBrowser = albumBrowser_;
@synthesize artistBrowser = artistBrowser_;

- (id)init {
  self = [super init];
  if (self) {
    self.loop = [Loop loop];
    self.startImage = [NSImage imageNamed:@"start"];
    self.stopImage = [NSImage imageNamed:@"stop"];
    self.searchField = [[[NSSearchField alloc] initWithFrame:CGRectMake(0, 0, 300, 22)] autorelease];
    self.searchField.font = [NSFont systemFontOfSize:12.0];
    self.searchField.autoresizingMask = NSViewMinXMargin;
    self.searchField.target = self;
    self.searchField.action = @selector(onSearch:);
    [self.searchField setRecentsAutosaveName:@"recentSearches"];
    [self setupWindow];
    [self setupStatusBarText];
    [self setupBusyIndicator];
//    [self setupLibrarySelect];
//
    __block MainWindowController *weakSelf = self;
    [loop_ every:kPollMovieInterval with:^{
      //id <AudioSource> movie = SharedAppDelegate().audioSource;
      id <AudioSink> sink = SharedAppDelegate().audioSink;
      if (sink) {
        if (!sink.isSeeking) {
          weakSelf.progressControl.isEnabled = true;
          weakSelf.progressControl.duration = sink.duration;
          weakSelf.progressControl.elapsed = sink.elapsed;
        }
        playButton_.image = (sink.audioSource.state == kPlayingAudioSourceState) ? stopImage_ : startImage_;
        weakSelf.volumeControl.level = SharedAppDelegate().audioSink.volume;
      } else {
        weakSelf.progressControl.duration = 0;
        weakSelf.progressControl.elapsed = 0;
        weakSelf.progressControl.isEnabled = false;
        playButton_.image = startImage_;
      }
    }];
    isBusy_ = false;
    [loop_ every:kPollProgressInterval with:^{
      if (weakSelf.content.isBusy && !isBusy_) {
        [self.progressIndicator startAnimation:self];
        isBusy_ = true;
      } else if (!weakSelf.content.isBusy && isBusy_) {
        isBusy_ = false;
        [self.progressIndicator stopAnimation:self];
      }
    }];
    [self setupAudioSelect];
    [self.loop every:kPollStatsInterval with:^{
      [weakSelf pollStats];
    }];
    self.libraryServiceBrowser = [[[ServiceBrowser alloc]
      initWithType:kDaemonServiceType
      onAdded:^(NSNetService *svc) {
        [weakSelf addRemoteLibraryService:svc];
      }
      onRemoved:^(NSNetService *svc) {
        [self removeRemoteLibraryService:svc];
      }] autorelease];
    [self selectBrowser:MainWindowControllerTrackBrowser];
  }
  return self;
}

- (void)removeRemoteLibraryService:(NSNetService *)svc {
}

- (void)addRemoteLibraryService:(NSNetService *)svc {
  NSLog(@"Added service: %@", svc);
  __block MainWindowController *weakSelf = self;
  for (NavNode *network in NodeGet(self.navTable.rootNode, kNodeChildren)) {
    NSString *key = NodeGet(network, @"key");
    if (![key isEqualToString:@"network"]) {
      continue;
    }
    for (NavNode *aLibrary in NodeGet(network, kNodeChildren)) {
      NSNetService *aService = NodeGet(aLibrary, @"service");
      if (aService && [aService isEqualTo:svc]) {
        return;
      }
    }
    NavNode *library = NodeCreate();
    NodeSet(library, @"service", svc);
    NodeAppend(network, library);
    NodeSet(library, kNodeTitle, svc.name);
    NavNode *tracks = NodeCreate();
    NodeAppend(library, tracks);
    NodeSet(tracks, kNodeTitle, @"Tracks");
    NodeSet(tracks, kNodeTitleCell, NodeImageTextCell([NSImage imageNamed:kTrackIconName]));
    NodeSet(tracks, kNodeOnSelect, [^{
        SharedAppDelegate().library = [[[RemoteLibrary alloc] initWithNetService:svc] autorelease];
        [weakSelf selectBrowser:MainWindowControllerTrackBrowser];
        } copy]);

    NavNode *albums = NodeCreate();
    NodeSet(albums, kNodeTitleCell, NodeImageTextCell([NSImage imageNamed:kAlbumIconName]));

    NodeSet(albums, kNodeTitle, @"Albums");
    NodeSet(albums, kNodeOnSelect, [^{
        SharedAppDelegate().library = [[[RemoteLibrary alloc] initWithNetService:svc] autorelease];
        [weakSelf selectBrowser:MainWindowControllerAlbumBrowser];
        } copy]);
    NodeAppend(library, albums);

    NavNode *artists = NodeCreate();
    NodeSet(artists, kNodeTitleCell, NodeImageTextCell([NSImage imageNamed:kAlbumIconName]));

    NodeSet(artists, kNodeTitle, @"Artists");
    NodeSet(artists, kNodeOnSelect, [^{
        SharedAppDelegate().library = [[[RemoteLibrary alloc] initWithNetService:svc] autorelease];
        [weakSelf selectBrowser:MainWindowControllerArtistBrowser];
        } copy]);
    NodeAppend(library, artists);
    ForkToMainWith(^{
        [weakSelf.navTable.outlineView reloadData];
        [weakSelf.navTable.outlineView expandItem:network];
        [weakSelf.navTable.outlineView expandItem:library];
        });
    NSLog(@"reloaded");
    break;
  }
}

- (void)setContent:(ViewController *)vc {
  @synchronized(self) {
    CGRect f = self.contentView.frame;
    f.origin.x = 0;
    f.origin.y = 0;
    for (NSView *view in self.contentView.subviews) {
      [view removeFromSuperview];
    }
    self.content.nextResponder = nil;
    vc.view.frame = f;
    [self.contentView addSubview:vc.view];
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
  [albums_ release];
  [artists_ release];
  [audioOutputPopUpButton_ release];
  [contentView_ release];
  [content_ release];
  [horizontalSplit_ release];
  [loop_ release];
  [nextButton_ release];
  [playButton_ release];
  [playImage_ release];
  [previousButton_ release];
  [progressControl_ release];
  [searchField_ release];
  [startImage_ release];
  [statusBarText_ release];
  [stopImage_ release];
  [verticalSplit_ release];
  [volumeControl_ release];
  [super dealloc];
}

- (void)search:(NSString *)term after:(On0)after {
  after = [after copy];
  if (![self.searchField.stringValue isEqual:term])
    self.searchField.stringValue = term;
  [self.content search:term after:after];
}

- (void)setupBusyIndicator {
  CGSize sz = ((NSView *)self.window.contentView).frame.size;
  CGRect rect = CGRectMake(sz.width - 5 - 18, 2, 18, 18);
  self.progressIndicator = [[[NSProgressIndicator alloc] initWithFrame:rect] autorelease];
  self.progressIndicator.style = NSProgressIndicatorSpinningStyle;
  self.progressIndicator.autoresizingMask = NSViewMaxYMargin | NSViewMinXMargin;
  self.progressIndicator.displayedWhenStopped = NO;
  [self.window.contentView addSubview:self.progressIndicator];
}

- (void)selectBrowser:(MainWindowControllerBrowser)idx {
  Library *library = SharedAppDelegate().library;
  if (idx == MainWindowControllerAlbumBrowser) {
    if (!self.albumBrowser || self.albumBrowser.library != library) {
      self.albumBrowser = [[[CoverBrowser alloc] initWithLibrary:library
        toKey:CoverBrowserGroupByFolder
        toTitle:CoverBrowserFolderTitle
        toSubtitle:CoverBrowserFolderSubtitle
        toPredicate:CoverBrowserSearchByFolder] autorelease];
    }
    self.content = self.albumBrowser;
  } else if (idx == MainWindowControllerArtistBrowser) {
    if (!self.artistBrowser || self.artistBrowser.library != library) {
      self.artistBrowser = [[[CoverBrowser alloc] initWithLibrary:library
        toKey:CoverBrowserGroupByArtist
        toTitle:CoverBrowserArtistTitle
        toSubtitle:CoverBrowserArtistSubtitle
        toPredicate:CoverBrowserSearchByArtist] autorelease];
    }
    self.content = self.artistBrowser;
  } else {
    if (!self.trackBrowser) {
      self.trackBrowser = [[[TrackBrowser alloc] initWithLibrary:library] autorelease];
    }
    self.content = self.trackBrowser;
  }
  NSString *term = self.searchField.stringValue;
  if (term) {
    [self.content search:term after:nil];
  }
}

- (void)onSearch:(id)sender {
  [[NSApp delegate] search:[sender stringValue] after:nil];
}

- (void)setupNav {
  self.navTable = [[[NavTable alloc] initWithFrame:CGRectMake(0, 0, 148, self.navSplit.frame.size.height)] autorelease];
  NavNode *root = self.navTable.rootNode;
  NavNode *library = NodeCreate();
  NodeSet(library, kNodeTitle, @"Library");
  NodeSet(library, kNodeIsGroup, [NSNumber numberWithBool:YES]);
  NodeAppend(root, library);

  NavNode *network = NodeCreate();
  NodeSet(network, kNodeTitle, @"Network");
  NodeSet(network, @"key", @"network");
  NodeSet(network, kNodeIsGroup, [NSNumber numberWithBool:YES]);
  NodeAppend(root, network);

  NSMutableDictionary *tracks = NodeCreate();
  NodeSet(tracks, kNodeTitle, @"Tracks");
  NodeSet(tracks, kNodeTitleCell, NodeImageTextCell([NSImage imageNamed:kTrackIconName]));
  NodeSet(tracks, kNodeOnSelect, [^{
    SharedAppDelegate().library = SharedAppDelegate().localLibrary;
    [self selectBrowser:MainWindowControllerTrackBrowser];
  } copy]);
  NodeAppend(library, tracks);

  // Albums
  NSMutableDictionary *albums = NodeCreate();
  NodeSet(albums, kNodeTitle, @"Albums");
  NodeSet(albums, kNodeTitleCell, NodeImageTextCell([NSImage imageNamed:kAlbumIconName]));
  NodeSet(albums, kNodeOnSelect, [^{
    SharedAppDelegate().library = SharedAppDelegate().localLibrary;
    [self selectBrowser:MainWindowControllerAlbumBrowser];
  } copy]);
  NodeAppend(library, albums);

  // Artists
  NSMutableDictionary *artists = NodeCreate();
  NodeSet(artists, kNodeTitle, @"Artists");
  NodeSet(artists, kNodeTitleCell, NodeImageTextCell([NSImage imageNamed:kArtistIconName]));
  NodeSet(artists, kNodeOnSelect, [^{
    SharedAppDelegate().library = SharedAppDelegate().localLibrary;
    [self selectBrowser:MainWindowControllerArtistBrowser];
  } copy]);
  NodeAppend(library, artists);

  [self.navTable reload];
  [self.navTable.outlineView expandItem:library];
  [self.navSplit addSubview:self.navTable];
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

  self.navSplit = [[[SplitView alloc] initWithFrame:splitRect] autorelease];
  [self.navSplit setDividerStyle:NSSplitViewDividerStyleThin];
  self.navSplit.autoresizesSubviews = YES;
  self.navSplit.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.navSplit.vertical = YES;
  self.navSplit.focusRingType = NSFocusRingTypeNone;
  self.navSplit.dividerColor = [NSColor grayColor];
  self.navSplit.dividerThickness = 0.5;
  [self.window.contentView addSubview:self.navSplit];

  [self setupNav];

  self.horizontalSplit = [[[SplitView alloc] initWithFrame:splitRect] autorelease];
  [self.horizontalSplit setDividerStyle:NSSplitViewDividerStyleThin];
  self.horizontalSplit.autoresizesSubviews = YES;
  self.horizontalSplit.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.horizontalSplit.vertical = NO;
  self.horizontalSplit.focusRingType = NSFocusRingTypeNone;
  //[self.window.contentView addSubview:self.horizontalSplit];
  [self.navSplit addSubview:self.horizontalSplit];

  self.contentView = [[[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)] autorelease];
  self.contentView.autoresizesSubviews = YES;
  self.contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.contentView.focusRingType = NSFocusRingTypeNone;

  self.verticalSplit = [[[SplitView alloc] initWithFrame:splitRect] autorelease];
  [self.verticalSplit setDividerStyle:NSSplitViewDividerStyleThin];
  self.verticalSplit.autoresizesSubviews = YES;
  self.verticalSplit.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.verticalSplit.focusRingType = NSFocusRingTypeNone;
  self.verticalSplit.vertical = YES;
  self.verticalSplit.dividerColor = [NSColor grayColor];
  self.verticalSplit.dividerThickness = 0;
  [self.verticalSplit addSubview:self.contentView];
  [self.horizontalSplit addSubview:self.verticalSplit];
  [self.horizontalSplit adjustSubviews];
  NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"main"] autorelease];
  toolbar.delegate = self;
  toolbar. displayMode = NSToolbarDisplayModeIconOnly;
  self.window.toolbar = toolbar;

}

- (void)setupStatusBarText {
  int windowWidth = ((NSView *)[self.window contentView]).bounds.size.width;
  int w = 300;
  int x = (windowWidth / 2.0) - (300.0 / 2.0) + 5.0;

  self.statusBarText = [[[NSTextField alloc] initWithFrame:CGRectMake(x, 2, w, 18)] autorelease];
  self.statusBarText.stringValue = @"";
  self.statusBarText.editable = NO;
  self.statusBarText.selectable = NO;
  self.statusBarText.bordered = NO;
  self.statusBarText.bezeled = NO;
  self.statusBarText.backgroundColor = [NSColor clearColor];
  self.statusBarText.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
  self.statusBarText.alignment = NSCenterTextAlignment;

  NSTextFieldCell *cell = (NSTextFieldCell *)[self.statusBarText cell];
  cell.font = [NSFont systemFontOfSize:11.0];
  cell.font = [NSFont systemFontOfSize:11.0];
  [cell setControlSize:NSSmallControlSize];
  [cell setBackgroundStyle:NSBackgroundStyleRaised];
  [[self.window contentView] addSubview:self.statusBarText];
}

- (void)setupAudioSelect {
  int w = 160;
  int x = ((NSView *)[self.window contentView]).bounds.size.width;
  x -= w + 10;
  x -= 32;
  self.audioOutputPopUpButton = [[[ServicePopUpButton alloc] initWithFrame:CGRectMake(x, 2, w, 18)
    serviceTypes:[NSSet setWithObjects:kRAOPServiceType, nil]] autorelease];
  self.audioOutputPopUpButton.onService = ^(id v) {
    NSNetService *netService = (NSNetService *)v;
    bool isPaused = SharedAppDelegate().audioSink.isPaused;
    id <AudioSource> audioSource = SharedAppDelegate().audioSink.audioSource;
    SharedAppDelegate().audioSink.audioSource = nil;
    SharedAppDelegate().audioSink.isPaused = true;
    if (netService) {
      SharedAppDelegate().audioSink = [[[RAOPSink alloc] initWithAddress:netService.ipv4Address port:netService.port] autorelease];
    } else {
      SharedAppDelegate().audioSink = [[[CoreAudioSink alloc] init] autorelease];
    }
    SharedAppDelegate().audioSink.audioSource = audioSource;
    SharedAppDelegate().audioSink.isPaused = isPaused;
  };
  [self.audioOutputPopUpButton appendItemWithTitle:@"Computer Speakers" value:nil];
  self.audioOutputPopUpButton.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
  NSButtonCell *buttonCell = (NSButtonCell *)[self.audioOutputPopUpButton cell];
  [buttonCell setFont:[NSFont systemFontOfSize:11.0]];
  [buttonCell setControlSize:NSSmallControlSize];

  [[self.window contentView] addSubview:self.audioOutputPopUpButton];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
  NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
  NSView *view = nil;
  if (itemIdentifier == kPlayButton) {
      self.playButton = [[[NSButton alloc] initWithFrame:CGRectMake(0, 0, 40, 22)] autorelease];
      view = playButton_;
      playButton_.title = @"";
      playButton_.image = self.startImage;
      playButton_.bezelStyle = NSTexturedRoundedBezelStyle;
      playButton_.action = @selector(playClicked:);
      playButton_.target = SharedAppDelegate();
      //[[playButton_ cell] setImageScaling:0.8];
      [[playButton_ cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
  } else if (itemIdentifier == kProgressControl) {
    if (!self.progressControl) {
      self.progressControl = [[[ProgressControl alloc]
        initWithFrame:CGRectMake(0, 0, 5 + 60 + 5 + 300 + 5 + + 60 + 5, 22)] autorelease];
      self.progressControl.onElapsed = ^(int64_t amt) {
        //[SharedAppDelegate().audioSink flush];
        [SharedAppDelegate().audioSink seek:amt];
      };
    }
    view = self.progressControl.view;
    [item setMaxSize:NSMakeSize(1000, 22)];
    [item setMinSize:NSMakeSize(400, 22)];
  } else if (itemIdentifier == kVolumeControl) {
    if (!self.volumeControl) {
      self.volumeControl = [[[VolumeControl alloc] init] autorelease];
      self.volumeControl.onVolume = ^(double amt) {
        SharedAppDelegate().audioSink.volume = amt;
      };
    }
    view = self.volumeControl.view;
  } else if (itemIdentifier == kSearchControl) {
    view = self.searchField;
  } else if (itemIdentifier == kPreviousButton) {
    NSButton *previousButton =  [[[NSButton alloc] initWithFrame:CGRectMake(0, 0, 40, 22)] autorelease];
    view = previousButton;
    previousButton.title = @"";
    previousButton.bezelStyle = NSTexturedRoundedBezelStyle;
    previousButton.image = [NSImage imageNamed:@"left"];
    previousButton.action = @selector(previousClicked:);
    previousButton.target = SharedAppDelegate();
    //[[previousButton cell] setImageScaling:0.8];
    [[previousButton cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
  } else if (itemIdentifier == kNextButton)  {
    NSButton *nextButton = [[[NSButton alloc] initWithFrame:CGRectMake(0, 0, 40, 22)] autorelease];
    nextButton.target = self;
    nextButton.title = @"";
    nextButton.image = [NSImage imageNamed:@"right"];
    nextButton.bezelStyle = NSTexturedRoundedBezelStyle;
    //[[nextButton cell] setImageScaling:0.8];
    [[nextButton cell] setImageScaling:NSImageScaleProportionallyUpOrDown];
    nextButton.action = @selector(nextClicked:);
    nextButton.target = SharedAppDelegate();
    view = nextButton;
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
  return [NSArray arrayWithObjects:kPreviousButton, kPlayButton, kNextButton,
         kVolumeControl, kProgressControl, kSearchControl, nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
  return [NSArray array];
}
- (void)toolbarWillAddItem:(NSNotification *)notification {
}

- (void)toolbarWillRemoveItem:(NSNotification *)notification {
}

- (void)trackStarted:(Track *)track {
  self.window.title = GetWindowTitle(track);
  [self.content reload];
}

- (void)trackEnded:(Track *)track {
  self.window.title = kDefaultWindowTitle;
  [self.content reload];
}

- (void)pollStats {
  NSMutableSet *artists = [NSMutableSet set];
  NSMutableSet *albums = [NSMutableSet set];
  int i = 0;
  for (Track *t in self.trackBrowser.tracks.array) {
    if (t.artist)
      [artists addObject:t.artist];
    if (t.album)
      [albums addObject:t.album];
    i++;
  }
  self.artists = artists;
  self.albums = albums;
  self.statusBarText.stringValue = [NSString stringWithFormat:@"%d Tracks, %d Artists, %d Albums", i, self.artists.count, self.albums.count];
}
@end

