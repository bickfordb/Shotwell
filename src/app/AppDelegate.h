#import <Cocoa/Cocoa.h>

#import "app/AppleCoverArtClient.h"
#import "app/Daemon.h"
#import "app/Library.h"
#import "app/LocalLibrary.h"
#import "app/Movie.h"
#import "app/Plugin.h"
#import "app/ProgressControl.h"
#import "app/Slider.h"
#import "app/SortField.h"
#import "app/SortedSeq.h"
#import "app/SplitView.h"
#import "app/TableView.h"
#import "app/Track.h"
#import "app/VolumeControl.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate> {
  AppleCoverArtClient *appleCoverArtClient_;
  bool needsReload_; 
  bool needsLibraryRefresh_;
  bool requestClearSelection_;
  bool requestNext_;
  bool requestPrevious_;
  bool requestTogglePlay_;
  bool requestReloadPathsTable_;
  bool trackEnded_;
  Daemon *daemon_;
  Library *library_;
  LocalLibrary *localLibrary_;
  Movie *movie_;
  NSSet *artists_;
  NSSet *albums_;
  NSButton *nextButton_;
  NSButton *playButton_;
  NSButton *previousButton_;
  ProgressControl *progressControl_;
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
  SortedSeq *tracks_;
  NSMutableArray *libraries_;
  NSMutableArray *plugins_;
  NSMutableArray *audioOutputs_;
  NSMutableArray *sortFields_;
  NSNetServiceBrowser *daemonBrowser_;
  NSNetServiceBrowser *raopServiceBrowser_;
  NSPopUpButton *audioOutputPopUp_;
  NSPopUpButton *libraryPopUp_;
  NSMutableDictionary *selectedAudioOutput_;
  NSMutableDictionary *selectedLibrary_;
  NSSearchField *searchField_;
  TableView *trackTableView_;
  TableView *scanPathsTableView_;
  NSButton *automaticallyScanPathsButton_;
  NSTextField *statusBarText_;
  NSTimer *pollLibraryTimer_;
  NSTimer *pollMovieTimer_;
  NSToolbar *preferenceToolbar_;
  NSToolbarItem *nextButtonItem_;
  NSToolbarItem *playButtonItem_;
  NSToolbarItem *previousButtonItem_;
  NSToolbarItem *progressSliderItem_;
  NSToolbarItem *searchItem_;
  NSToolbarItem *volumeItem_;
  NSView *contentView_;
  NSWindow *mainWindow_;
  NSWindow *preferencesWindow_;
  Slider *progressSlider_;
  VolumeControl *volumeControl_;
  SplitView *contentHorizontalSplit_;
  SplitView *contentVerticalSplit_;
  Track *track_;
  bool predicateChanged_;
  int requestPlayTrackAtIndex_;
  int seekToRow_;
  NSTimer *pollStatsTimer_;
}

@property (retain) AppleCoverArtClient *appleCoverArtClient;
@property (retain) ProgressControl *progressControl;
@property (retain) Daemon *daemon;
@property (retain) Library *library;
@property (retain) LocalLibrary *localLibrary;
@property (retain) Movie *movie;
@property (retain) NSButton *automaticallyScanPathsButton;
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
@property (retain) NSMutableArray *libraries;
@property (retain) NSMutableArray *plugins;
@property (retain) NSMutableArray *audioOutputs;
@property (retain) NSMutableArray *sortFields;
@property (retain) SortedSeq *tracks;
@property (retain) NSNetServiceBrowser *daemonBrowser;
@property (retain) NSNetServiceBrowser *raopServiceBrowser;
@property (retain) NSPopUpButton *audioOutputPopUp;
@property (retain) NSPopUpButton *libraryPopUp;
@property (retain) NSMutableDictionary *selectedAudioOutput;
@property (retain) NSMutableDictionary *selectedLibrary;
@property (retain) NSSearchField *searchField;
@property (retain) NSSet *albums;
@property (retain) NSSet *artists;
@property (retain) TableView *trackTableView;
@property (retain) TableView *scanPathsTable;
@property (retain) NSTextField *statusBarText;
@property (retain) NSTimer *pollLibraryTimer;
@property (retain) NSTimer *pollMovieTimer;
@property (retain) NSTimer *pollStatsTimer;
@property (retain) NSToolbarItem *nextButtonItem;
@property (retain) NSToolbarItem *playButtonItem;
@property (retain) NSToolbarItem *previousButtonItem;
@property (retain) NSToolbarItem *progressSliderItem;
@property (retain) NSToolbarItem *searchItem;
@property (retain) NSToolbarItem *volumeItem;
@property (retain) NSView *contentView;
@property (retain) VolumeControl *volumeControl;
@property (retain) NSWindow *mainWindow;
@property (retain) NSWindow *preferencesWindow;
@property (retain) SplitView *contentHorizontalSplit;
@property (retain) SplitView *contentVerticalSplit;
@property (retain) Track *track;
@property bool needsReload; 
@property bool needsLibraryRefresh;
@property bool requestClearSelection;
@property bool requestNext;
@property bool requestPrevious;
@property bool requestTogglePlay;
@property bool trackEnded;
@property bool predicateChanged;
@property int requestPlayTrackAtIndex;
@property int seekToRow;
@property bool requestReloadPathsTable;

- (NSArray *)cutTracksAtIndices:(NSIndexSet *)indices;
- (void)playNextTrack;
- (void)playPreviousTrack;
- (void)playTrackAtIndex:(int)idx;
- (void)refreshAudioOutputList;
- (void)refreshLibraryList;
- (void)search:(NSString *)query;
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
- (void)library:(Library *)l addedTrack:(Track *)t;
- (void)library:(Library *)l savedTrack:(Track *)t;
- (void)library:(Library *)l deletedTrack:(Track *)t;
- (void)playClicked:(id)sender;
@end

