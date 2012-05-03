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

static NSString * const kGeneralPreferenceTab = @"GeneralPreferenceTab";

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
@synthesize audioOutputs = audioOutputs_;
@synthesize daemon = daemon_;
@synthesize daemonBrowser = daemonBrowser_;
@synthesize libraries = libraries_;
@synthesize localLibrary = localLibrary_;
@synthesize loop = loop_;
@synthesize mainWindowController = mainWindowController_;
@synthesize movie = movie_;
@synthesize plugins = plugins_;
@synthesize preferencesWindowController = preferencesWindowController_;
@synthesize raopServiceBrowser = raopServiceBrowser_;
@synthesize selectedAudioOutput = selectedAudioOutput_;
@synthesize selectedLibrary = selectedLibrary_;
@synthesize track = track_;

- (void)dealloc { 
  [[NSNotificationCenter defaultCenter]
    removeObserver:self];
  [loop_ release];
  [daemon_ release];
  [daemonBrowser_ release];
  [libraries_ release];
  [localLibrary_ release];
  [mainWindowController_ release];
  [movie_ release];
  [plugins_ release];
  [preferencesWindowController_ release];
  [raopServiceBrowser_ release];
  [selectedAudioOutput_ release];
  [selectedLibrary_ release];
  [track_ release];
  [super dealloc];
}

- (void)search:(NSString *)term {
  ForkWith(^{
    [self.mainWindowController search:term];
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
  NSMenuItem *i = nil;
  i = [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
  i = [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
  i = [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
  i = [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:[NSString stringWithFormat:@"%C", NSBackspaceCharacter]];
  [i setKeyEquivalentModifierMask:0];
  i = [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
  i = [editMenu addItemWithTitle:@"Select None" action:@selector(deselectAll:) keyEquivalent:@"A"];

  // File Menu
  i = [fileMenu addItemWithTitle:@"Add to Library" action:@selector(addToLibrary:) keyEquivalent:@"o"];

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

- (void)paste:(id)sender { 
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
  self.localLibrary = [[[LocalLibrary alloc] initWithDBPath:LibraryPath() coverArtPath:CoverArtPath()] autorelease];
  self.library = self.localLibrary;
  self.movie = nil;
  self.track = nil;

  [self setupSharing];
  [self.localLibrary prune];
  self.preferencesWindowController = [[[PreferencesWindowController alloc] initWithLocalLibrary:self.localLibrary] autorelease];
  self.mainWindowController = [[[MainWindowController alloc] init] autorelease];
  self.loop = [Loop loop];
  [self.loop every:kPollMovieInterval with:^{
    [weakSelf pollMovie];  
  }];

  [self setupPlugins];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  [self.localLibrary checkITunesImport];
  [self.localLibrary checkAutomaticPaths];
  [self setupMenu];
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



- (void)pollMovie { 
  if (movie_ && ([movie_ state] == kEOFAudioSourceState)) {
    [self playNextTrack];
    return;
  }
}

- (Library *)library { 
  return library_;
}

- (void)setLibrary:(Library *)library { 
  @synchronized(self) {
    if (library_) { 
      [[NSNotificationCenter defaultCenter] removeObserver:self name:kLibraryTrackChanged object:library_];
    }
    Library *o = library_;
    library_ = [library retain];
    [o autorelease];
  }
  if (library) { 
    [[NSNotificationCenter defaultCenter]
      addObserver:self 
      selector:@selector(onTrackChange:)
      name:kLibraryTrackChanged
      object:library];
  }
};

- (void)onTrackChange:(NSNotification *)notification {
  NSDictionary *userInfo = notification.userInfo;
  NSString *change = [userInfo valueForKey:@"change"];
  Track *t = [userInfo valueForKey:@"track"];
  @synchronized (plugins_) {
    for (Plugin *p in plugins_) {
      if (change == kLibraryTrackAdded) {
        [p trackAdded:t];
      } else if (change == kLibraryTrackSaved) {
        [p trackSaved:t];
      } else if (change == kLibraryTrackDeleted) {
        [p trackDeleted:t];
      }
    }
  }
}

- (void)playTrackAtIndex:(int)index {
  if (movie_) {
    [movie_ stop];
    @synchronized (plugins_) {
      for (Plugin *p in plugins_) {
        [p trackEnded:track_];
      }
    }
    [self.mainWindowController trackEnded:track_];
  }
  self.track = [self.mainWindowController.trackBrowser.tracks get:index];
  [self.mainWindowController trackStarted:track_];
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
}

/*
 * Play the next track.
 */
- (void)playNextTrack { 
  IgnoreSigPIPE();
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
  });
}

- (void)nextClicked:(id)sender { 
  ForkWith(^{
    [self playNextTrack];
  });
}

- (void)previousClicked:(id)sender { 
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

AppDelegate *SharedAppDelegate() {
  return (AppDelegate *)[NSApp delegate];
}
