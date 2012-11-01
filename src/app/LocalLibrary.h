
#import "app/Level.h"
#import "app/Library.h"
#include <leveldb/db.h>
#include <sys/time.h>
#include <event2/event.h>

extern NSString * const kScanPathsChanged;

@interface LocalLibrary : Library {
}

@property bool pruneRequested;
@property (retain) NSMutableSet *pathsToScan;
@property (retain) NSMutableSet *pendingCoverArtTracks;

- (id)initWithDBPath:(NSString *)dbPath;
- (void)save:(Track *)t;
- (Track *)get:(NSNumber *)trackID;
- (void)clear;
- (void)prune;
- (void)delete:(Track *)track;
- (void)each:(void (^)(Track *track))block;
- (void)checkITunesImport;
- (void)noteAddedPath:(NSString *)aPath;
- (void)checkAutomaticPaths;
- (NSData *)getCoverArt:(NSString *)coverArtID;
- (void)scan:(NSArray *)paths;
- (void)checkCoverArt;
- (void)checkAcoustIDs;

@property bool isITunesImported;
@property (copy) NSArray *pathsToAutomaticallyScan;

@end

