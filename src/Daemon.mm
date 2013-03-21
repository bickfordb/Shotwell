#include <sys/utsname.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string>

#import "Daemon.h"
#import "HTTP.h"
#import "JSON.h"
#import "Log.h"
#import "Track.h"

const int kDaemonDefaultPort = 6226;
NSString * const kDaemonServiceType = @"_shotwell._tcp.";
static Daemon *daemon;

@interface Request : NSObject {
  struct evhttp_request *req_;
}
- (id)initWithRequest:(evhttp_request *)req;
- (NSString *)path;
- (void)respondWithStatus:(int)status message:(NSString *)message body:(NSString *)body;
- (void)respondWithStatus:(int)status message:(NSString *)message buffer:(struct evbuffer *)buffer;
- (void)addResponseHeader:(NSString *)key value:(NSString *)value;
- (NSDictionary *)headers;
@end

@implementation Request
- (id)initWithRequest:(evhttp_request *)req {
  self = [super init];
  if (self) {
    req_ = req;
  }
  return self;
}
- (void)dealloc {
  req_ = NULL;
  [super dealloc];
}

- (NSString *)path {
    const struct evhttp_uri *uri = evhttp_request_get_evhttp_uri(req_);
    const char *p0 = evhttp_uri_get_path(uri);
    size_t sz = 0;
    char *p = evhttp_uridecode(p0, 1, &sz);
    NSString *ret = [[[NSString alloc] initWithBytesNoCopy:p length:sz encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];
    return ret;
}

- (NSDictionary *)headers {
  return FromEvKeyValQ(evhttp_request_get_input_headers(req_));
}

- (void)respondWithStatus:(int)status message:(NSString *)message body:(NSString *)body {
  struct evbuffer *buffer = evbuffer_new();
  evbuffer_add_printf(buffer, "%s", body.UTF8String);
  evhttp_send_reply(req_, status, message.UTF8String, buffer);
  evbuffer_free(buffer);
}

- (void)respondWithStatus:(int)status message:(NSString *)message buffer:(struct evbuffer *)buffer {
  evhttp_send_reply(req_, status, message.UTF8String, buffer);
}

- (void)respondNotFound {
  [self respondWithStatus:404 message:@"Not Found" body:@""];
}
- (void)addResponseHeader:(NSString *)key value:(NSString *)value {
  struct evkeyvalq *headers = evhttp_request_get_output_headers(req_);
  evhttp_add_header(headers, key.UTF8String, value.UTF8String);
}

@end

static void ParseRangeHeader(NSString *s, int *startByte, int *endByte) {
  *startByte = -1;
  *endByte = -1;
  if (!s)
    return;
  NSScanner *sc = [NSScanner scannerWithString:s];
  [sc scanString:@"bytes=" intoString:NULL];
  if ([sc scanInt:startByte]) {
    [sc scanString:@"-" intoString:NULL];
    [sc scanInt:endByte];
  }
}

static void OnRequest(evhttp_request *r, void *ctx) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  Request *request = [[[Request alloc] initWithRequest:r] autorelease];
  [((Daemon *)ctx) handleRequest:request];
  [pool release];
}

@implementation Daemon
@synthesize netService = netService_;

+ (Daemon *)shared {
  if (!daemon) {
    daemon = [[Daemon alloc]
      initWithHost:@"0.0.0.0"
      port:kDaemonDefaultPort
      library:self.localLibrary];
  }
}
- (bool)handleHomeRequest:(Request *)r {
  if (![r.path isEqualToString:@"/"])
    return false;
  [r addResponseHeader:@"Content-Type" value:@"application/json"];
  struct utsname uname_data;
  uname(&uname_data);
  NSString *json = [[NSDictionary dictionaryWithObjectsAndKeys:
    [NSString stringWithUTF8String:uname_data.nodename], @"name",
    [NSNumber numberWithInt:[library_ count]], @"total",
    nil] getJSONEncodedString];
  [r respondWithStatus:200 message:@"OK" body:json];
  return true;
}

- (bool)handleLibraryRequest:(Request *)r {
  if (![r.path isEqualToString:@"/tracks"])
    return false;
  [r addResponseHeader:@"Content-Type" value:@"application/json"];
  NSMutableArray *tracks = [NSMutableArray array];
  NSArray *keys = [NSArray arrayWithObjects:kTrackArtist, kTrackID, kTrackAlbum, kTrackCreatedAt, kTrackUpdatedAt, kTrackCoverArtID, kTrackGenre, kTrackLastPlayedAt, kTrackPath, kTrackPublisher, kTrackCreatedAt, kTrackTitle, kTrackDuration, kTrackNumber, kTrackYear, nil];

  [library_ each:^(NSMutableDictionary *track) {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *k in keys) {
      d[k] = track[k];
    }
    [tracks addObject:d];
  }];
  [r respondWithStatus:200 message:@"OK" body:[tracks getJSONEncodedString]];
  return true;
}

