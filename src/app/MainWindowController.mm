#import "app/AppDelegate.h"
#import "app/AudioSource.h"
#import "app/CoreAudioSink.h"
#import "app/Log.h"
#import "app/MainWindowController.h"
#import "app/NSNetServiceAddress.h"
#import "app/PThread.h"
#import "app/RemoteLibrary.h"

static NSString * const kArtistIconName = @"NSEveryone";
static NSString * const kAlbumIconName = @"album-icon";
static NSString * const kTrackIconName = @"NSActionTemplate";
static NSString * const kRemoteLibraryIconName = @"NSNetwork";
static NSString * const kNetworkIconName = @"NSNetwork";
static NSString * const kLocalLibraryIconName = @"NSComputer";
static NSString * const kNextButton = @"NextButton";
static NSString * const kPlayButton = @"PlayButton";
static NSString * const kPreviousButton = @"PreviousButton";
static NSString * const kProgressControl = @"ProgressControl";
static CGRect kStartupFrame = {{50, 200}, {1300, 650}};
static int64_t kPollMovieInterval = 100000;
static int64_t kPollProgressInterval = 500000;
static NSString * const kDefaultWindowTitle = @"Shotwell";
static NSString * const kSearchControl = @"SearchControl";
static const int kBottomEdgeMargin = 25;
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
@synthesize libraryServiceBrowser = libraryServiceBrowser_;
@synthesize loop = loop_;
@synthesize playbackControls = playbackControls_;
@synthesize playImage = playImage_;
@synthesize progressControl = progressControl_;
@synthesize progressIndicator = progressIndicator_;
@synthesize searchField = searchField_;
@synthesize startImage = startImage_;
@synthesize statusBarText = statusBarText_;
@synthesize stopImage = stopImage_;
@synthesize trackBrowser = trackBrowser_;
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
    __block MainWindowController *weakSelf = self;
    [loop_ every:kPollMovieInterval with:^{
      id <AudioSink> sink = SharedAppDelegate().audioSink;
      NSImage *playImage = nil;
      if (sink) {
        if (!sink.isSeeking) {
          weakSelf.progressControl.isEnabled = true;
          weakSelf.progressControl.duration = sink.duration;
          weakSelf.progressControl.elapsed = sink.elapsed;
        }
        playImage = sink.audioSource.state == kPlayingAudioSourceState ? stopImage_ : startImage_;
        weakSelf.volumeControl.level = SharedAppDelegate().audioSink.volume;
      } else {
        weakSelf.progressControl.duration = 0;
        weakSelf.progressControl.elapsed = 0;
        weakSelf.progressControl.isEnabled = false;
        playImage = startImage_;
      }
      [self.playbackControls setImage:playImage forSegment:1];
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
  NSLog(@"noticed remote library service: %@", svc);
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
  [loop_ release];
  [playImage_ release];
  [playbackControls_ release];
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
  ForkToMainWith(^{
    Library *library = SharedAppDelegate().library;
    INFO(@"library: %@", library);
    if (idx == MainWindowControllerAlbumBrowser) {
      if (!self.albumBrowser || self.albumBrowser.library != library) {
        self.albumBrowser = [[[CoverBrowser alloc]
                               initWithLibrary:library
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
    } else if (idx == MainWindowControllerCondensedBrowser) {
      //self.content = [[[CondensedView alloc] init] autorelease];
    } else {
      if (!self.trackBrowser || self.trackBrowser.library != library) {
        self.trackBrowser = [[[TrackBrowser alloc] initWithLibrary:library] autorelease];
      }
      self.content = self.trackBrowser;
    }
    NSString *last = self.content.lastSearch;
    self.searchField.stringValue = last ? last : @"";
  });
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

  navSplit_ = [[[SplitView alloc] initWithFrame:splitRect] autorelease];
  [navSplit_ setDividerStyle:NSSplitViewDividerStyleThin];
  navSplit_.autoresizesSubviews = YES;
  navSplit_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  navSplit_.vertical = YES;
  navSplit_.focusRingType = NSFocusRingTypeNone;
  navSplit_.dividerColor = [NSColor grayColor];
  navSplit_.dividerThickness = 1.0;
  [self.window.contentView addSubview:navSplit_];


  self.contentView = [[[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)] autorelease];
  self.contentView.autoresizesSubviews = YES;
  self.contentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.contentView.focusRingType = NSFocusRingTypeNone;

  verticalSplit_ = [[SplitView alloc] initWithFrame:splitRect];
  [verticalSplit_ setDividerStyle:NSSplitViewDividerStyleThin];
  verticalSplit_.autoresizesSubviews = YES;
  verticalSplit_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  verticalSplit_.focusRingType = NSFocusRingTypeNone;
  verticalSplit_.vertical = NO;
  verticalSplit_.dividerColor = [NSColor grayColor];
  verticalSplit_.dividerThickness = 1.0;
  [verticalSplit_ addSubview:self.contentView];
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
  self.audioOutputPopUpButton = [[[ServicePopUpButton alloc] initWithFrame:CGRectMake(x, 2, w, 18)] autorelease];
  self.audioOutputPopUpButton.onService = ^(id v) {
    NSDictionary *item = (NSDictionary *)v;
    INFO(@"set output to: %@", item);
    [SharedAppDelegate().audioSink setOutputDeviceID:item[@"id"]];
  };
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
      self.playbackControls = [[[NSSegmentedControl alloc] initWithFrame:CGRectMake(0, 0, 130, 22)] autorelease];
      self.playbackControls.segmentCount = 3;
      [[self.playbackControls cell] setTrackingMode:NSSegmentSwitchTrackingMomentary];
      self.playbackControls.segmentStyle = NSSegmentStyleTexturedRounded;
      [self.playbackControls setImage:[NSImage imageNamed:@"left"] forSegment:0];
      [self.playbackControls setImageScaling:NSImageScaleProportionallyUpOrDown forSegment:0];
      [self.playbackControls setImage:self.startImage forSegment:1];
      [self.playbackControls setImageScaling:NSImageScaleProportionallyUpOrDown forSegment:1];
      [self.playbackControls setImage:[NSImage imageNamed:@"right"] forSegment:2];
      [self.playbackControls setImageScaling:NSImageScaleProportionallyUpOrDown forSegment:2];
      [self.playbackControls sizeToFit];
      view = self.playbackControls;
      self.playbackControls.action = @selector(playbackControlsClicked:);
      self.playbackControls.target = SharedAppDelegate();
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

- (void)trackStarted:(Track *)track {
  self.window.title = GetWindowTitle(track);
  [self.content reload];
}

- (void)trackEnded:(Track *)track {
  self.window.title = kDefaultWindowTitle;
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
  self.statusBarText.stringValue = [NSString stringWithFormat:@"%d Tracks, %d Artists, %d Albums", i, (int)self.artists.count, (int)self.albums.count];
}
@end

