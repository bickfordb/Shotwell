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
static const int64_t kPollMovieInterval = 150000;
static const int64_t kPollServicesInterval = 5 * 1000000;
static const int64_t kPollStatsInterval = 10 * 1000000;

static NSString * const kGeneralPreferenceTab = @"GeneralPreferenceTab";

static NSString * const kRAOPServiceType = @"_raop._tcp.";
static NSString *LibraryDir();
static NSString *LibraryPath();

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

@implementation AppDelegate
@synthesize albums = albums_;
@synthesize appleCoverArtClient = appleCoverArtClient_;
@synthesize artists = artists_;
@synthesize audioOutputs = audioOutputs_;
@synthesize daemon = daemon_;
@synthesize daemonBrowser = daemonBrowser_;
@synthesize libraries = libraries_;
@synthesize localLibrary = localLibrary_;
@synthesize loop = loop_;
@synthesize mainWindowController = mainWindowController_;
@synthesize movie = movie_;
@synthesize plugins = plugins_;
@synthesize pollLibraryTimer = pollLibraryTimer_;
@synthesize pollMovieTimer = pollMovieTimer_;
@synthesize pollStatsTimer = pollStatsTimer_;
@synthesize preferencesWindowController = preferencesWindowController_;
@synthesize raopServiceBrowser = raopServiceBrowser_;
@synthesize selectedAudioOutput = selectedAudioOutput_;
@synthesize selectedLibrary = selectedLibrary_;
@synthesize track = track_;

- (void)dealloc { 
  [loop_ release];
  [albums_ release];
  [appleCoverArtClient_ release];
  [artists_ release];
  [daemon_ release];
  [daemonBrowser_ release];
  [libraries_ release];
  [localLibrary_ release];
  [mainWindowController_ release];
  [movie_ release];
  [plugins_ release];
  [pollLibraryTimer_ release];
  [pollMovieTimer_ release];
  [pollStatsTimer_ release];
  [preferencesWindowController_ release];
  [raopServiceBrowser_ release];
  [selectedAudioOutput_ release];
  [selectedLibrary_ release];
  [track_ release];
  [super dealloc];
}

