
#import "md0/Level.h"
#import "md0/Library.h"
#import "md0/Loop.h"
#include <leveldb/db.h>
#include <sys/time.h>
#include <event2/event.h>

@interface TrackTable : JSONTable {
}
@end

@interface URLTable : JSONTable {
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
- (void)save:(Track *)t;
- (Track *)get:(NSNumber *)trackID;
- (void)clear;
- (void)scan:(NSArray *)scanPaths;
- (void)prune;
- (void)delete:(Track *)track;
- (void)each:(void (^)(Track *track))block;
@end


