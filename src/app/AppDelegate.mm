#include <locale>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/utsname.h>

#import "app/AppDelegate.h"
#import "app/CoreAudioSink.h"
#import "app/LibAVSource.h"
#import "app/Log.h"
#import "app/NSNetServiceAddress.h"
#import "app/NSNumberTimeFormat.h"
#import "app/NSMutableArrayInsert.h"
#import "app/NSStringDigest.h"
#import "app/Pthread.h"
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
  path = [path stringByAppendingPathComponent:@"Shotwell"];
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
@synthesize audioSink = audioSink_;
@synthesize audioOutputs = audioOutputs_;
@synthesize daemon = daemon_;
@synthesize daemonBrowser = daemonBrowser_;
@synthesize libraries = libraries_;
@synthesize localLibrary = localLibrary_;
@synthesize loop = loop_;
@synthesize mainWindowController = mainWindowController_;
@synthesize audioSource = audioSource_;
@synthesize plugins = plugins_;
@synthesize preferencesWindowController = preferencesWindowController_;
@synthesize raopServiceBrowser = raopServiceBrowser_;
@synthesize selectedAudioOutput = selectedAudioOutput_;
@synthesize track = track_;

- (void)dealloc {
  [[NSNotificationCenter defaultCenter]
    removeObserver:self];
  [loop_ release];
  [daemon_ release];
  [daemonBrowser_ release];
  [library_ release];
  [libraries_ release];
  [localLibrary_ release];
  [mainWindowController_ release];
  [audioSource_ release];
  [plugins_ release];
  [preferencesWindowController_ release];
  [raopServiceBrowser_ release];
  [selectedAudioOutput_ release];
  [track_ release];
  [super dealloc];
}

- (void)search:(NSString *)term after:(On0)after {
  after = [after copy];
  ForkWith(^{
    [self.mainWindowController search:term after:after];
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
  i = [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:[NSString stringWithFormat:@"%C", (unsigned short)NSBackspaceCharacter]];
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
  [localLibrary_ scan:paths];
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
  if (paths.count > 0)
    [localLibrary_ scan:paths];
}




- (void)parseDefaults {
  [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"WebKitDeveloperExtras"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
  __block AppDelegate *weakSelf = self;
  self.audioSink = [[[CoreAudioSink alloc] init] autorelease];
  [self parseDefaults];
  self.audioOutputs = [NSMutableArray array];
  self.libraries = [NSMutableArray array];
  self.localLibrary = [[[LocalLibrary alloc] initWithDBPath:LibraryPath() coverArtPath:CoverArtPath()] autorelease];
  self.library = self.localLibrary;
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
  [self.localLibrary checkCoverArt];
  [self setupMenu];
  [self.localLibrary each:^(Track *t) {
    if (!t.url) {
      ERROR(@"%@ is missing a URL");
    }
  }];
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
  if (audioSource_ && ([audioSource_ state] == kEOFAudioSourceState)) {
    [self playNextTrack];
    return;
  }
}

- (Library *)library {
  return library_;
}

- (void)setLibrary:(Library *)library {
  @synchronized(self) {
    Library *last = library_;
    if (last) {
      [[NSNotificationCenter defaultCenter] removeObserver:self name:kLibraryTrackChanged object:last];
    }
    library_ = [library retain];
    [last release];
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
  if (audioSource_) {
    audioSource_.isPaused = true;
    @synchronized (plugins_) {
      for (Plugin *p in plugins_) {
        [p trackEnded:track_];
      }
    }
    [self.mainWindowController trackEnded:track_];
  }
  self.track = [self.mainWindowController.trackBrowser.tracks get:index];
  [self.mainWindowController trackStarted:track_];
  self.audioSource = [[[LibAVSource alloc] initWithURL:self.track.url] autorelease];
  self.audioSource.isPaused = false;
  self.audioSink.audioSource = self.audioSource;
  if (self.audioSink.isPaused)
    self.audioSink.isPaused = false;
  self.audioSink.volume = self.mainWindowController.volumeControl.level;
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
  int found = -1;
  if (track_) {
    found = IndexOf(self.mainWindowController.trackBrowser.tracks, track_);
  }
  [self playTrackAtIndex:found + 1];
}

- (void)playPreviousTrack {
  int found = 0;
  if (track_) {
    found = IndexOf(self.mainWindowController.trackBrowser.tracks, track_);
  }
  if (found > 0) {
    [self playTrackAtIndex:found - 1];
  }
}

- (void)playClicked:(id)sender {
  ForkWith(^{
    if (audioSource_) {
        bool playing = audioSource_.state == kPlayingAudioSourceState;
        if (playing) {
          audioSource_.isPaused = true;
        } else {
          audioSource_.isPaused = false;
        }
      } else {
        [self playNextTrack];
      }
  });
}

- (void)playbackControlsClicked:(id)sender {
  NSSegmentedControl *c = (NSSegmentedControl *)sender;
  long idx = c.selectedSegment;
  if (idx == 0) {
    [self previousClicked:sender];
  } else if (idx == 1) {
    [self playClicked:sender];
  } else if (idx == 2) {
    [self nextClicked:sender];
  }
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
