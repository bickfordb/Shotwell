#import <Cocoa/Cocoa.h>
#import "NavTable.h"
#import "ProgressControl.h"
#import "ServiceBrowser.h"
#import "ServicePopUpButton.h"
#import "SplitView.h"
#import "TableViewController.h"
#import "Track.h"
#import "TrackBrowser.h"
#import "VolumeControl.h"
#import "WindowController.h"

typedef enum {
  MainWindowControllerAlbumBrowser,
  MainWindowControllerArtistBrowser,
  MainWindowControllerCondensedBrowser,
  MainWindowControllerTrackBrowser,
  MainWindowControllerYearBrowser
} MainWindowControllerBrowser;

@interface MainWindowController : WindowController <NSToolbarDelegate> {
  Loop *loop_;
  NSSegmentedControl *playbackControls_;
  NSImage *playImage_;
  NSProgressIndicator *progressIndicator_;
  NSPopUpButton *browserControl_;
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
  NSView *navContent_;
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
- (void)trackEnded:(NSMutableDictionary *)track;
- (void)trackStarted:(NSMutableDictionary *)track;
- (void)setupBusyIndicator;

@property (retain) Loop *loop;
@property (retain) NSSegmentedControl *playbackControls;
@property (retain) NSPopUpButton *browserControl;
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
+ (MainWindowController *)shared;

@end
// vim: filetype=objcpp
