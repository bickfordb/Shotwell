#import <Cocoa/Cocoa.h>
#import "app/SortedSeq.h"
#import "app/TableViewController.h"
#import "app/Library.h"

@interface ArtistBrowser : ViewController { 
  SortedSeq *items_;
  NSScrollView *scrollView_;
  NSCollectionView *collectionView_;
  Library *library_;
}
@property (retain) SortedSeq *items;
@property (retain) NSCollectionView *collectionView;
@property (retain) NSScrollView *scrollView;
@property (retain) Library *library;
- (void)reload;
- (id)initWithLibrary:(Library *)library;

@end


// vim: filetype=objcpp
