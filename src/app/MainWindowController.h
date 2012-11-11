#import <Cocoa/Cocoa.h>
#import "app/CoverBrowser.h"
#import "app/NavTable.h"
#import "app/ProgressControl.h"
#import "app/ServiceBrowser.h"
#import "app/ServicePopUpButton.h"
#import "app/SplitView.h"
#import "app/TableViewController.h"
#import "app/Track.h"
#import "app/TrackBrowser.h"
#import "app/TrackDetailView.h"
#import "app/VolumeControl.h"
#import "app/WindowController.h"

typedef enum {
  MainWindowControllerAlbumBrowser,
  MainWindowControllerArtistBrowser,
  MainWindowControllerTrackBrowser,
  MainWindowControllerYearBrowser
} MainWindowControllerBrowser;

@interface MainWindowController : WindowController <NSToolbarDelegate> {
  CoverBrowser *albumBrowser_;
  CoverBrowser *artistBrowser_;
  Loop *loop_;
  NSSegmentedControl *playbackControls_;
  NSImage *playImage_;
  NSProgressIndicator *progressIndicator_;
  NSImage *startImage_;
  NSImage *stopImage_;
  NSSearchField *searchField_;
  NSSet *albums_;
  NSSet *artists_;
  Library *library_;
  NavTable *navTable_;
  NSTextField *statusBarText_;
  NSView *contentView_;
  ProgressControl *progressControl_;
  ServicePopUpButton *audioOutputPopUpButton_;
  ServiceBrowser *libraryServiceBrowser_;
  SplitView *verticalSplit_;
  SplitView *navSplit_;
  TrackBrowser *trackBrowser_;
  ViewController *content_;
  VolumeControl *volumeControl_;
  TrackDetailView *trackDetailView_;
  bool isBusy_;
}

- (void)removeRemoteLibraryService:(NSNetService *)svc;
- (void)addRemoteLibraryService:(NSNetService *)svc;
- (void)pollStats;
- (void)search:(NSString *)term after:(On0)after;
- (void)selectBrowser:(MainWindowControllerBrowser)idx;
- (void)setupAudioSelect;
- (void)setupStatusBarText;
- (void)setupWindow;
- (void)trackEnded:(Track *)track;
- (void)trackStarted:(Track *)track;
- (void)setupBusyIndicator;

@property (retain) Loop *loop;
@property (retain) NSSegmentedControl *playbackControls;
@property (retain) CoverBrowser *albumBrowser;
@property (retain) CoverBrowser *artistBrowser;
@property (retain) NavTable *navTable;
@property (retain) NSImage *playImage;
@property (retain) NSProgressIndicator *progressIndicator;
@property (retain) NSImage *startImage;
@property (retain) NSImage *stopImage;
@property (retain) NSSearchField *searchField;
@property (retain) NSSet *albums;
@property (retain) NSSet *artists;
@property (retain) NSTextField *statusBarText;
@property (retain) NSView *contentView;
@property (retain) ProgressControl *progressControl;
@property (retain) ServicePopUpButton *audioOutputPopUpButton;
@property (retain) ServiceBrowser *libraryServiceBrowser;
@property (retain) TrackBrowser *trackBrowser;
@property (retain) ViewController *content;
@property (retain) VolumeControl *volumeControl;

@end
// vim: filetype=objcpp
