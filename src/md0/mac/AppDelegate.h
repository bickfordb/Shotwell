#ifndef _APPDELEGATE_H_
#define _APPDELEGATE_H_

#import <Cocoa/Cocoa.h>
#include <set>
#include <tr1/memory>
#include <tr1/tuple>
#include <vector>
#include "md0/lib/library.h"
#include "md0/lib/movie.h"
#include "md0/mac/Slider.h"
#include "md0/mac/Service.h"
#include "md0/lib/daemon.h"
#include "md0/lib/local_library.h"
#include "md0/mac/Plugin.h"

using namespace md0;
using namespace std;
using namespace std::tr1;

typedef enum  {
  Ascending = 0,
  Descending = 1,
  NoDirection = 2// pointing at Eris
} Direction;

typedef tuple<NSString *, Direction> SortField;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate> {
  set<md0::Service> services_;
  //vector<md0::Plugin> plugins_;
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
  long double lastLibraryRefresh_;
  Daemon *daemon_;
  NSNetService *netService_;
  NSSplitView *contentVerticalSplit_;
  NSNetServiceBrowser *raopServiceBrowser_;
  NSNetServiceBrowser *mdServiceBrowser_;
  vector<SortField> sortFields_;
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
  md0::movie::Movie *movie_;
  Track track_;
  vector<Track> allTracks_;  
  vector<Track> tracks_;  
  NSString *searchQuery_;
  bool predicateChanged_;

}

@property (retain) NSString *searchQuery;

- (void)displayElapsed:(double)elapsed duration:(double)duration;
- (void)executeSearch;
- (void)handleMovie:(md0::movie::Movie *)m event:(md0::movie::MovieEvent)event data:(void *)data;
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
@end

#endif
