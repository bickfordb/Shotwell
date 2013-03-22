#import <Cocoa/Cocoa.h>
#import "Library.h"
#import "TableViewController.h"
#import "SortedSeq.h"

@interface TrackBrowser : TableViewController {
  SortedSeq *tracks_;
  NSFont *playingFont_;
  NSFont *font_;
  NSImage *emptyImage_;
  NSImage *playImage_;
  Library *library_;
}


@property (retain) SortedSeq *tracks;
@property (retain) NSImage *emptyImage;
@property (retain) NSFont *playingFont;
@property (retain) NSFont *font;
@property (retain) NSImage *playImage;
@property (retain) Library *library;
- (NSArray *)selectedTracks;
- (NSArray *)cutSelectedTracks;
- (void)playTrackAtIndex:(int)idx;
- (void)playNextTrack;
- (void)playPreviousTrack;
@end
// vim: filetype=objcpp
