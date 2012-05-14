#import "app/AppDelegate.h"
#import "app/AudioSource.h"
#import "app/Log.h"
#import "app/MainWindowController.h"
#import "app/NSNetServiceAddress.h"
#import "app/PThread.h"
#import "app/RemoteLibrary.h"
#import "app/RAOP.h"
#import "app/CoreAudioSink.h"

static NSString * const kNextButton = @"NextButton";
static NSString * const kRAOPServiceType = @"_raop._tcp.";
static NSString * const kPlayButton = @"PlayButton";
static NSString * const kPreviousButton = @"PreviousButton";
static NSString * const kProgressControl = @"ProgressControl";
static NSString * const kGroupControl = @"GroupControl";
static CGRect kStartupFrame = {{50, 50}, {1300, 650}};
static int64_t kPollMovieInterval = 100000;
static int64_t kPollProgressInterval = 500000;
static NSString * const kDefaultWindowTitle = @"Mariposa";
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
@synthesize groupsButton = groupsButton_;
@synthesize horizontalSplit = horizontalSplit_;
@synthesize libraryPopUp = libraryPopUp_;
@synthesize libraryPopUpButton = libraryPopUpButton_; 
@synthesize loop = loop_;
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
    [self setupGroupsPopupButton];
    [self setupWindow];
    [self setupStatusBarText];
    [self setupBusyIndicator];
    [self setupLibrarySelect];

    __block MainWindowController *weakSelf = self;
    [loop_ every:kPollMovieInterval with:^{
      id <AudioSource> movie = SharedAppDelegate().audioSource;
      if (movie) {
        if (!movie.isSeeking) {
          weakSelf.progressControl.isEnabled = true;
          weakSelf.progressControl.duration = movie.duration;
          weakSelf.progressControl.elapsed = movie.elapsed;
        }
        playButton_.image = (movie.state == kPlayingAudioSourceState) ? stopImage_ : startImage_;
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
    [self selectBrowser:MainWindowControllerTrackBrowser];
  }
  return self;
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
  [groupsButton_ release];
  [horizontalSplit_ release];
  [libraryPopUp_ release];
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

- (void)setupGroupsPopupButton {
  CGRect rect = CGRectMake(0, 0, 100, 32);
  NSImage *albumImage = [NSImage imageNamed:@"album-icon"];
  NSImage *trackImage = [NSImage imageNamed:@"NSListViewTemplate"];
  self.groupsButton = [[[NSSegmentedControl alloc] initWithFrame:rect] autorelease]; 
  self.groupsButton.segmentStyle = NSSegmentStyleTexturedRounded;
  self.groupsButton.segmentCount = 2;
  self.groupsButton.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  [[self.groupsButton cell] setControlSize:NSRegularControlSize];
  self.groupsButton.selectedSegment = 1;
  self.groupsButton.target = self;
  self.groupsButton.action = @selector(onGroupSelect:);
  [self.groupsButton setImage:albumImage forSegment:0];
  [self.groupsButton setImage:trackImage forSegment:1];
  [self.groupsButton setImageScaling:NSImageScaleProportionallyUpOrDown forSegment:0];
}

- (Library *)library { 
  return library_;
}

- (void)setLibrary:(Library *)library { 
  @synchronized(self) {
    Library *oldLibrary = library_;
    library_ = [library retain];
    [oldLibrary release];
  }
}

- (void)onGroupSelect:(id)sender { 
  [self selectBrowser:(MainWindowControllerBrowser)self.groupsButton.selectedSegment];
}

- (void)selectBrowser:(MainWindowControllerBrowser)idx { 
  if (idx == MainWindowControllerAlbumBrowser) {
    if (!self.albumBrowser) {
      self.albumBrowser = [[[AlbumBrowser alloc] initWithLibrary:SharedAppDelegate().library] autorelease];
    }
    self.content = self.albumBrowser;
  } else { 
    if (!self.trackBrowser) {
      self.trackBrowser = [[[TrackBrowser alloc] initWithLibrary:SharedAppDelegate().library] autorelease];
    }
    self.content = self.trackBrowser;
  }
  NSString *term = self.searchField.stringValue;
  if (term) { 
    [self.content search:term after:nil];
  }
  if (idx != self.groupsButton.selectedSegment)
    self.groupsButton.selectedSegment = idx;
}

- (void)onSearch:(id)sender { 
  [[NSApp delegate] search:[sender stringValue] after:nil];
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

  self.horizontalSplit = [[[SplitView alloc] initWithFrame:splitRect] autorelease];
  [self.horizontalSplit setDividerStyle:NSSplitViewDividerStyleThin];
  self.horizontalSplit.autoresizesSubviews = YES;
  self.horizontalSplit.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.horizontalSplit.vertical = NO;
  self.horizontalSplit.focusRingType = NSFocusRingTypeNone;
  [self.window.contentView addSubview:self.horizontalSplit];

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
  self.verticalSplit.dividerColor = [NSColor blackColor];
  self.verticalSplit.dividerThickness = 1;
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

- (void)setupLibrarySelect { 
  int w = 160;
  self.libraryPopUpButton = [[[ServicePopUpButton alloc] initWithFrame:CGRectMake(5, 3, w, 18)
    serviceTypes:[NSSet setWithObjects:kDaemonServiceType, nil]] autorelease];
  self.libraryPopUpButton.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
  NSButtonCell *buttonCell = (NSButtonCell *)[self.libraryPopUpButton cell];
  [buttonCell setFont:[NSFont systemFontOfSize:11.0]];
  [buttonCell setControlSize:NSSmallControlSize];
  [self.libraryPopUpButton appendItemWithTitle:@"Local Library" value:nil];
  self.libraryPopUpButton.onService = ^(id v) {
    SharedAppDelegate().library = !v ? SharedAppDelegate().localLibrary : [[[RemoteLibrary alloc] initWithNetService:v] autorelease];
    self.trackBrowser = nil;
    self.albumBrowser = nil;
    [self selectBrowser:(MainWindowControllerBrowser)self.groupsButton.selectedSegment];
  };
  [self.window.contentView addSubview:self.libraryPopUpButton];
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
        [SharedAppDelegate().audioSource seek:amt];
      };
    }
    view = self.progressControl.view;
    [item setMaxSize:NSMakeSize(1000, 22)];
    [item setMinSize:NSMakeSize(400, 22)];
  } else if (itemIdentifier == kGroupControl) {
    view = self.groupsButton;
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
         kVolumeControl, kProgressControl, kGroupControl, kSearchControl, nil];
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

