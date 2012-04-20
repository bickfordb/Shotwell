
#include <errno.h>
#include <fts.h>
#include <google/protobuf/io/coded_stream.h>
#include <google/protobuf/io/zero_copy_stream_impl.h>
#include <pcre.h>
#include <pthread.h>
#include <stdio.h>
#include <sys/stat.h>
#include <pcrecpp.h>
#include <string>
#include <leveldb/slice.h>

#import "md0/JSON.h"
#import "md0/LocalLibrary.h"
#import "md0/Log.h"
#import "md0/Track.h"
#import "md0/Util.h"

#define GET_URL_KEY(url) (kURLTablePrefix + url) 

using namespace std;

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
        INFO(@"pruning");
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
  char *paths[paths0.count + 1];
  memset(paths, 0, paths0.count + 1);
  int i;
  for (i = 0; i < paths0.count; i++) {
    paths[i] = (char *)[[paths0 objectAtIndex:i] UTF8String];
  }
  i++;
  paths[i] = NULL; 

  FTS *tree = fts_open(paths, FTS_NOCHDIR, 0);
  if (tree == NULL)
    return;
  FTSENT *node = NULL;
  pcrecpp::RE mediaExtensionsPattern("^.*[.](?:mp3|m4a|ogg|avi|mkv|aac|mov)$");
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  while (tree && (node = fts_read(tree))) {
    if (node->fts_level > 0 && node->fts_name[0] == '.') {
      fts_set(tree, node, FTS_SKIP);
      continue;
    }
    if (!(node->fts_info & FTS_F)) 
      continue;
    NSString *filename = [NSString stringWithUTF8String:node->fts_path];
    if (!filename)
      continue;
    if (!mediaExtensionsPattern.FullMatch(node->fts_path)) {
      continue;
    }
    NSNumber *trackID = [urlTable_ get:filename];
    if (!trackID) {
      Track *t = [[Track alloc] init];
      t.url = filename;
      int st = [t readTag];
      [self save:t];
      [t release];
    }
  }
  [pool release];
  if (tree) 
    fts_close(tree);
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
  if (!url || !url.length) 
    return;
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

