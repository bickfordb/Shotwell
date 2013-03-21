#include <locale>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/utsname.h>

#import "AppDelegate.h"
#import "AudioSink.h"
#import "AudioSource.h"
#import "CoreAudioSink.h"
#import "Daemon.h"
#import "DaemonBrowser.h"
#import "LibAVSource.h"
#import "Library.h"
#import "LocalLibrary.h"
#import "Log.h"
#import "MainWindowController.h"
#import "NSMutableArrayInsert.h"
#import "NSNetServiceAddress.h"
#import "NSNumberTimeFormat.h"
#import "NSStringDigest.h"
#import "PreferencesWindowController.h"
#import "Pthread.h"
#import "RemoteLibrary.h"
#import "Signals.h"
#import "TableView.h"
#import "Types.h"
#import "Util.h"

@interface AppDelegate (Private)
- (void)playNextTrack;
- (void)playPreviousTrack;
- (void)playTrackAtIndex:(int)idx;
- (void)setupSharing;
- (void)playClicked:(id)sender;
- (void)nextClicked:(id)sender;
- (void)previousClicked:(id)sender;
- (void)search:(NSString *)term after:(On0)after;
@end

@implementation AppDelegate

- (void)search:(NSString *)term after:(On0)after {
  after = [after copy];
  ForkWith(^{
    [[MainWindowController shared] search:term after:after];
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
  preferences.target = [PreferencesWindowController shared].window;

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
  [self parseDefaults];
  ;
  if (![LocalLibrary shared]) {
    [self die:@"Unable to open local library."];
  }
  if (![Daemon shared]) {
    [self die:@"Unable to setup daemon."];
  }
  if (![DaemonBrowser shared]) {
    [self die:@"Unable to setup daemon browser."];

  }
  [[LocalLibrary shared] prune];
  [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
  [[LocalLibrary shared] checkITunesImport];
  [[LocalLibrary shared] checkAutomaticPaths];
  [self setupMenu];
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
  self.audioSink.audioSource = [[[LibAVSource alloc] initWithURL:self.track[kTrackURL]] autorelease];
  self.audioSink.isPaused = NO;
  self.audioSink.volume = self.mainWindowController.volumeControl.level;
  [self.mainWindowController.trackBrowser seekTo:index];
  [self.mainWindowController.trackBrowser reload];
  self.track[kTrackLastPlayedAt] = [NSDate date];
  self.track[kTrackLibrary][self.track[kTrackID]] = self.track;
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

+ (AppDelegate *)shared {
  return (AppDelegate *)[NSApp delegate];
}
@end
