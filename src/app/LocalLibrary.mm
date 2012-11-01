
#include <errno.h>
#include <fts.h>
#include <stdio.h>
#include <sys/stat.h>
#include <string>
#include <leveldb/slice.h>

#import "app/AppDelegate.h"
#import "app/CoverArtScraper.h"
#import "app/HTTP.h"
#import "app/HTTPResponse.h"
#import "app/ITunesScan.h"
#import "app/JSON.h"
#import "app/LocalLibrary.h"
#import "app/Log.h"
#import "app/NSStringDigest.h"
#import "app/NSURLAdditions.h"
#import "app/PThread.h"
#import "app/Track.h"
#import "app/Tuple.h"
#import "app/Util.h"
#import "app/pb/Track.pb.h"

static NSString * const kPathsToScan = @"PathsToScan";
static NSString * const kIsITunesImported = @"IsITunesImported";
NSString * const kScanPathsChanged = @"ScanPathsChanged";
static CFTimeInterval kMonitorLatency = 2.0;

NSString *DecodeString(const leveldb::Slice *data) {
  return [[[NSString alloc] initWithBytes:data->data() length:data->size() encoding:NSUTF8StringEncoding] autorelease];
}

NSData *DecodeData(const leveldb::Slice *data) {
  return [NSData dataWithBytes:data->data() length:data->size()];
}

void EncodeDataTo(NSData *data, std::string *out) {
  if (data) {
    out->append((const char *)data.bytes, data.length);
  }
}

void EncodeStringTo(NSString *s, std::string *out) {
  if (s) {
    out->append(s.UTF8String);
  }
}

void EncodeUInt64(uint64_t v, std::string *out) {
  out->append(((const char *)&v), sizeof(v));
}

uint64_t DecodeUInt64(const leveldb::Slice *slice) {
  uint64_t result = 0;
  if (slice->size() >= sizeof(result)) {
    result = *((uint64_t *)slice->data());
  }
  return result;
}

@interface TrackTable : LevelTable {
}
@end

@interface PathIndex : LevelTable {
}
@end

@interface CoverArtTable : LevelTable {
}
@end

@interface LocalLibrary (Private)
- (void)monitorPaths;
- (Track *)index:(NSString *)path;
- (void)checkCoverArtForTrack:(uint64_t)trackID;
- (bool)hasCoverArt:(NSString *)coverArtID;
- (void)saveCoverArt:(NSString *)coverArtID data:(NSData *)data;
@end

@implementation TrackTable
- (id)decodeValue:(const leveldb::Slice *)bytes {
  Track *t = [[[Track alloc] init] autorelease];
  [t message]->ParsePartialFromArray(bytes->data(), bytes->size());
  return t;
}

- (void)encodeValue:(id)val to:(std::string *)dst {
  Track *t = (Track *)val;
  [t message]->SerializeToString(dst);
}

- (void)encodeKey:(id)key to:(std::string *)dst {
  EncodeUInt64([((NSNumber *)key) unsignedLongLongValue], dst);
}

- (id)decodeKey:(const leveldb::Slice *)key {
  return @(DecodeUInt64(key));
}
@end

@implementation CoverArtTable
- (void)encodeKey:(id)key to:(std::string *)out {
  EncodeStringTo(key, out);
}

- (id)decodeKey:(const leveldb::Slice *)data {
  return DecodeString(data);
}

- (void)encodeValue:(id)key to:(std::string *)out {
  return EncodeDataTo(key, out);
}

- (id)decodeValue:(const leveldb::Slice *)value {
  return DecodeData(value);
}
@end

@implementation PathIndex

- (id)decodeValue:(const leveldb::Slice *)bytes {
  return @(DecodeUInt64(bytes));
}

- (void)encodeValue:(id)val to:(std::string *)out {
  EncodeUInt64([((NSNumber *)val) unsignedLongLongValue], out);
}

- (void)encodeKey:(id)key to:(std::string *)out {
  EncodeStringTo(key, out);
}

