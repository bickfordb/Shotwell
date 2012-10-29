
#import "app/Level.h"
#import "app/Library.h"
#import "app/Loop.h"
#include <leveldb/db.h>
#include <sys/time.h>
#include <event2/event.h>

extern NSString * const kScanPathsChanged;

@interface LocalLibrary : Library {
}

@property bool pruneRequested;
@property (retain) NSMutableSet *pathsToScan;
@property (retain) NSMutableSet *pendingCoverArtTracks;

- (id)initWithDBPath:(NSString *)dbPath coverArtPath:(NSString *)coverArtPath;
- (void)save:(Track *)t;
- (Track *)get:(NSNumber *)trackID;
- (void)clear;
- (void)prune;
- (void)delete:(Track *)track;
- (void)each:(void (^)(Track *track))block;
- (void)checkITunesImport;
- (void)noteAddedPath:(NSString *)aPath;
- (void)checkAutomaticPaths;
- (void)checkCoverArtForTrack:(Track *)t;
- (void)checkCoverArt;
- (bool)hasCoverArt:(NSString *)coverArtID;
- (Track *)index:(NSString *)path;
- (void)saveCoverArt:(NSString *)coverArtID data:(NSData *)data;
- (NSData *)getCoverArt:(NSString *)coverArtID;

@property bool isITunesImported;
@property (copy) NSArray *pathsToAutomaticallyScan;
@end

