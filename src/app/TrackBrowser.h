#import <Cocoa/Cocoa.h>
#import "app/Library.h"
#import "app/TableViewController.h"

@interface TrackBrowser : TableViewController {
  SortedSeq *tracks_;
  NSFont *playingFont_;
  NSFont *font_;
  NSImage *emptyImage_;
  NSImage *playImage_;
  Library *library_;
}

- (id)initWithLibrary:(Library *)library;

@property (retain) SortedSeq *tracks;
@property (retain) NSImage *emptyImage;
@property (retain) NSFont *playingFont;
@property (retain) NSFont *font;
@property (retain) NSImage *playImage;
@property (retain) Library *library;
- (NSArray *)selectedTracks;
- (NSArray *)cutSelectedTracks;

@end
// vim: filetype=objcpp
