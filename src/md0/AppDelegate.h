#ifndef _APPDELEGATE_H_
#define _APPDELEGATE_H_

#import <Cocoa/Cocoa.h>

#import "md0/Library.h"
#import "md0/Movie.h"
#import "md0/Slider.h"
#import "md0/SplitView.h"
#import "md0/Daemon.h"
#import "md0/LocalLibrary.h"
#import "md0/Plugin.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate> {
  NSMutableArray *services_;
  NSMutableArray *plugins_;
  BOOL needsReload_; 
  BOOL sortChanged_;
  BOOL trackEnded_;
  BOOL requestPrevious_;
  BOOL requestClearSelection_;
  BOOL requestNext_;
  BOOL requestTogglePlay_;
  BOOL needsLibraryRefresh_;
  int seekToRow_;
  int64_t lastLibraryRefresh_;
  Daemon *daemon_;
  NSNetService *netService_;
  SplitView *contentVerticalSplit_;
  SplitView *contentHorizontalSplit_;
  NSNetServiceBrowser *raopServiceBrowser_;
  NSNetServiceBrowser *mdServiceBrowser_;
  NSMutableArray *sortFields_;
  NSFont *trackTableFont_;
  NSFont *trackTablePlayingFont_;
  NSImage *emptyImage_;
  NSImage *playImage_;
  NSImage *startImage_;
  NSImage *stopImage_;
  NSButton *nextButton_;
  NSButton *playButton_;
  NSButton *previousButton_;
  NSPopUpButton *audioOutputSelect_;
  NSPopUpButton *librarySelect_;
  NSMenuItem *addToLibraryMenuItem_;
  NSMenuItem *cutMenuItem_;
  NSMenuItem *pasteMenuItem_;
  NSMenuItem *copyMenuItem_;
  NSMenuItem *deleteMenuItem_;
  NSMenuItem *playMenuItem_;
  NSMenuItem *selectAllMenuItem_;
  NSMenuItem *selectNoneMenuItem_;
  NSMenuItem *stopMenuItem_;
  NSMenuItem *nextMenuItem_;
  NSMenuItem *prevMenuItem_;
  NSScrollView *trackTableScrollView_;
  NSSearchField *searchField_;
  NSToolbarItem *searchItem_;
  Slider *progressSlider_;
  Slider *volumeSlider_;
  NSTableView *trackTableView_;
  NSTextField *durationText_;
  NSTextField *elapsedText_;
  NSTimer *pollLibraryTimer_;
  NSTimer *pollMovieTimer_;
  NSToolbar *toolbar_;
  NSToolbarItem *nextButtonItem_;
  NSToolbarItem *playButtonItem_;
  NSToolbarItem *previousButtonItem_;
  NSToolbarItem *progressSliderItem_;
  NSView *contentView_;
  NSView *volumeControl_;
  NSToolbarItem *volumeItem_;
  NSWindow *mainWindow_;
  Library *library_;
  LocalLibrary *localLibrary_;
  Movie *movie_;
  NSDictionary *track_;
  NSMutableArray *allTracks_;
  NSMutableArray *tracks_;
  NSString *searchQuery_;
  bool predicateChanged_;

}

@property (retain) NSString *searchQuery;


- (NSSplitView *)contentVerticalSplit;
- (NSSplitView *)contentHorizontalSplit;
- (void)displayElapsed:(int64_t)elapsed duration:(int64_t)duration;
- (void)executeSearch;
- (void)playNextTrack;
- (void)playPreviousTrack;
- (void)playTrackAtIndex:(int)idx;
- (void)refreshAudioOutputList;
- (void)refreshLibraryList;
- (void)selectLocalAudio;
- (void)selectRemoteAudioHost:(NSString *)host port:(uint16_t)port;
- (void)setupAudioSelect;
- (void)setupDockIcon;
- (void)setupToolbar;
- (void)setupTrackTable;
- (void)setupWindow;
- (void)setupPlugins;
- (void)updateTableColumnHeaders;
- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices;
- (void)setVolume:(double)pct;
@end

#endif
