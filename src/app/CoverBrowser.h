#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "app/Dict.h"
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

@interface CoverBrowserItem : NSObject {
  NSMutableSet *tracks_;
  NSString *key_;
  CoverBrowserTracksToString toTitle_;
  CoverBrowserTracksToString toSubtitle_;
}

@property (retain) NSString *key;
@property (retain) NSMutableSet *tracks;
@property (copy) CoverBrowserTracksToString toTitle;
@property (copy) CoverBrowserTracksToString toSubtitle;

// IKImageBrowserItem protocol:
- (NSString *)imageUID;
- (NSUInteger)imageVersion;
- (NSString *)imageTitle;
- (NSString *)imageSubtitle;
- (NSString *)imageRepresentationType;
- (id)imageRepresentation;
- (BOOL)isSelectable;
@end

@interface CoverBrowser : ViewController {
  SortedSeq *items_;
  Dict *keyToItem_;
  Dict *trackToItem_;
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
@property (retain) Dict *keyToItem;
@property (retain) Dict *trackToItem;
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
