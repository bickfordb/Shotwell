#include <locale>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/utsname.h>

#import "app/AppDelegate.h"
#import "app/AudioSource.h"
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
#import "app/TableView.h"

static NSString *AppSupportPath() {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory,
      NSUserDomainMask,
      YES);
  NSString *path = [paths objectAtIndex:0];
  path = [path stringByAppendingPathComponent:@"Shotwell"];
  mkdir(path.UTF8String, 0755);
  return path;
}

@implementation AppDelegate
@synthesize audioSink = audioSink_;
@synthesize daemon = daemon_;
@synthesize daemonBrowser = daemonBrowser_;
@synthesize localLibrary = localLibrary_;
@synthesize library = library_;
@synthesize mainWindowController = mainWindowController_;
@synthesize preferencesWindowController = preferencesWindowController_;
@synthesize track = track_;

- (void)dealloc {
  [[NSNotificationCenter defaultCenter]
    removeObserver:self];
  [daemon_ release];
  [daemonBrowser_ release];
  [library_ release];
  [localLibrary_ release];
  [mainWindowController_ release];
  [preferencesWindowController_ release];
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

- (void)die:(NSString *)message {
  NSAlert *alert = [NSAlert alertWithMessageText:@"An error occurred" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@"Need to exit: %@", message];
  [alert runModal];
  [[NSApplication sharedApplication] terminate:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)n {
  __block AppDelegate *weakSelf = self;
  self.audioSink = [[[CoreAudioSink alloc] init] autorelease];
  self.audioSink.onDone = ^{
    [weakSelf playNextTrack];
  };
  [self parseDefaults];
  self.localLibrary = [[[LocalLibrary alloc] initWithDBPath:[AppSupportPath() stringByAppendingPathComponent:@"db"]] autorelease];
  if (!self.localLibrary) {
    [self die:@"Unable to open local library."];

  }
  self.library = self.localLibrary;
  self.track = nil;

  [self setupSharing];
  [self.localLibrary prune];
  self.preferencesWindowController = [[[PreferencesWindowController alloc] initWithLocalLibrary:self.localLibrary] autorelease];
  self.mainWindowController = [[[MainWindowController alloc] init] autorelease];

  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  [self.localLibrary checkITunesImport];
  [self.localLibrary checkAutomaticPaths];
  [self.localLibrary checkCoverArt];
  [self.localLibrary checkAcoustIDs];
  [self setupMenu];
  [self.localLibrary each:^(Track *t) {
    if (!t.url) {
      ERROR(@"%@ is missing a URL", t);
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

- (void)playTrackAtIndex:(int)index {
  if (track_) {
    [self.mainWindowController trackEnded:track_];
    [[NSNotificationCenter defaultCenter]
      postNotificationName:kTrackEnded
      object:self
      userInfo:@{@"track": self.track}];
  }
  self.track = [self.mainWindowController.trackBrowser.tracks get:index];

  [self.mainWindowController trackStarted:track_];
  self.audioSink.audioSource = [[[LibAVSource alloc] initWithURL:self.track.url] autorelease];
  self.audioSink.isPaused = NO;
  self.audioSink.volume = self.mainWindowController.volumeControl.level;
  [self.mainWindowController.trackBrowser seekTo:index];
  [self.mainWindowController.trackBrowser reload];
  if (self.track.library == self.localLibrary) {
    self.track.lastPlayedAt = Now();
    self.track.updatedAt = Now();
    [self.localLibrary save:self.track];
  }
  if (track_) {
    [[NSNotificationCenter defaultCenter]
      postNotificationName:kTrackStarted
      object:self
      userInfo:@{@"track": track_}];
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
    if (!audioSink_.isDone) {
        audioSink_.isPaused = !audioSink_.isPaused;
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
