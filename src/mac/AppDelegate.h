#import <Cocoa/Cocoa.h>
#import "library.h"
#import "movie.h"
#import "MD1Slider.h"
#include <tr1/memory>
#include <vector>

using namespace std;
using namespace std::tr1;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate> {
  NSButton *nextButton_;
  NSButton *playButton_;
  NSButton *previousButton_;
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
  shared_ptr<vector<shared_ptr<Track> > > tracks_;  
}

- (void)displayElapsed:(double)elapsed duration:(double)duration;
- (void)handleMovie:(Movie *)m event:(MovieEvent)event data:(void *)data;
- (void)playTrackAtIndex:(int)idx;
- (void)playNextTrack;

@end
