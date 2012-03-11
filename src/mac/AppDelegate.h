#import <Cocoa/Cocoa.h>
#import "library.h"
#import "movie.h"
#import "MD1Slider.h"
#include <tr1/memory>
#include <vector>
#include <tr1/tuple>
#include "daemon.h"

using namespace std;
using namespace std::tr1;

typedef enum  {
  Ascending = 0,
  Descending = 1,
  NoDirection = 2// pointing at Eris
} Direction;

typedef tuple<NSString *, Direction> SortField;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate> {
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
  shared_ptr<Daemon> daemon_;
  NSNetService *netService_;
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
  NSMenuItem *cutMenuItem_;
  NSMenuItem *pasteMenuItem_;
  NSMenuItem *copyMenuItem_;
  NSMenuItem *deleteMenuItem_;
  NSMenuItem *playMenuItem_;
  NSMenuItem *stopMenuItem_;
  NSMenuItem *nextMenuItem_;
  NSMenuItem *prevMenuItem_;

  NSScrollView *trackTableScrollView_;
  NSSearchField *searchField_;
  NSToolbarItem *searchItem_;
  MD1Slider *progressSlider_;
  MD1Slider *volumeSlider_;
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
  shared_ptr<Library> library_;
  shared_ptr<Movie> movie_;
  shared_ptr<Track> track_;
  shared_ptr<vector<shared_ptr<Track> > > allTracks_;  
  shared_ptr<vector<shared_ptr<Track> > > tracks_;  
  NSString *searchQuery_;
  bool predicateChanged_;

}

@property (retain) NSString *searchQuery;

- (void)displayElapsed:(double)elapsed duration:(double)duration;
- (void)handleMovie:(Movie *)m event:(MovieEvent)event data:(void *)data;
- (void)playTrackAtIndex:(int)idx;
- (void)playNextTrack;
- (void)executeSearch;
- (void)updateTableColumnHeaders;
- (void)setupWindow;
- (void)setupTrackTable;
- (void)setupToolbar;
- (void)playPreviousTrack;

@end
