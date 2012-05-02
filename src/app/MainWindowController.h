#import <Cocoa/Cocoa.h>
#import "app/AlbumBrowser.h"
#import "app/ArtistBrowser.h"
#import "app/ServicePopUpButton.h"
#import "app/ProgressControl.h"
#import "app/SplitView.h"
#import "app/TableViewController.h"
#import "app/TrackBrowser.h"
#import "app/VolumeControl.h"
#import "app/WindowController.h"
#import "app/Track.h"

@interface MainWindowController : WindowController <NSToolbarDelegate> {
  Loop *loop_;
  NSButton *nextButton_;
  NSButton *playButton_;
  NSButton *previousButton_;
  NSImage *playImage_;
  NSImage *startImage_;
  NSImage *stopImage_;
  NSPopUpButton *groupsPopUpButton_;
  NSPopUpButton *libraryPopUp_;
  NSSearchField *searchField_;
  NSSet *albums_;
  NSSet *artists_;
  Library *library_;
  NSTextField *statusBarText_;
  NSView *contentView_;
  ProgressControl *progressControl_;
  ServicePopUpButton *audioOutputPopUpButton_;
  ServicePopUpButton *libraryPopUpButton_;
  SplitView *horizontalSplit_;
  SplitView *verticalSplit_;
  TrackBrowser *trackBrowser_;
  ViewController *content_;
  VolumeControl *volumeControl_;
}

- (void)pollStats;
- (void)search:(NSString *)term; 
- (void)selectBrowser:(int)idx;
- (void)setupAudioSelect;
- (void)setupGroupsPopupButton;
- (void)setupStatusBarText;
- (void)setupWindow;
- (void)trackEnded:(Track *)track;
- (void)trackStarted:(Track *)track;

@property (retain) Loop *loop;
@property (retain) NSButton *nextButton;
@property (retain) NSButton *playButton;
@property (retain) NSButton *previousButton;
@property (retain) NSImage *playImage;
@property (retain) NSImage *startImage;
@property (retain) NSImage *stopImage;
@property (retain) NSPopUpButton *groupsPopUpButton;
@property (retain) NSPopUpButton *libraryPopUp;
@property (retain) NSSearchField *searchField;
@property (retain) NSSet *albums;
@property (retain) NSSet *artists;
@property (retain) NSTextField *statusBarText;
@property (retain) NSView *contentView;
@property (retain) ProgressControl *progressControl;
@property (retain) ServicePopUpButton *audioOutputPopUpButton;
@property (retain) ServicePopUpButton *libraryPopUpButton;
@property (retain) Library *library;
@property (retain) SplitView *horizontalSplit;
@property (retain) SplitView *verticalSplit;
@property (retain) TrackBrowser *trackBrowser;
@property (retain) ViewController *content;
@property (retain) VolumeControl *volumeControl;
@end
// vim: filetype=objcpp
