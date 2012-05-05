#import <Cocoa/Cocoa.h>

#import "app/Daemon.h"
#import "app/Library.h"
#import "app/LocalLibrary.h"
#import "app/Loop.h"
#import "app/MainWindowController.h"
#import "app/Movie.h"
#import "app/Plugin.h"
#import "app/PreferencesWindowController.h"
#import "app/Track.h"
#import "app/Types.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
  Daemon *daemon_;
  Library *library_;
  LocalLibrary *localLibrary_;
  Loop *loop_;
  Movie *movie_;
  NSMenuItem *stopMenuItem_;
  NSMutableArray *libraries_;
  NSMutableArray *plugins_;
  NSMutableArray *audioOutputs_;
  NSNetServiceBrowser *daemonBrowser_;
  NSNetServiceBrowser *raopServiceBrowser_;
  NSMutableDictionary *selectedAudioOutput_;
  MainWindowController *mainWindowController_;
  PreferencesWindowController *preferencesWindowController_;
  Track *track_;
}


//- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices;
- (void)playNextTrack;
- (void)playPreviousTrack;
- (void)playTrackAtIndex:(int)idx;
- (void)pollMovie;
//- (void)pollStats;
- (void)setupDockIcon;
- (void)setupPlugins;
- (void)setupSharing;
- (void)playClicked:(id)sender;
- (void)nextClicked:(id)sender;
- (void)previousClicked:(id)sender;

@property (retain) Daemon *daemon;
@property (retain) Library *library;
@property (retain) LocalLibrary *localLibrary;
@property (retain) Loop *loop;
@property (retain) MainWindowController *mainWindowController;
@property (retain) Movie *movie;
@property (retain) NSMutableArray *audioOutputs;
@property (retain) NSMutableArray *libraries;
@property (retain) NSMutableArray *plugins;
@property (retain) NSMutableDictionary *selectedAudioOutput;
@property (retain) NSNetServiceBrowser *daemonBrowser;
@property (retain) NSNetServiceBrowser *raopServiceBrowser;
@property (retain) PreferencesWindowController *preferencesWindowController;
@property (retain) Track *track;
- (void)search:(NSString *)term after:(On0)after;
@end

AppDelegate *SharedAppDelegate();


