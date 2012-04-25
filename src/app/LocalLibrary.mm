
#include <errno.h>
#include <fts.h>
#include <stdio.h>
#include <sys/stat.h>
#include <string>
#include <leveldb/slice.h>

#import "app/JSON.h"
#import "app/ITunesScan.h"
#import "app/LocalLibrary.h"
#import "app/Log.h"
#import "app/PThread.h"
#import "app/Track.h"
#import "app/Util.h"

#define GET_URL_KEY(url) (kURLTablePrefix + url) 
static NSString * const kPathsToScan = @"PathsToScan";
static NSString * const kIsITunesImported = @"IsItunesImported";

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
@synthesize pathsToAutomaticallyScan = pathsToAutomaticallyScan_;
@synthesize onScanPathsChange = onScanPathsChange_;

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
    self.onScanPathsChange = nil;
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
  [onScanPathsChange_ release];
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
  for (NSString *p in paths0) {
    [self noteAddedPath:p];
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

- (void)noteAddedPath:(NSString *)aPath {
  struct stat status;
  if (stat(aPath.UTF8String, &status) == 0 && status.st_mode & S_IFDIR) {
    NSArray *curr = self.pathsToAutomaticallyScan;
    NSMutableArray *a = [NSMutableArray array];
    if (curr)
      [a addObjectsFromArray:curr];
    if (![a containsObject:aPath]) 
      [a addObject:aPath];
    self.pathsToAutomaticallyScan = a;
  }
}

- (NSArray *)pathsToAutomaticallyScan {
  return [[NSUserDefaults standardUserDefaults] arrayForKey:kPathsToScan];
}

- (void)setPathsToAutomaticallyScan:(NSArray *)paths {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  paths = [paths sortedArrayUsingSelector:@selector(compare:)];
  [d setObject:paths forKey:kPathsToScan];
  [d synchronize];
  OnScanPathsChange c = self.onScanPathsChange;
  if (c) {
    c();
  }
}
- (void)checkITunesImport {
  ForkWith(^{
    usleep(1000);
    if (!self.isITunesImported) {
      NSMutableArray *paths = [NSMutableArray array];
        GetITunesTracks(^(Track *t) {
        [paths addObject:t.url];
      });
      [self scan:paths];
      self.isITunesImported = true;
    }
  });
};

- (void)checkAutomaticPaths {
  ForkWith(^{
    usleep(2000);
    [self scan:self.pathsToAutomaticallyScan];
  });
}

- (bool)isITunesImported { 
  return [[NSUserDefaults standardUserDefaults] boolForKey:kIsITunesImported];
}

- (void)setIsITunesImported:(bool)st { 
  [[NSUserDefaults standardUserDefaults] setBool:(BOOL)st forKey:kIsITunesImported];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

