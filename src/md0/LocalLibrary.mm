
#include <errno.h>
#include <fts.h>
#include <stdio.h>
#include <sys/stat.h>
#include <string>
#include <leveldb/slice.h>

#import "md0/JSON.h"
#import "md0/LocalLibrary.h"
#import "md0/Log.h"
#import "md0/Track.h"
#import "md0/Util.h"

#define GET_URL_KEY(url) (kURLTablePrefix + url) 

@interface LocalLibrary (P)  
- (void)scanQueuedPaths;
- (void)pruneQueued;
@end

@implementation TrackTable 
- (const char *)keyPrefix {
  return "t:";
}

- (id)decodeValue:(const char *)bytes length:(size_t)length {
  NSDictionary *v = [super decodeValue:bytes length:length];
  Track *t = [[[Track alloc] init] autorelease];
  [t setValuesForKeysWithDictionary:v];
  return t;
}
@end

@implementation URLTable
- (const char *)keyPrefix { 
  return "u:"; 
}

@end

@implementation LocalLibrary
@synthesize trackTable = trackTable_;
@synthesize urlTable = urlTable_;
@synthesize pathsToScan = pathsToScan_;
@synthesize pruneRequested = pruneRequested_;
@synthesize pruneLoop = pruneLoop_;
@synthesize scanLoop = scanLoop_;

- (id)initWithPath:(NSString *)path {  
  self = [super init];
  if (self) {
    Level *level = [[[Level alloc] initWithPath:path] autorelease]; 
    urlTable_ = [[URLTable alloc] initWithLevel:level];
    trackTable_ = [[TrackTable alloc] initWithLevel:level];
    self.pathsToScan = [NSMutableSet set];
    self.pruneRequested = false;
    self.pruneLoop = [[[Loop alloc] init] autorelease];
    self.scanLoop = [[[Loop alloc] init] autorelease];
    void *weakSelf = (void*)self;
    [pruneLoop_ onTimeout:1000000 with:^(Event *e, short flags) {
      LocalLibrary *self0 = (LocalLibrary *)weakSelf;
      if (self0.pruneRequested) {
        self0.pruneRequested = false;
        [self0 pruneQueued]; 
      }
      [e add:1000000];
    }];
    [scanLoop_ onTimeout:1000000 with:^(Event *e, short flags) {
      [((LocalLibrary *)weakSelf) scanQueuedPaths];
      [e add:1000000];
    }];
  }
  return self;
}

- (void)dealloc { 
  [pruneLoop_ release];
  [scanLoop_ release];
  [pathsToScan_ release];
  [trackTable_ release];
  [urlTable_ release];
  [super dealloc];
}

- (void)scanQueuedPaths { 
  NSArray *paths0;
  @synchronized(pathsToScan_)  {
    paths0 = pathsToScan_.allObjects;
    [pathsToScan_ removeAllObjects];
  }
  if (paths0.count == 0) {
    return;
  }
  int n = paths0.count;
  char * paths[n + 1];
  int i = 0;
  for (NSString *p in paths0) {
    paths[i] = (char *)p.UTF8String;  
    i++;
  }
  paths[n] = NULL;

  NSAutoreleasePool *pool = nil;
  FTS *tree = fts_open(paths, FTS_NOCHDIR, 0);
  if (!tree)
    return;
  for (;;) {
    FTSENT *node = fts_read(tree);
    if (!node) {
      if (errno) {
        ERROR(@"errno: %d", (int)errno);
      }
      break;
    }
    [pool release];
    pool = [[NSAutoreleasePool alloc] init];
    if (node->fts_info & FTS_F) {
      NSString *filename = [NSString stringWithUTF8String:node->fts_path];
      
      if (!filename)
        continue;
      NSNumber *trackID = [urlTable_ get:filename];
      if (!trackID) {
        Track *t = [[Track alloc] init];
        t.url = filename;
        int st = [t readTag];
        // Only index things with audio:
        // This will skip JPEG/photo files but allow almost other media files that LibAV can read through.
        if (t.isAudio.boolValue) {
          [self save:t];
        } 
        [t release];
      }
    }
  }
  fts_close(tree);
  [pool release];
}

- (id)init {
  self = [super init];
  if (self) {
    pruneLoop_ = [[Loop alloc] init];
    scanLoop_ = [[Loop alloc] init];
    pruneRequested_ = false;
    pathsToScan_ = [NSMutableSet set];
    self.lastUpdatedAt = Now();
  }
  return self;
}

- (void)pruneQueued {
  [trackTable_ each:^(id key, id val) {
    Track *track = (Track *)val;    
    struct stat fsStatus;
    if (stat(track.url.UTF8String, &fsStatus) < 0 && errno == ENOENT) {
      [self delete:track];
    }
  }];
}     

- (void)save:(Track *)track { 
  NSString *url = track.url;
  if (!url || !url.length) { 
    return;
  }
  bool isNew = false;
  if (!track.id) {
    track.id = [trackTable_ nextID];
    isNew = true;
  }
  [urlTable_ put:track.id forKey:track.url];
  [trackTable_ put:track forKey:track.id];
  if (isNew && self.onAdded)
    self.onAdded(self, track);
  else if (self.onSaved)
    self.onSaved(self, track);
  self.lastUpdatedAt = Now();
}


- (Track *)get:(NSNumber *)trackID {
  return [trackTable_ get:trackID]; 
}

- (void)clear {
  [urlTable_ clear];
  [trackTable_ clear];
}

- (void)delete:(Track *)track { 
  [trackTable_ delete:track.id];
  if (track.url) 
    [urlTable_ delete:track.url];
  self.lastUpdatedAt = Now();
  if (self.onDeleted)
    self.onDeleted(self, track);
}

- (int)count { 
  return trackTable_.count;
}

- (void)each:(void (^)(Track *track))block {
  [trackTable_ each:^(id key, id val) {
    block((Track *)val);
  }];
}

- (void)scan:(NSArray *)paths { 
  @synchronized(pathsToScan_) { 
    if (paths)
      [pathsToScan_ addObjectsFromArray:paths];
  }
}

- (void)prune { 
  pruneRequested_ = true;
}

@end