- (void)search:(NSString *)term {
  /*
  ForkWith(^{
    self.trackBrowser.tracks.predicate = ParseSearchQuery(term);
    self.needsReload = true;
  });*/
  self.mainWindowController.searchField.stringValue = term;
  [self.mainWindowController.content search:term];
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
  i = [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  i.target = self;
  i = [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:[NSString stringWithFormat:@"%C", NSBackspaceCharacter]];
  [i setKeyEquivalentModifierMask:0];
  i.target = self;
  i = [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  i.target = self.mainWindowController.trackBrowser.tableView;
  i = [editMenu addItemWithTitle:@"Select None" action:@selector(selectNone:) keyEquivalent:@"A"];
  i.target = self.mainWindowController.trackBrowser.tableView;

  // File Menu
  i = [fileMenu addItemWithTitle:@"Add to Library" action:@selector(addToLibrary:) keyEquivalent:@"o"];
  i.target = self;

  NSMenuItem *appMenu = [mainMenu itemAtIndex:0];
  NSMenuItem *preferences = [appMenu.submenu 
    insertItemWithTitle:@"Preferences" action:@selector(makeKeyAndOrderFront:) 
    keyEquivalent:@"," 
    atIndex:1];
  preferences.target = self.preferencesWindowController.window;

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
  NSIndexSet *indices = [self.mainWindowController.trackBrowser.tableView selectedRowIndexes];
  ForkWith(^{
    [self cutTracksAtIndices:indices];  
  });
}

- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices { 
  NSArray *tracks = [self.mainWindowController.trackBrowser.tracks getMany:indices];
  for (Track *o in tracks) {
    [self.localLibrary delete:o];
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
    NSIndexSet *indices = [self.mainWindowController.trackBrowser.tableView selectedRowIndexes];
    NSUInteger i = [indices lastIndex];
    NSMutableArray *urls = [NSMutableArray array];
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
    for (Track *t in [self.mainWindowController.trackBrowser.tracks getMany:indices]) {
      NSURL *url = [NSURL fileURLWithPath:t.url];
      [urls addObject:url];
    }
    [pb writeObjects:urls];
  }
}

- (void)cut:(id)sender { 
  if (library_ != localLibrary_)
    return;

  @synchronized(self) { 
    NSIndexSet *indices = [self.mainWindowController.trackBrowser.tableView selectedRowIndexes];
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
    [pb writeObjects:urls];
  }
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

  self.appleCoverArtClient = [[[AppleCoverArtClient alloc] init] autorelease];
  self.localLibrary = [[[LocalLibrary alloc] initWithPath:LibraryPath()] autorelease];
  self.localLibrary.onScanPathsChange = ^{
    [self.preferencesWindowController.automaticPathsTable reload];
  };
  
  self.library = self.localLibrary;
  self.movie = nil;
  self.track = nil;

  [self setupSharing];
  [self setupRAOP]; 

  [self.localLibrary prune];
  [self setupMenu];
  self.preferencesWindowController = [[[PreferencesWindowController alloc] init] autorelease];
  self.mainWindowController = [[[MainWindowController alloc] init] autorelease];
  self.loop = [Loop loop];
  [self.loop every:kPollMovieInterval with:^{
    [weakSelf pollMovie];  
  }];

  [self.loop every:kPollStatsInterval with:^{
    [weakSelf pollStats];
  }];

  [self.loop every:kPollServicesInterval with:^{
    [weakSelf pollServices];
  }];

  [self setupPlugins];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

  [self.localLibrary checkITunesImport];
  [self.localLibrary checkAutomaticPaths];
}

- (void)setupRAOP { 
  self.raopServiceBrowser = [[[NSNetServiceBrowser alloc] init] autorelease];
  [raopServiceBrowser_ setDelegate:self];
  [raopServiceBrowser_ searchForServicesOfType:kRAOPServiceType inDomain:@"local."];
}

- (void)pollServices { 

}

- (void)pollStats {
  NSMutableSet *artists = [NSMutableSet set];
  NSMutableSet *albums = [NSMutableSet set];

  for (Track *t in self.mainWindowController.trackBrowser.tracks.array) {
    if (t.artist)
      [artists addObject:t.artist];
    if (t.album) 
      [albums addObject:t.album];
  }
  self.artists = artists;
  self.albums = albums;
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




- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
  [netService retain];
  [netService setDelegate:self];
  [netService resolveWithTimeout:10.0];
}

- (void)netServiceDidResolveAddress:(NSNetService *)netService {
//  NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
//    netService, @"service", 
//    netService.name, @"title", 
//    nil]; 
//  NSMutableArray *arr = nil;
//  if ([netService.type isEqualToString:kRAOPServiceType]) {
//    arr = self.audioOutputs;
//  } else { 
//    arr = self.libraries;
//    RemoteLibrary *remoteLibrary = [[[RemoteLibrary alloc] initWithNetService:netService] autorelease];
//    [d setObject:remoteLibrary forKey:@"library"];
//  }  
//
//  @synchronized(arr) {
//    if (![arr containsObject:d]) {
//      [arr addObject:d];
//    }
//  }
//  [self.mainWindowController refreshLibraryList];
//  [self.mainWindowController refreshAudioOutputList];
//  [netService release];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSMutableDictionary *)errorDict {
}


- (void)pollMovie { 
  /*
  int numTracks = 0;
  @synchronized (self.mainWindowController.trackBrowser.tracks) {
    numTracks = self.mainWindowController.trackBrowser.tracks.count;
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
    [self.mainWindowController.trackBrowser.tableView deselectAll:self];
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
    [self.mainWindowController.trackBrowser.tracks clear];
    [library_ each:^(Track *t) {
        [self.mainWindowController.trackBrowser.tracks add:t];
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
  */
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
  [self.mainWindowController.trackBrowser reload];
};

- (void)library:(Library *)l addedTrack:(Track *)t {
  if (l != library_)
    return;
  [self.mainWindowController.trackBrowser.tracks add:t];
  [self.mainWindowController.trackBrowser reload];
}

- (void)library:(Library *)l savedTrack:(Track *)t {
  if (l != library_) {
    DEBUG(@"other library");
    return;
  }
  [self.mainWindowController.trackBrowser.tracks remove:t];
  [self.mainWindowController.trackBrowser.tracks add:t];
  [self.mainWindowController.trackBrowser reload];
  @synchronized (plugins_) {
    for (Plugin *p in plugins_) {
      [p trackSaved:t];
    }
  }
}

- (void)library:(Library *)l deletedTrack:(Track *)t {
  if (l != library_)
    return;
  [self.mainWindowController.trackBrowser.tracks remove:t];
  [self.mainWindowController.trackBrowser reload];
}

- (void)onPollLibraryTimer:(id)sender { 
  [raopServiceBrowser_ searchForServicesOfType:kRAOPServiceType inDomain:@"local."];
  [self.daemonBrowser searchForServicesOfType:kDaemonServiceType inDomain:@"local."]; 
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
  self.track = [self.mainWindowController.trackBrowser.tracks get:index];
  NSNetService *netService = [self.selectedAudioOutput objectForKey:@"service"];

  self.movie = self.track ? [[[Movie alloc] initWithURL:self.track.url
    address:netService.ipv4Address port:netService.port] autorelease] : nil;
  self.movie.volume = self.mainWindowController.volumeControl.level;
  [self.movie start];

  [self.mainWindowController.trackBrowser seekTo:index];
  [self.mainWindowController.trackBrowser reload];
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
    for (Track *t in [self.mainWindowController.trackBrowser.tracks all]) {
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

/*
 * Play the next track.
 */
- (void)playNextTrack { 
  int idx = 0;
  int found = -1;
  if (movie_) {
    for (Track *t in self.mainWindowController.trackBrowser.tracks) {
      if ([t isEqual:track_]) {
        found = idx;
        break;
      }
      idx++;
    }
  } 
  [self playTrackAtIndex:found + 1];
}

- (void)playPreviousTrack { 
  int idx = 0;
  int found = -1;
  int req = 0;
  if (movie_) {
    for (Track *t in self.mainWindowController.trackBrowser.tracks) {
      if ([t isEqual:track_]) {
        found = idx;
        break;
      }
      idx++;
    }
    if (found > 0) 
      req = found - 1;
  } 
  [self playTrackAtIndex:req];
}

- (void)playClicked:(id)sender { 
  ForkWith(^{
    if (self.movie.state == kPlayingAudioSourceState) {
      [self.movie stop];
    } else if (self.movie.state == kPlayingAudioSourceState) { 
      [self.movie start];
    }
  });
}

- (void)nextClicked:(id)sender { 
  DEBUG(@"next clicked");
  ForkWith(^{
    [self playNextTrack];
  });
}

- (void)previousClicked:(id)sender { 
  DEBUG(@"previous clicked");
  ForkWith(^{
    [self playPreviousTrack];
  });
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

