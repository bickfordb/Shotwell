
#include <errno.h>
#include <fts.h>
#include <stdio.h>
#include <sys/stat.h>
#include <string>

#import "AppDelegate.h"
#import "AVFile.h"
#import "CoverArtScraper.h"
#import "HTTP.h"
#import "HTTPResponse.h"
#import "ITunesScan.h"
#import "LocalLibrary.h"
#import "Log.h"
#import "NSStringDigest.h"
#import "NSURLAdditions.h"
#import "Pthread.h"
#import "UUID.h"
#import "Table.h"
#import "Track.h"
#import "Util.h"

static NSString * const kPathsToScan = @"PathsToScan";
static NSString * const kIsITunesImported = @"IsITunesImported";
NSString * const kScanPathsChanged = @"ScanPathsChanged";
static CFTimeInterval kMonitorLatency = 2.0;
static LocalLibrary *localLibrary = nil;
static NSObject *sharedLocalLibraryLock = nil;



static NSMutableDictionary *FilterKeys(NSMutableDictionary *src, NSArray *keys) {
  NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:src];
  [ret removeObjectsForKeys:keys];
  return ret;
}

@interface LocalLibrary (Private)
- (void)monitorPaths;
- (NSMutableDictionary *)index:(NSString *)path;
@end

static void OnFileEvent(
    ConstFSEventStreamRef streamRef,
    void *clientCallBackInfo,
    size_t numEvents,
    void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[]) {
  NSArray *paths = (NSArray *)eventPaths;
  LocalLibrary *library = (LocalLibrary *)clientCallBackInfo;
  NSMutableArray *paths0 = [NSMutableArray array];
  for (NSString *p in paths) {
    struct stat status;
    if (stat(p.UTF8String, &status) != 0) {
      continue;
    }
    // Skip directories
    if (status.st_mode & S_IFDIR) {
      continue;
    }
    [paths0 addObject:p];
  }
  [library scan:paths0];
}

@implementation LocalLibrary {
  Table *trackTable_;
  Table *pathIndex_;
  dispatch_queue_t indexQueue_;
  dispatch_queue_t pruneQueue_;
  dispatch_queue_t coverArtQueue_;
  dispatch_queue_t acoustIDQueue_;
  int numCoverArtQueries_;
  FSEventStreamRef fsEventStreamRef_;
  NSMutableSet *pendingCoverArtTracks_;
  Table *coverArtTable_;
}
+ (void)initialize {
  sharedLocalLibraryLock = [[NSObject alloc] init];
}

- (id)initWithDBPath:(NSString *)dbPath {
  self = [super init];
  if (self) {
    pathIndex_ = [[Table alloc] initWithPath:[dbPath stringByAppendingPathComponent:@"paths"]];
    trackTable_ = [[Table alloc] initWithPath:[dbPath stringByAppendingPathComponent:@"tracks"]];
    if (!pathIndex_ || !trackTable_) {
      [self release];
      return nil;
    }
    indexQueue_ = dispatch_queue_create("shotwell.index", NULL);
    pruneQueue_ = dispatch_queue_create("shotwell.prune", NULL);
    acoustIDQueue_ = dispatch_queue_create("shotwell.acoustid", NULL);
    pendingCoverArtTracks_ = [[NSMutableSet set] retain];
    fsEventStreamRef_ = nil;
    [self monitorPaths];
  }
  return self;
}

- (void)monitorPaths {
  if (fsEventStreamRef_) {
    FSEventStreamStop(fsEventStreamRef_);
    FSEventStreamInvalidate(fsEventStreamRef_);
    FSEventStreamRelease(fsEventStreamRef_);
    fsEventStreamRef_ = nil;
  }
  NSArray *paths = self.pathsToAutomaticallyScan;
  FSEventStreamContext context = {0, self, NULL, NULL, NULL};
  INFO(@"paths to automatically scan: %@", paths);

  if (paths.count) {
    fsEventStreamRef_ = FSEventStreamCreate(
        kCFAllocatorDefault,
        OnFileEvent,
        &context,
        (CFArrayRef)paths,
        kFSEventStreamEventIdSinceNow,
        kMonitorLatency,
        kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents);

    FSEventStreamScheduleWithRunLoop(fsEventStreamRef_,
        CFRunLoopGetCurrent(),
        kCFRunLoopDefaultMode);
    FSEventStreamStart(fsEventStreamRef_);
  }
}

- (void)dealloc {
  if (coverArtQueue_)
    dispatch_release(coverArtQueue_);
  if (indexQueue_)
    dispatch_release(indexQueue_);
  if (pruneQueue_)
    dispatch_release(pruneQueue_);
  if (acoustIDQueue_)
    dispatch_release(acoustIDQueue_);
  if (fsEventStreamRef_) {
    FSEventStreamStop(fsEventStreamRef_);
    FSEventStreamInvalidate(fsEventStreamRef_);
    FSEventStreamRelease(fsEventStreamRef_);
    fsEventStreamRef_ = nil;
  }

  [coverArtTable_ release];
  [trackTable_ release];
  [pathIndex_ release];
  [super dealloc];
}

