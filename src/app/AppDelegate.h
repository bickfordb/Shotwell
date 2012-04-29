#import <Cocoa/Cocoa.h>

#import "app/AppleCoverArtClient.h"
#import "app/Daemon.h"
#import "app/Library.h"
#import "app/LocalLibrary.h"
#import "app/Loop.h"
#import "app/Movie.h"
#import "app/Plugin.h"
#import "app/Track.h"
#import "app/MainWindowController.h"
#import "app/PreferencesWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate> {
  AppleCoverArtClient *appleCoverArtClient_;
  Daemon *daemon_;
  Library *library_;
  LocalLibrary *localLibrary_;
  Loop *loop_;
  Movie *movie_;
  NSSet *artists_;
  NSSet *albums_;
  NSMenuItem *addToLibraryMenuItem_;
  NSMenuItem *copyMenuItem_;
  NSMenuItem *cutMenuItem_;
  NSMenuItem *deleteMenuItem_;
  NSMenuItem *nextMenuItem_;
  NSMenuItem *pasteMenuItem_;
  NSMenuItem *playMenuItem_;
  NSMenuItem *prevMenuItem_;
  NSMenuItem *selectAllMenuItem_;
  NSMenuItem *selectNoneMenuItem_;
  NSMenuItem *stopMenuItem_;
  NSMutableArray *libraries_;
  NSMutableArray *plugins_;
  NSMutableArray *audioOutputs_;
  NSNetServiceBrowser *daemonBrowser_;
  NSNetServiceBrowser *raopServiceBrowser_;
  NSMutableDictionary *selectedAudioOutput_;
  NSMutableDictionary *selectedLibrary_;
  NSTimer *pollLibraryTimer_;
  NSTimer *pollMovieTimer_;
  MainWindowController *mainWindowController_;
  PreferencesWindowController *preferencesWindowController_;
  Track *track_;
  NSTimer *pollStatsTimer_;
}


- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices;
- (void)library:(Library *)l addedTrack:(Track *)t;
- (void)library:(Library *)l deletedTrack:(Track *)t;
- (void)library:(Library *)l savedTrack:(Track *)t;
- (void)loadCoverArt:(Track *)track;
- (void)playNextTrack;
- (void)playPreviousTrack;
- (void)playTrackAtIndex:(int)idx;
- (void)pollMovie;
- (void)pollServices;
- (void)pollStats;
- (void)setupDockIcon;
- (void)setupPlugins;
- (void)setupRAOP;
- (void)setupSharing;

@property (retain) AppleCoverArtClient *appleCoverArtClient;
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
@property (retain) NSMutableDictionary *selectedLibrary;
@property (retain) NSNetServiceBrowser *daemonBrowser;
@property (retain) NSNetServiceBrowser *raopServiceBrowser;
@property (retain) NSSet *albums;
@property (retain) NSSet *artists;
@property (retain) NSTimer *pollLibraryTimer;
@property (retain) NSTimer *pollMovieTimer;
@property (retain) NSTimer *pollStatsTimer;
@property (retain) PreferencesWindowController *preferencesWindowController;
@property (retain) Track *track;
@end