- (bool)handleArtworkRequest:(Request *)request {
  struct evbuffer *buf = NULL;
  [request
    respondWithStatus:404
    message:@"Not Found"
    buffer:buf];
  return true;
}


- (bool)handleTrackRequest:(Request *)request {
  [request respondWithStatus:404 message:@"Not Found" buffer:NULL];
  /*
  NSScanner *scanner = [NSScanner scannerWithString:request.path];
  NSString *s = nil;
  if (![scanner scanString:@"/tracks/" intoString:&s]) {
    return false;
  }
  int trackID = -1;
  if (![scanner scanInt:&trackID]) {
    return false;
  }

  // make sure it's a real track
  NSMutableDictionary *track = [library_ get:[NSNumber numberWithLongLong:trackID]];
  if (!track || !track[kURL].isFileURL) {
    DEBUG(@"no track");
    [request respondNotFound];
    return true;
  }

  int fd = open(track.url.path.UTF8String, O_RDONLY);
  if (fd < 0) {
    DEBUG(@"missing fd");
    [request respondNotFound];
    return true;
  }

  struct stat the_stat;
  if (fstat(fd, &the_stat) < 0) {
    DEBUG(@"stat failed");
    [request respondNotFound];
    return true;
  }
  NSString *guessContentType = @"application/octet-stream";
  if (strcasestr(guessContentType.UTF8String, ".mp3"))
    guessContentType = @"audio/mpeg";
  // fill me in
  [request addResponseHeader:@"Content-Type" value:guessContentType];
  [request addResponseHeader:@"Accept-Ranges" value:@"bytes"];
  struct evbuffer *buf = evbuffer_new();

  int offset = 0;
  int len = the_stat.st_size;
  int startByte = -1;
  int endByte = -1;

  NSString *rangeHeader = [request.headers objectForKey:@"Range"];
  ParseRangeHeader(rangeHeader, &startByte, &endByte);
  int status = 200;
  NSString *msg = @"OK";
  if (startByte >= 0 && endByte >= 0) {
    offset = startByte;
    len = 1 + (endByte - startByte);
    status = 206;
    msg = @"Partial Content";
  } else if (startByte >= 0) {
    offset = startByte;
    len = the_stat.st_size - offset;
    status = 206;
    msg = @"Partial Content";
  }
  [request
    addResponseHeader:@"Content-Range"
    value:[NSString stringWithFormat:@"bytes %d-%d/%d",
            (int)offset,
            (int)(offset + len - 1),
            (int)the_stat.st_size]];
  evbuffer_add_file(buf, fd, offset, len);
  [request respondWithStatus:status message:msg buffer:buf];
  evbuffer_free(buf);
  */
  return true;
}

- (void)handleRequest:(Request *)request {
  [request addResponseHeader:@"Server" value:@"0.0"];
  if ([self handleHomeRequest:request])
    return;
  else if ([self handleLibraryRequest:request])
    return;
  else if ([self handleArtworkRequest:request])
    return;
  else if ([self handleTrackRequest:request])
    return;
  else
    [request respondNotFound];
}

- (id)initWithHost:(NSString *)host port:(int)port library:(LocalLibrary *)library {
  self = [super init];
  if (self) {
    library_ = [library retain];
    loop_ = [[Loop alloc] init];
    eventHTTP_ = evhttp_new(loop_.base);
    evhttp_bind_socket(eventHTTP_, host.UTF8String, port);
    evhttp_set_gencb(eventHTTP_, OnRequest, self);
    struct utsname the_utsname;
    uname(&the_utsname);
    NSString *nodeName = [NSString stringWithUTF8String:the_utsname.nodename];
    self.netService = [[[NSNetService alloc]
      initWithDomain:@"local."
      type:kDaemonServiceType
      name:nodeName
      port:kDaemonDefaultPort] autorelease];
    [self.netService publish];
    [self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
  }
  return self;
}

- (void)dealloc {
  [loop_ release];
  [library_ release];
  [netService_ release];
  evhttp_free(eventHTTP_);
  [super dealloc];
}
@end

