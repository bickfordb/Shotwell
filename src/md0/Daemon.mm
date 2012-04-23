#include <sys/utsname.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string>

#import "Daemon.h"
#import "JSON.h"
#import "Log.h"
#import "Track.h"

const int kDaemonDefaultPort = 6226;

static void *MainThread(void *ctx); 

@interface Request : NSObject { 
  struct evhttp_request *req_;
}
- (id)initWithRequest:(evhttp_request *)req;
- (NSString *)path;
- (void)respondWithStatus:(int)status message:(NSString *)message body:(NSString *)body;
- (void)respondWithStatus:(int)status message:(NSString *)message buffer:(struct evbuffer *)buffer;
- (void)addResponseHeader:(NSString *)key value:(NSString *)value;

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
    NSString *ret = [[[NSString alloc] initWithBytes:p length:sz encoding:NSUTF8StringEncoding] autorelease];
    free(p);
    return ret;
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

static void OnRequest(evhttp_request *r, void *ctx) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  Request *request = [[[Request alloc] initWithRequest:r] autorelease];
  [((Daemon *)ctx) handleRequest:request];
  [pool release];
}

@implementation Daemon
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
  if (![r.path isEqualToString:@"/library"])
    return false;
  [r addResponseHeader:@"Content-Type" value:@"application/json"];
  NSMutableArray *tracks = [NSMutableArray array];
  NSArray *keys = [NSArray arrayWithObjects:kArtist, kID, kAlbum, kGenre, kTitle, kDuration, kTrackNumber, kYear, nil];

  [library_ each:^(Track *t) { 
    NSMutableDictionary *d = [NSMutableDictionary dictionary]; 
    for (NSString *k in keys) { 
      [d setValue:[t valueForKey:k] forKey:k];
    }
    [tracks addObject:d];
  }];
  [r respondWithStatus:200 message:@"OK" body:[tracks getJSONEncodedString]];
  return true;
}

- (bool)handleTrackRequest:(Request *)request { 
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
  Track *track = [library_ get:[NSNumber numberWithLongLong:trackID]];
  if (!track) {
    DEBUG(@"no track");
    [request respondNotFound];
    return true;
  }
  
  int fd = open(track.url.UTF8String, O_RDONLY);
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
  int offset = 0;
  int length = the_stat.st_size;
  struct evbuffer *buf = evbuffer_new();
  evbuffer_add_file(buf, fd, offset, length);
  [request respondWithStatus:200 message:@"OK" buffer:buf];
  evbuffer_free(buf);
  return true;
}

- (void)handleRequest:(Request *)request {
  [request addResponseHeader:@"Server" value:@"md0/0.0"];
  if ([self handleHomeRequest:request])
    return;
  else if ([self handleLibraryRequest:request]) 
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
    //rootPattern_ = new pcrecpp::RE("^/$");
    //trackPattern_ = new pcrecpp::RE("^/tracks/([^/]+)$");
    //libraryPattern_ = new pcrecpp::RE("^/library$");
    loop_ = [[Loop alloc] init];
    eventHTTP_ = evhttp_new(loop_.base);
    evhttp_bind_socket(eventHTTP_, host.UTF8String, port);
    evhttp_set_gencb(eventHTTP_, OnRequest, self);
  }
  return self;
}

- (void)dealloc { 
  [loop_ release];
  [library_ release];
  //delete rootPattern_;
  //delete trackPattern_;
  //delete libraryPattern_;
  evhttp_free(eventHTTP_);
  [super dealloc];
}
@end

