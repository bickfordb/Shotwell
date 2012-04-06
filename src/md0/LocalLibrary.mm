
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

static void *PruneThread(void *ctx);
static void *ScanThread(void *ctx);
bool IsTrackKey(const string &key);

@interface LocalLibrary (P)  
- (void)scanQueuedPaths;
- (void)pruneQueued;
@end

const char *kTrackTablePrefix = "t:";
const char *kURLTablePrefix = "u:";

bool IsTrackKey(const string &key) {
  return key.find(kTrackTablePrefix, 0) == 0;
}

@implementation TrackTable 
- (char *)encodeKey:(id)key length:(size_t *)length {
  NSNumber *trackID = (NSNumber *)key;
  uint32_t trackID0 = htonl([trackID unsignedIntValue]);
  size_t prefixLength = strlen(kTrackTablePrefix);
  size_t keyLength = key ? (prefixLength + sizeof(trackID0)) : prefixLength;
  char *ret = (char *)malloc(keyLength);
  memcpy(ret, kTrackTablePrefix, prefixLength);
  if (key) 
    memcpy(ret + prefixLength, &trackID0, sizeof(trackID0));
  *length = keyLength;
  return ret;
}

- (char *)encodeValue:(id)value length:(size_t *)length {

  NSDictionary *trackDictionary = (NSDictionary *)value;
  json_t *js = [trackDictionary getJSON];
  char *ret = js ? json_dumps(js, 0) : NULL;
  *length = (js && ret) ? strlen(ret) + 1 : 0;      
  if (js) 
    json_decref(js); 
  return ret; 
}

- (id)decodeValue:(const char *)bytes length:(size_t)length {
  return length > 0 ? FromJSONBytes(bytes) : nil;
}

- (id)decodeKey:(const char *)bytes length:(size_t)length {
  uint32_t val;
  memcpy(&val, bytes + strlen(kTrackTablePrefix), sizeof(val));
  val = ntohl(val);
  return [NSNumber numberWithUnsignedInt:val];
}
@end

@implementation URLTable
- (char *)encodeKey:(id)key length:(size_t *)length {
  NSString *trackURL = (NSString *)key;
  size_t keyLength = strlen(kURLTablePrefix);
  const char *key0 = key ? ((NSString *)key).UTF8String : "";
  if (key) {
    keyLength += strlen(key0);
  }
  char *ret = (char *)malloc(keyLength);
  memcpy(ret, kURLTablePrefix, strlen(kURLTablePrefix));
  if (key) 
    memcpy(ret + strlen(kURLTablePrefix), key0, strlen(key0));
  *length = keyLength;
  return ret;
}

- (char *)encodeValue:(id)value length:(size_t *)length {
  json_t *js = [((NSNumber *)value) getJSON];
  char *ret = js ? json_dumps(js, 0) : NULL;   
  *length = (js && ret) ? strlen(ret) + 1 : 0;
  if (js)
    json_decref(js);   
  return ret;
}

- (id)decodeValue:(const char *)bytes length:(size_t)length {
  return length > 0 ? FromJSONBytes(bytes) : nil;
}

- (id)decodeKey:(const char *)bytes length:(size_t)length {
  size_t prefixLength = strlen(kURLTablePrefix);
  id ret = [[[NSString alloc] 
    initWithBytes:bytes length:length - prefixLength encoding:NSUTF8StringEncoding] autorelease];
  return ret;
}

@end


@implementation LocalLibrary

- (id)initWithPath:(NSString *)path {  
  self = [super init];
  if (self) {
    Level *level = [[[Level alloc] initWithPath:path] autorelease]; 
    urlTable_ = [[URLTable alloc] initWithLevel:level];
    trackTable_ = [[TrackTable alloc] initWithLevel:level];
    pathsToScan_ = [[NSMutableSet set] retain];
    pruneRequested_ = false;
    pruneLoop_ = [[Loop alloc] init];
    scanLoop_ = [[Loop alloc] init];
    scanEvent_ = [[Event timeoutEventWithLoop:scanLoop_ interval:1000000] retain];
    scanEvent_.delegate = self;

    pruneEvent_ = [[Event timeoutEventWithLoop:pruneLoop_ interval:1000000] retain];
    pruneEvent_.delegate = self;
    [pruneLoop_ start];
    [scanLoop_ start];
  }
  return self;
}

- (void)eventTimeout:(Event *)e { 
  if (e == scanEvent_) {
    [self scanQueuedPaths];
  }
  if (e == pruneEvent_) {
    if (pruneRequested_) {
      pruneRequested_ = false;
      [self pruneQueued];
    }
  }
}

- (void)dealloc { 
  [scanEvent_ release];
  [pruneEvent_ release];
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
      NSMutableDictionary *t = [NSMutableDictionary dictionary];
      [t setObject:filename forKey:kURL];
      ReadTag(filename, t);
      [self save:t];
    } else { 
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
    [scanLoop_ start];
    [pruneLoop_ start];
    self.lastUpdatedAt = Now();
  }
  return self;
}
- (void)pruneQueued {
  [trackTable_ each:^(id key, id val) {
    NSDictionary *track = (NSDictionary *)val;    
    NSString *path = [track objectForKey:kURL];
    struct stat fsStatus;
    if (stat(path.UTF8String, &fsStatus) < 0 && errno == ENOENT) {
      [self delete:track];
    }
  }];
}     

- (void)save:(NSDictionary *)track { 
  NSString *url = [track objectForKey:kURL];
  NSNumber *trackID = [track objectForKey:kID];
  if (!url || !url.length) 
    return;
  NSMutableDictionary *track0 = [NSMutableDictionary dictionaryWithDictionary:track];
  if (!trackID) {
    trackID = [trackTable_ nextID];
    [track0 setObject:trackID forKey:kID];
  }
  [urlTable_ put:trackID forKey:url];
  [trackTable_ put:track0 forKey:trackID];
  self.lastUpdatedAt = Now();
}

- (NSDictionary *)get:(NSNumber *)trackID {
  return [trackTable_ get:trackID]; 
}

- (void)clear {
  [urlTable_ clear];
  [trackTable_ clear];
}

- (void)delete:(NSDictionary *)track { 
  NSNumber *key = [track objectForKey:kID];
  NSString *url = [track objectForKey:kURL];
  [trackTable_ delete:key];
  if (url) 
    [urlTable_ delete:url];
  self.lastUpdatedAt = Now();
}


- (int)count { 
  return [trackTable_ count];
}

- (void)each:(void (^)(NSDictionary *track))block {
  [trackTable_ each:^(id key, id val) {
    block((NSDictionary *)val);
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

