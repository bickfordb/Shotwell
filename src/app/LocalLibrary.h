
#import "app/Level.h"
#import "app/Library.h"
#import "app/Loop.h"
#include <leveldb/db.h>
#include <sys/time.h>
#include <event2/event.h>

@interface TrackTable : JSONTable {
}
@end

@interface URLTable : JSONTable {
}
@end

extern NSString * const kScanPathsChanged;


@interface LocalLibrary : Library { 
  TrackTable *trackTable_;
  URLTable *urlTable_;
  Loop *pruneLoop_;
  Loop *scanLoop_;
  Loop *coverArtLoop_;
  bool pruneRequested_;
  int numCoverArtQueries_;
  NSMutableSet *pathsToScan_;
  FSEventStreamRef fsEventStreamRef_;
  NSMutableSet *pendingCoverArtTracks_;
  NSString *coverArtPath_;
}

@property (retain) TrackTable *trackTable;
@property (retain) URLTable *urlTable;
@property (retain) Loop *pruneLoop;
@property (retain) Loop *scanLoop;
@property (retain) Loop *coverArtLoop;
@property bool pruneRequested;
@property (retain) NSMutableSet *pathsToScan;
@property (retain) NSMutableSet *pendingCoverArtTracks;
@property (retain) NSString *coverArtPath;

- (id)initWithDBPath:(NSString *)dbPath coverArtPath:(NSString *)coverArtPath;
- (void)save:(Track *)t;
- (Track *)get:(NSNumber *)trackID;
- (void)clear;
- (void)scan:(NSArray *)scanPaths;
- (void)prune;
- (void)delete:(Track *)track;
- (void)each:(void (^)(Track *track))block;
- (void)checkITunesImport;
- (void)noteAddedPath:(NSString *)aPath;
- (void)checkAutomaticPaths;
- (void)checkCoverArtForTrack:(Track *)t;
- (void)checkCoverArt;

@property bool isITunesImported;
@property (copy) NSArray *pathsToAutomaticallyScan;
@end

