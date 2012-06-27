
#include <errno.h>
#include <fts.h>
#include <stdio.h>
#include <sys/stat.h>
#include <string>
#include <leveldb/slice.h>

#import "app/AppDelegate.h"
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
#import "app/Util.h"

#define GET_URL_KEY(url) (kURLTablePrefix + url)
static NSString * const kPathsToScan = @"PathsToScan";
static NSString * const kIsITunesImported = @"IsITunesImported";
NSString * const kScanPathsChanged = @"ScanPathsChanged";
static CFTimeInterval kMonitorLatency = 2.0;
static NSString * const kITunesAffiliateURL = @"http://itunes.apple.com/search";
static int kMaxConcurrentCoverArtQueries = 1;
static int kCheckCoverArtDelay = 10 * 1000000;

@interface LocalLibrary (P)
- (void)scanQueuedPaths;
- (void)pruneQueued;
- (void)monitorPaths;
- (void)search:(NSString *)d entity:(NSString *)entity withResult:(void(^)(int status, NSArray *results))onResults;
- (void)searchCoverArt:(NSString *)term withArtworkData:(void (^)(int status, NSData *d))block;
- (void)popPendingCoverArt;
@end

@implementation TrackTable
- (const char *)keyPrefix {
  return "t:";
}

- (id)decodeValue:(const char *)bytes length:(size_t)length {
  NSDictionary *v = [super decodeValue:bytes length:length];
  return [Track fromJSON:v];
}
@end

