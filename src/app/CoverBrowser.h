#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "app/SortedSeq.h"
#import "app/TableViewController.h"
#import "app/Library.h"
#import "app/Loop.h"

typedef NSString *(^CoverBrowserTracksToString)(NSSet *tracks);
typedef NSString *(^CoverBrowserTrackToKey)(Track *t);
typedef NSString *(^CoverBrowserTracksToPredicate)(NSSet *tracks);

extern CoverBrowserTracksToString CoverBrowserFolderTitle;
extern CoverBrowserTracksToString CoverBrowserFolderSubtitle;
extern CoverBrowserTracksToString CoverBrowserArtistTitle;
extern CoverBrowserTracksToString CoverBrowserArtistSubtitle;
extern CoverBrowserTracksToPredicate CoverBrowserSearchByFolder;
extern CoverBrowserTracksToPredicate CoverBrowserSearchByArtist;
extern CoverBrowserTrackToKey CoverBrowserGroupByFolder;
extern CoverBrowserTrackToKey CoverBrowserGroupByArtist;

@interface CoverBrowser : ViewController {
  SortedSeq *items_;
  NSMutableDictionary *keyToItem_;
  NSScrollView *scrollView_;
  IKImageBrowserView *browserView_;
  Library *library_;
  CoverBrowserTrackToKey toKey_;
  CoverBrowserTracksToString toTitle_;
  CoverBrowserTracksToString toSubtitle_;
  CoverBrowserTracksToPredicate toPredicate_;
}
@property (retain) SortedSeq *items;
@property (retain) NSScrollView *scrollView;
@property (retain) IKImageBrowserView *browserView;
@property (retain) Library *library;
@property (retain) NSMutableDictionary *keyToItem;
@property (copy) CoverBrowserTrackToKey toKey;
@property (copy) CoverBrowserTracksToPredicate toPredicate;
@property (copy) CoverBrowserTracksToString toTitle;
@property (copy) CoverBrowserTracksToString toSubtitle;

- (id)initWithLibrary:(Library *)library
                toKey:(CoverBrowserTrackToKey)toKey
              toTitle:(CoverBrowserTracksToString)toTitle
           toSubtitle:(CoverBrowserTracksToString)toSubtitle
          toPredicate:(CoverBrowserTracksToPredicate)toPredicate;

@end

// vim: filetype=objcpp
