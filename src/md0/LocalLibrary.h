
#import "Level.h"
#import "Library.h"
#import "Loop.h"
#include <leveldb/db.h>
#include <sys/time.h>
#include <event2/event.h>

@interface TrackTable : LevelTable {
}
@end

@interface URLTable : LevelTable {
}
@end

@interface LocalLibrary : Library { 
  TrackTable *trackTable_;
  URLTable *urlTable_;
  Loop *pruneLoop_;
  Loop *scanLoop_;
  Event *scanEvent_;
  Event *pruneEvent_;
  bool pruneRequested_;
  NSMutableSet *pathsToScan_;
  struct event *scanTimeout_;
  struct event *pruneTimeout_;
}

- (id)initWithPath:(NSString *)path;
- (void)save:(NSDictionary *)t;
- (NSDictionary *)get:(NSNumber *)trackID;
- (void)clear;
- (void)scan:(NSArray *)scanPaths;
- (void)prune;
- (void)delete:(NSDictionary *)track;
- (void)each:(void (^)(NSDictionary *track))block;
@end


