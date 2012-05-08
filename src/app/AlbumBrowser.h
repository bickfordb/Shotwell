#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "app/SortedSeq.h"
#import "app/TableViewController.h"
#import "app/Library.h"
#import "app/Loop.h"

@interface AlbumBrowser : ViewController { 
  SortedSeq *items_;
  NSMutableDictionary *titleToItem_;
  NSScrollView *scrollView_;
  IKImageBrowserView *browserView_;
  Library *library_;
}
@property (retain) SortedSeq *items;
@property (retain) NSScrollView *scrollView;
@property (retain) IKImageBrowserView *browserView;
@property (retain) Library *library;
@property (retain) NSMutableDictionary *titleToItem;

- (id)initWithLibrary:(Library *)library;

@end

// vim: filetype=objcpp