- (void)scanPath:(NSString *)path {
  char *paths[2];
  paths[0] = (char *)path.UTF8String;
  paths[1] = NULL;
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
      [self index:filename];
    }
  }
  fts_close(tree);
  [pool release];

}

- (NSMutableDictionary *)index:(NSString *)path {
  DEBUG(@"indexing %@", path);
  if (!path) {
    DEBUG(@"empty path");
    return nil;
  }
  NSDate *lastModified = ModifiedAt(path);
  if (!lastModified) {
    DEBUG(@"not modified");
    // Not Found
    return nil;
  }
  NSMutableDictionary *track = trackTable_[pathIndex_[path]];
  NSDate *createdAt = track[kTrackCreatedAt];
  NSError *error = nil;
  NSDictionary *tag = nil;
  BOOL readTag = NO;
  if (!track) {
    track = TrackNew();
    readTag = YES;
  } else if (createdAt && [createdAt compare:lastModified] < 0) {
    readTag = YES;
  } else {
    return nil;
  }
  if (readTag) {
    AVFile *file = [[[AVFile alloc] initWithURL:[NSURL fileURLWithPath:path] error:&error] autorelease];
    if (!file || error) return nil;
    NSDictionary *tag = [file tag];
    if (!tag) return nil;
    [track addEntriesFromDictionary:tag];
  }
  NSString *title = track[kTrackTitle];
  if (!title || !title.length) {
    track[kTrackTitle] = path.lastPathComponent.stringByDeletingPathExtension;
  }
  DEBUG(@"adding track: %@", track);
  self[track[kTrackID]] = track;
  return track;
}

- (id)objectForKeyedSubscript:(id)trackID {
  return trackTable_[trackID];
}

- (void)clear {
  [pathIndex_ clear];
  [trackTable_ clear];
}

- (void)setObject:(id)track forKeyedSubscript:(id)trackID {
  if (!trackID) {
    return;
  }
  // delete case
  NSMutableDictionary *oldTrack = trackTable_[trackID];
  if (!track) {
    if (!oldTrack) {
      return;
    }
    trackTable_[track[kTrackID]] = nil;
    pathIndex_[track[kTrackPath]] = nil;
    self.lastUpdatedAt = [NSDate date];
    [self notifyTrack:track change:kLibraryTrackDeleted];
  } else {
    // make sure trackID is set
    track = FilterKeys(track, @[kTrackURL, kTrackLibrary]);
    track[kTrackID] = trackID;
    track[kTrackUpdatedAt] = [NSDate date];
    pathIndex_[oldTrack[kTrackPath]] = nil;
    pathIndex_[track[kTrackPath]] = trackID;
    trackTable_[trackID] = track;
    [self notifyTrack:track change:oldTrack ? kLibraryTrackSaved : kLibraryTrackAdded];
  }
}

+ (LocalLibrary *)shared {
  @synchronized(sharedLocalLibraryLock) {
    if (!localLibrary) {
      localLibrary = [[LocalLibrary alloc] initWithDBPath:LocalLibraryPath()];
    }
    return localLibrary;
  }
}

- (int)count {
  return trackTable_.count;
}

- (void)each:(void (^)(NSMutableDictionary *))block {
  [trackTable_ eachValue:^(id item) {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:item];
    if (d[@"path"]) {
      d[kTrackURL] = [NSURL fileURLWithPath:d[@"path"]];
    }
    block(d);
  }];
}

- (void)scan:(NSArray *)paths {
  __block LocalLibrary *weakSelf = self;
  dispatch_async(indexQueue_, ^{
    for (NSString *p in paths) {
      [weakSelf noteAddedPath:p];
      [weakSelf scanPath:p];
    }
  });
}

- (void)prune {
  __block LocalLibrary *weakSelf = self;
  dispatch_async(pruneQueue_, ^{
    [weakSelf retain];
    [weakSelf each:^(NSMutableDictionary *track) {
      if (!ModifiedAt(track[kTrackPath])) {
        weakSelf[track[kTrackID]] = nil;
      }
    }];
    [weakSelf release];
  });
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
  NSArray *oldPaths = [[NSUserDefaults standardUserDefaults] arrayForKey:kPathsToScan];
  if (oldPaths && paths && [oldPaths isEqualToArray:paths]) {
    return;
  }
  INFO(@"set paths to automatically scan: %@", paths);
  [d setObject:paths forKey:kPathsToScan];
  [d synchronize];
  [[NSNotificationCenter defaultCenter]
    postNotificationName:kScanPathsChanged
    object:self];
  [self monitorPaths];
}
- (void)checkITunesImport {
  ForkWith(^{
    if (!self.isITunesImported) {
      NSMutableArray *paths = [NSMutableArray array];
      GetITunesTracks(^(NSMutableDictionary *t) {
        NSString *path = t[kTrackPath];
        [paths addObject:path];
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

