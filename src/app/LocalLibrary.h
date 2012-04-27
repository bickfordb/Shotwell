
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

typedef void (^OnScanPathsChange)(void);

@interface LocalLibrary : Library { 
  TrackTable *trackTable_;
  URLTable *urlTable_;
  Loop *pruneLoop_;
  Loop *scanLoop_;
  bool pruneRequested_;
  NSMutableSet *pathsToScan_;
  OnScanPathsChange onScanPathsChange_;
  FSEventStreamRef fsEventStreamRef_;
}

@property (retain) TrackTable *trackTable;
@property (retain) URLTable *urlTable;
@property (retain) Loop *pruneLoop;
@property (retain) Loop *scanLoop;
@property bool pruneRequested;
@property (retain) NSMutableSet *pathsToScan;
@property (copy) OnScanPathsChange onScanPathsChange;

- (id)initWithPath:(NSString *)path;
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

@property bool isITunesImported;
@property (copy) NSArray *pathsToAutomaticallyScan;
@end