@implementation URLTable
- (const char *)keyPrefix {
  return "u:";
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

@implementation LocalLibrary
@synthesize trackTable = trackTable_;
@synthesize coverArtLoop = coverArtLoop_;
@synthesize urlTable = urlTable_;
@synthesize pathsToScan = pathsToScan_;
@synthesize pruneRequested = pruneRequested_;
@synthesize pruneLoop = pruneLoop_;
@synthesize scanLoop = scanLoop_;
@synthesize pathsToAutomaticallyScan = pathsToAutomaticallyScan_;
@synthesize pendingCoverArtTracks = pendingCoverArtTracks_;
@synthesize coverArtDB = coverArtDB_;

- (void)search:(NSString *)term withArtworkData:(void (^)(int code, NSData *d))block {
  __block LocalLibrary *weakSelf = self;
  block = [block copy];
  [self search:term entity:@"album" withResult:^(int status, NSArray *results) {
    if (results && results.count) {
      NSString *artworkURL = [[results objectAtIndex:0] objectForKey:@"artworkUrl100"];
      artworkURL = [artworkURL
        stringByReplacingOccurrencesOfString:@".100x100" withString:@".600x600"];
      if (artworkURL && artworkURL.length) {
        [weakSelf.coverArtLoop fetchURL:[NSURL URLWithString:artworkURL] with:^(HTTPResponse *response) {
          block(response.status, response.status == 200 ? response.body : nil);
        }];
      } else {
        block(status, nil);
      }
    } else {
      block(status, nil);
    }
  }];
}

- (void)search:(NSString *)term entity:(NSString *)entity withResult:(void(^)(int status, NSArray *results))onResults {
  onResults = [onResults copy];
  NSURL *url = [NSURL URLWithString:kITunesAffiliateURL];
  url = [url pushKey:@"term" value:term];
  url = [url pushKey:@"entity" value:entity];
  [coverArtLoop_ fetchURL:url with:^(HTTPResponse *r) {
    NSArray *results = [NSArray array];
    if (r.status == 200) {
      NSDictionary *data = (NSDictionary *)r.body.decodeJSON;
      results = [data objectForKey:@"results"];
    }
    onResults(r.status, results);
  }];
}

- (id)initWithDBPath:(NSString *)dbPath
  coverArtPath:(NSString *)coverArtPath {
  self = [super init];
  if (self) {
    self.coverArtLoop = [Loop loop];
    //self.coverArtPath = coverArtPath;
    Level *level = [[[Level alloc] initWithPath:dbPath] autorelease];
    urlTable_ = [[URLTable alloc] initWithLevel:level];
    trackTable_ = [[TrackTable alloc] initWithLevel:level];
    self.coverArtDB = [[[Level alloc] initWithPath:coverArtPath] autorelease];
    self.pendingCoverArtTracks = [NSMutableSet set];
    self.pathsToScan = [NSMutableSet set];
    self.pruneRequested = false;
    self.pruneLoop = [Loop loop];
    self.scanLoop = [Loop loop];
    __block LocalLibrary *weakSelf = self;
    [pruneLoop_ onTimeout:1000000 with:^(Event *e, short flags) {
      LocalLibrary *self0 = (LocalLibrary *)weakSelf;
      if (self0.pruneRequested) {
        self0.pruneRequested = false;
        [self0 pruneQueued];
      }
      [e add:1000000];
    }];
    [scanLoop_ onTimeout:1000000 with:^(Event *e, short flags) {
      [weakSelf scanQueuedPaths];
      [e add:1000000];
    }];

    numCoverArtQueries_ = 0;
    [coverArtLoop_ every:10000 with:^{
      [weakSelf popPendingCoverArt];
    }];

    fsEventStreamRef_ = nil;
    [self monitorPaths];
  }
  return self;
}

- (void)checkCoverArt {
  __block LocalLibrary *weakSelf = self;
  [coverArtLoop_ onTimeout:kCheckCoverArtDelay with:^(Event *e, short flags) {
    [weakSelf each:^(Track *t) {
      if (!t.coverArtURL)
        return;
      if (t.isCoverArtChecked.boolValue)
        return;
      @synchronized(weakSelf.pendingCoverArtTracks) {
        [weakSelf.pendingCoverArtTracks addObject:t.id];
      }
    }];
  }];
}

- (void)popPendingCoverArt {
  if (numCoverArtQueries_ >= kMaxConcurrentCoverArtQueries)
    return;
  @synchronized(pendingCoverArtTracks_) {
    NSNumber *trackID = pendingCoverArtTracks_.anyObject;
    Track *track = [self get:trackID];
    if (trackID) {
      [pendingCoverArtTracks_ removeObject:trackID];
    }
    if (track) {
      [self checkCoverArtForTrack:track];
    }
  }
}

- (void)checkCoverArtForTrack:(Track *)track {
  __block LocalLibrary *weakSelf = self;
  NSString *artist = track.artist;
  NSString *album = track.album;
  if (!track || !artist || !artist.length || !album || !album.length
    || track.isCoverArtChecked.boolValue) {
    return;
  }
  NSString *term = [NSString stringWithFormat:@"%@ %@", artist, album];
  NSString *coverArtID = term.sha1;
  if ([self hasCoverArt:coverArtID]) {
    track.coverArtID = coverArtID;
    track.isCoverArtChecked = [NSNumber numberWithBool:YES];
    [self save:track];
    return;
  }
  numCoverArtQueries_++;
  [self search:term withArtworkData:^(int status, NSData *data) {
    numCoverArtQueries_--;
    if (data) {
      [self saveCoverArt:coverArtID data:data];
    }
    Track *t = [weakSelf get:track.id];
    if (data) {
      t.coverArtID = coverArtID;
    }
    t.isCoverArtChecked = [NSNumber numberWithBool:YES];
    [self save:t];
  }];
}

- (bool)hasCoverArt:(NSString *)coverArtID {
  return [self getCoverArt:coverArtID] != nil;
}

- (void)saveCoverArt:(NSString *)coverArtID data:(NSData *)data {
  const char *s = coverArtID.UTF8String;
  NSData *coverArtID0 = [NSData dataWithBytes:s length:strlen(s)];
  return [coverArtDB_ setData:data forKey:coverArtID0];
}

- (NSData *)getCoverArt:(NSString *)coverArtID {
  const char *s = coverArtID.UTF8String;
  NSData *coverArtID0 = [NSData dataWithBytes:s length:strlen(s)];
  return [coverArtDB_ getDataForKey:coverArtID0];
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
  [coverArtLoop_ release];
  [pruneLoop_ release];
  [scanLoop_ release];
  if (fsEventStreamRef_) {
    FSEventStreamStop(fsEventStreamRef_);
    FSEventStreamInvalidate(fsEventStreamRef_);
    FSEventStreamRelease(fsEventStreamRef_);
    fsEventStreamRef_ = nil;
  }

  [pendingCoverArtTracks_ release];
  [coverArtDB_ release];
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
      NSURL *url = [NSURL fileURLWithPath:filename] ;
      NSNumber *trackID = [urlTable_ get:url.absoluteString];
      if (!trackID) {
        Track *t = [[[Track alloc] init] autorelease];
        t.path = filename;
        t.library = self;
        [t readTag];
        if (!t.title || !t.title.length) {
          t.title = filename.lastPathComponent.stringByDeletingPathExtension;
        }
        // Only index things with audio:
        // This will skip JPEG/photo files but allow almost other media files that LibAV can read through.
        if (t.isAudio.boolValue) {
          [self save:t];
          @synchronized(pendingCoverArtTracks_) {
            [pendingCoverArtTracks_ addObject:t.id];
          }
        } else {
        }
      } else {
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
    track.library = self;
    struct stat fsStatus;
    if (stat(track.url.path.UTF8String, &fsStatus) < 0 && errno == ENOENT) {
      [self delete:track];
    }
  }];
}

- (void)save:(Track *)track {
  NSURL *url = track.url;
  if (!url) {
    return;
  }
  bool isNew = false;
  if (!track.id) {
    track.id = [trackTable_ nextID];
    isNew = true;
  }
  [urlTable_ put:track.id forKey:track.url.absoluteString];
  [trackTable_ put:track forKey:track.id];
  if (isNew) {
    [self notifyTrack:track change:kLibraryTrackAdded];
  } else {
    [self notifyTrack:track change:kLibraryTrackSaved];
  }
  self.lastUpdatedAt = Now();
}


- (Track *)get:(NSNumber *)trackID {
  Track *t = [trackTable_ get:trackID];
  t.library = self;
  return t;
}

- (void)clear {
  [urlTable_ clear];
  [trackTable_ clear];
}

- (void)delete:(Track *)track {
  [trackTable_ delete:track.id];
  if (track.url)
    [urlTable_ delete:track.url.absoluteString];
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
@end

