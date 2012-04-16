#ifndef _APPDELEGATE_H_
#define _APPDELEGATE_H_

#import <Cocoa/Cocoa.h>

#import "md0/AppleCoverArtClient.h"
#import "md0/Daemon.h"
#import "md0/Library.h"
#import "md0/LocalLibrary.h"
#import "md0/Movie.h"
#import "md0/Plugin.h"
#import "md0/Slider.h"
#import "md0/SortField.h"
#import "md0/SplitView.h"
#import "md0/Track.h"
#import "md0/Plugin.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate> {
  AppleCoverArtClient *appleCoverArtClient_;
  BOOL needsLibraryRefresh_;
  BOOL needsReload_; 
  BOOL requestClearSelection_;
  BOOL requestNext_;
  BOOL requestPrevious_;
  BOOL requestTogglePlay_;
  BOOL sortChanged_;
  BOOL trackEnded_;
  Daemon *daemon_;
  Library *library_;
  LocalLibrary *localLibrary_;
  Movie *movie_;
  NSButton *nextButton_;
  NSButton *playButton_;
  NSButton *previousButton_;
  NSFont *trackTableFont_;
  NSFont *trackTablePlayingFont_;
  NSImage *emptyImage_;
  NSImage *playImage_;
  NSImage *startImage_;
  NSImage *stopImage_;
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
  NSMutableArray *allTracks_;
  NSMutableArray *libraries_;
  NSMutableArray *plugins_;
  NSMutableArray *audioOutputs_;
  NSMutableArray *sortFields_;
  NSMutableArray *tracks_;
  NSNetService *netService_;
  NSNetServiceBrowser *mdServiceBrowser_;
  NSNetServiceBrowser *raopServiceBrowser_;
  NSPopUpButton *audioOutputPopUp_;
  NSPopUpButton *libraryPopUp_;
  NSMutableDictionary *selectedAudioOutput_;
  NSMutableDictionary *selectedLibrary_;
  NSScrollView *trackTableScrollView_;
  NSSearchField *searchField_;
  NSString *searchQuery_;
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
  NSToolbarItem *searchItem_;
  NSToolbarItem *volumeItem_;
  NSView *contentView_;
  NSView *volumeControl_;
  NSWindow *mainWindow_;
  Slider *progressSlider_;
  Slider *volumeSlider_;
  SplitView *contentHorizontalSplit_;
  SplitView *contentVerticalSplit_;
  Track *track_;
  bool predicateChanged_;
  int requestPlayTrackAtIndex_;
  int seekToRow_;
  int64_t lastLibraryRefresh_;
}

@property (retain) AppleCoverArtClient *appleCoverArtClient;
@property (retain) Daemon *daemon;
@property (retain) Library *library;
@property (retain) LocalLibrary *localLibrary;
@property (retain) Movie *movie;
@property (retain) NSButton *nextButton;
@property (retain) NSButton *playButton;
@property (retain) NSButton *previousButton;
@property (retain) NSFont *trackTableFont;
@property (retain) NSFont *trackTablePlayingFont;
@property (retain) NSImage *emptyImage;
@property (retain) NSImage *playImage;
@property (retain) NSImage *startImage;
@property (retain) NSImage *stopImage;
@property (retain) NSMenuItem *addToLibraryMenuItem;
@property (retain) NSMenuItem *copyMenuItem;
@property (retain) NSMenuItem *cutMenuItem;
@property (retain) NSMenuItem *deleteMenuItem;
@property (retain) NSMenuItem *nextMenuItem;
@property (retain) NSMenuItem *pasteMenuItem;
@property (retain) NSMenuItem *playMenuItem;
@property (retain) NSMenuItem *prevMenuItem;
@property (retain) NSMenuItem *selectAllMenuItem;
@property (retain) NSMenuItem *selectNoneMenuItem;
@property (retain) NSMenuItem *stopMenuItem;
@property (retain) NSMutableArray *allTracks;
@property (retain) NSMutableArray *libraries;
@property (retain) NSMutableArray *plugins;
@property (retain) NSMutableArray *audioOutputs;
@property (retain) NSMutableArray *sortFields;
@property (retain) NSMutableArray *tracks;
@property (retain) NSNetService *netService;
@property (retain) NSNetServiceBrowser *mdServiceBrowser;
@property (retain) NSNetServiceBrowser *raopServiceBrowser;
@property (retain) NSPopUpButton *audioOutputPopUp;
@property (retain) NSPopUpButton *libraryPopUp;
@property (retain) NSMutableDictionary *selectedAudioOutput;
@property (retain) NSMutableDictionary *selectedLibrary;
@property (retain) NSScrollView *trackTableScrollView;
@property (retain) NSSearchField *searchField;
@property (retain) NSString *searchQuery;
@property (retain) NSTableView *trackTableView;
@property (retain) NSTextField *durationText;
@property (retain) NSTextField *elapsedText;
@property (retain) NSTimer *pollLibraryTimer;
@property (retain) NSTimer *pollMovieTimer;
@property (retain) NSToolbar *toolbar;
@property (retain) NSToolbarItem *nextButtonItem;
@property (retain) NSToolbarItem *playButtonItem;
@property (retain) NSToolbarItem *previousButtonItem;
@property (retain) NSToolbarItem *progressSliderItem;
@property (retain) NSToolbarItem *searchItem;
@property (retain) NSToolbarItem *volumeItem;
@property (retain) NSView *contentView;
@property (retain) NSView *volumeControl;
@property (retain) NSWindow *mainWindow;
@property (retain) Slider *progressSlider;
@property (retain) Slider *volumeSlider;
@property (retain) SplitView *contentHorizontalSplit;
@property (retain) SplitView *contentVerticalSplit;
@property (retain) Track *track;
@property BOOL needsLibraryRefresh;
@property BOOL needsReload; 
@property BOOL requestClearSelection;
@property BOOL requestNext;
@property BOOL requestPrevious;
@property BOOL requestTogglePlay;
@property BOOL sortChanged;
@property BOOL trackEnded;
@property bool predicateChanged;
@property int requestPlayTrackAtIndex;
@property int seekToRow;
@property int64_t lastLibraryRefresh;

- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices;
- (void)displayElapsed:(int64_t)elapsed duration:(int64_t)duration;
- (void)executeSearch;
- (void)playNextTrack;
- (void)playPreviousTrack;
- (void)playTrackAtIndex:(int)idx;
- (void)refreshAudioOutputList;
- (void)refreshLibraryList;
- (void)search:(NSString *)query;
- (void)setVolume:(double)pct;
- (void)setupAudioSelect;
- (void)setupDockIcon;
- (void)setupPlugins;
- (void)setupRAOP;
- (void)setupSharing;
- (void)setupToolbar;
- (void)setupTrackTable;
- (void)setupWindow;
- (void)updateTableColumnHeaders;
- (void)loadCoverArt:(Track *)track;
@end

#endif
