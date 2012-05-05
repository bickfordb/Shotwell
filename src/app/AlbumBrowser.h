#import <Cocoa/Cocoa.h>
#import "app/SortedSeq.h"
#import "app/TableViewController.h"
#import "app/Library.h"
#import "app/Loop.h"

@interface AlbumBrowser : ViewController { 
  NSMutableSet *items_;
  Loop *loop_;
  NSScrollView *scrollView_;
  NSCollectionView *collectionView_;
  Library *library_;
  bool requestReload_;
  NSPredicate *predicate_;
}
@property (retain) NSMutableSet *items;
@property (retain) NSCollectionView *collectionView;
@property (retain) NSScrollView *scrollView;
@property (retain) Library *library;
@property (retain) Loop *loop;
@property (retain) NSPredicate *predicate;

- (void)reload;
- (id)initWithLibrary:(Library *)library;

@end

// vim: filetype=objcpp
