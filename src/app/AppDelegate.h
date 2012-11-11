#import <Cocoa/Cocoa.h>

#import "app/AudioSink.h"
#import "app/Daemon.h"
#import "app/Library.h"
#import "app/LocalLibrary.h"
#import "app/Loop.h"
#import "app/MainWindowController.h"
#import "app/PreferencesWindowController.h"
#import "app/Track.h"
#import "app/Types.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
  Daemon *daemon_;
  Library *library_;
  LocalLibrary *localLibrary_;
  id <AudioSink> audioSink_;
  NSNetServiceBrowser *daemonBrowser_;
  MainWindowController *mainWindowController_;
  PreferencesWindowController *preferencesWindowController_;
  Track *track_;
}

- (void)playNextTrack;
- (void)playPreviousTrack;
- (void)playTrackAtIndex:(int)idx;
- (void)setupSharing;
- (void)playClicked:(id)sender;
- (void)nextClicked:(id)sender;
- (void)previousClicked:(id)sender;

@property (retain) id <AudioSink> audioSink;
@property (retain) Daemon *daemon;
@property (retain) Library *library;
@property (retain) LocalLibrary *localLibrary;
@property (retain) MainWindowController *mainWindowController;
@property (retain) NSMutableArray *libraries;
@property (retain) NSNetServiceBrowser *daemonBrowser;
@property (retain) PreferencesWindowController *preferencesWindowController;
@property (retain) Track *track;
- (void)search:(NSString *)term after:(On0)after;
@end

AppDelegate *SharedAppDelegate();


