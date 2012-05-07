#import <Cocoa/Cocoa.h>
#import "app/SortedSeq.h"
#import "app/TableViewController.h"
#import "app/Library.h"
#import "app/Loop.h"

@interface AlbumBrowser : ViewController { 
  NSArrayController *items_;
  NSMutableDictionary *titleToItem_;
  NSScrollView *scrollView_;
  NSCollectionView *collectionView_;
  Library *library_;
}
@property (retain) NSArrayController *items;
@property (retain) NSCollectionView *collectionView;
@property (retain) NSScrollView *scrollView;
@property (retain) Library *library;
@property (retain) NSMutableDictionary *titleToItem;

- (id)initWithLibrary:(Library *)library;

@end

// vim: filetype=objcpp