- (id)decodeKey:(const leveldb::Slice *)key {
  return DecodeString(key);
}
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
  TrackTable *trackTable_;
  PathIndex *pathIndex_;
  dispatch_queue_t indexQueue_;
  dispatch_queue_t pruneQueue_;
  dispatch_queue_t coverArtQueue_;
  dispatch_queue_t acoustIDQueue_;
  int numCoverArtQueries_;
  FSEventStreamRef fsEventStreamRef_;
  NSMutableSet *pendingCoverArtTracks_;
  CoverArtTable *coverArtTable_;
}

- (id)initWithDBPath:(NSString *)dbPath {
  self = [super init];
  if (self) {
    indexQueue_ = dispatch_queue_create("shotwell.index", NULL);
    pruneQueue_ = dispatch_queue_create("shotwell.prune", NULL);
    coverArtQueue_ = dispatch_queue_create("shotwell.cover-art", NULL);
    acoustIDQueue_ = dispatch_queue_create("shotwell.acoustid", NULL);

    pathIndex_ = [[PathIndex alloc] initWithPath:[dbPath stringByAppendingPathComponent:@"paths"]];
    trackTable_ = [[TrackTable alloc] initWithPath:[dbPath stringByAppendingPathComponent:@"tracks"]];
    coverArtTable_ = [[CoverArtTable alloc] initWithPath:[dbPath stringByAppendingPathComponent:@"cover-art"]];
    pendingCoverArtTracks_ = [[NSMutableSet set] retain];
    fsEventStreamRef_ = nil;
    [self monitorPaths];
  }
  return self;
}


- (void)queueCheckCoverArt:(Track *)track {
  uint64_t id = track.id;
  __block LocalLibrary *weakSelf = self;
  dispatch_async(coverArtQueue_, ^{
    [weakSelf checkCoverArtForTrack:id];
  });
}

- (void)checkCoverArt {
  __block LocalLibrary *weakSelf = self;
  dispatch_async(coverArtQueue_, ^{
    [weakSelf each:^(Track *t) {
      uint64_t trackID = t.id;
      if (!t.isCoverArtChecked) {
        dispatch_async(weakSelf->coverArtQueue_, ^{
          [weakSelf checkCoverArtForTrack:trackID];
        });
      }
    }];
  });
}

- (void)checkCoverArtForTrack:(uint64_t)trackID {
  Track *track = trackTable_[@(trackID)];
  NSString *artist = track.artist;
  NSString *album = track.album;
  if (!track || !artist || !artist.length || !album || !album.length
    || track.isCoverArtChecked) {
    return;
  }
  NSString *term = [NSString stringWithFormat:@"%@ %@", artist, album];
  NSString *coverArtID = term.sha1;
  NSData *coverArt = coverArtTable_[coverArtID];
  if (coverArt) {
    track.coverArtID = coverArtID;
    track.isCoverArtChecked = YES;
    return;
  } else {
    NSData *artwork = ScrapeCoverArt(term);
    if (artwork) {
      DEBUG(@"found cover art for term: %@", term);
      coverArtTable_[coverArtID] = artwork;
    } else {
      // 0 length entries => 404
      DEBUG(@"couldn't find cover art for: %@", term);
      coverArtTable_[coverArtID] = [NSData data];
    }
  }
  track.isCoverArtChecked = YES;
  [self save:track];
}

- (bool)hasCoverArt:(NSString *)coverArtID {
  return [self getCoverArt:coverArtID] != nil;
}

- (void)saveCoverArt:(NSString *)coverArtID data:(NSData *)data {
  coverArtTable_[coverArtID] = data;
}

- (NSData *)getCoverArt:(NSString *)coverArtID {
  return coverArtTable_[coverArtID];
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
  dispatch_release(coverArtQueue_);
  dispatch_release(indexQueue_);
  dispatch_release(pruneQueue_);
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
  [self noteAddedPath:path];
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

- (Track *)index:(NSString *)filename {
  if (!filename)
    return nil;
  uint64_t lastModified = ModifiedAt(filename);
  if (!lastModified) {
    // Not Found
    return nil;
  }
  NSNumber *trackID = [pathIndex_ get:filename];
  Track *t = trackID ? [trackTable_ get:trackID] : nil;
  if (!t) {
    t = [[[Track alloc] init] autorelease];
    t.path = filename;
    t.library = self;
    [t readTag];
    if (!t.title || !t.title.length) {
      t.title = filename.lastPathComponent.stringByDeletingPathExtension;
    }
    // Only index things with audio:
    // This will skip JPEG/photo files but allow almost other media files that LibAV can read through.
    if (t.isAudio) {
      [self save:t];
      @synchronized(pendingCoverArtTracks_) {
        [pendingCoverArtTracks_ addObject:@(t.id)];
      }
      [self checkCoverArtForTrack:t.id];
    } else {
      DEBUG(@"missing audio, skipping: %@", t);
    }
  } else {
    if (t.createdAt < lastModified) {
      DEBUG(@"re-indexing: %@ because %llu < %llu", t.path, t.createdAt, lastModified);
      [t readTag];
      [self save:t];
    }
  }
  return t;
}

- (void)save:(Track *)track {
  DEBUG(@"%@: saving %@", self, track);
  if (!track.path) {
    return;
  }
  track.library = self;
  bool isNew = track.id == 0;
  if (isNew) {
    track.id = [[trackTable_ nextID] unsignedLongValue];
  }
  pathIndex_[track.path] = @(track.id);
  trackTable_[@(track.id)] = track;
  if (isNew) {
    [self notifyTrack:track change:kLibraryTrackAdded];
  } else {
    [self notifyTrack:track change:kLibraryTrackSaved];
  }
  self.lastUpdatedAt = Now();
}


- (Track *)get:(NSNumber *)trackID {
  Track *t = trackID ? [trackTable_ get:trackID] : nil;
  t.library = self;
  return t;
}

- (void)clear {
  [pathIndex_ clear];
  [trackTable_ clear];
}

- (void)delete:(Track *)track {
  [trackTable_ delete:@(track.id)];
  if (track.url)
    [pathIndex_ delete:track.path];
  self.lastUpdatedAt = Now();
  [self notifyTrack:track change:kLibraryTrackDeleted];
}

- (int)count {
  return trackTable_.count;
}

- (void)each:(void (^)(Track *track))block {
  [trackTable_ each:^(id key, id val) {
    Track *t = (Track *)val;
    t.library = self;
    block(t);
  }];
}

- (void)scan:(NSArray *)paths {
  DEBUG(@"scan: %@", paths);
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
  dispatch_async(
    pruneQueue_, ^{
      [weakSelf->trackTable_ each:^(id key, id val) {
        Track *track = (Track *)val;
        track.library = weakSelf;
        struct stat fsStatus;
        if (stat(track.path.UTF8String, &fsStatus) < 0 && errno == ENOENT) {
        [weakSelf delete:track];
        }
    }];
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
  [d setObject:paths forKey:kPathsToScan];
  [d synchronize];
  [[NSNotificationCenter defaultCenter]
    postNotificationName:kScanPathsChanged
    object:self];
  [self monitorPaths];
}
- (void)checkITunesImport {
  ForkWith(^{
    usleep(1000);
    if (!self.isITunesImported) {
      NSMutableArray *paths = [NSMutableArray array];
        GetITunesTracks(^(Track *t) {
          [paths addObject:t.path];
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

- (NSURL *)coverArtURLForTrack:(Track *)t {
  NSString *c = t.coverArtID;
  return c ? [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:6226/art/%@", c]] : nil;
}

- (NSURL *)urlForTrack:(Track *)t {
  NSString *path = t.path;
  return path ? [NSURL fileURLWithPath:path] : nil;
}

- (void)checkAcoustIDs {
  dispatch_async(acoustIDQueue_, ^{
    [self each:^(Track *t) {
      if (!t.isAcoustIDChecked) {
        [t refreshAcoustID];
      }
    }];
  });
}

@end

