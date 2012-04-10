#include <event2/buffer.h>
#include <event2/thread.h>
#include <event2/keyvalq_struct.h>
#include <unistd.h>

#import "md0/Loop.h"
#import "md0/Log.h"
#import "md0/NSObjectPthread.h"

static NSMutableDictionary *FromEvKeyValQ(struct evkeyvalq *kv);
static void OnRequestComplete(struct evhttp_request *req, void *context);

static const int kDispatchInterval = 10000;
static const int kCheckRunningInterval = 1000;

@interface Loop (P) 
- (void)run;
@end

@implementation Loop 
+ (void)initialize {
  evthread_use_pthreads();
}

- (id)init { 
  self = [super init];
  if (self) { 
    base_ = event_base_new();
    running_ = false;
    started_ = true;
    [self runSelectorInThread:@selector(run)];
  }
  return self;
}

 
- (void)dealloc { 
  started_ = false;
  while (running_) {
    usleep(kCheckRunningInterval); 
  }
  event_base_free(base_);
  [super dealloc];
}


- (void)run { 
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  running_ = true;
  struct timeval dispatchInterval;
  dispatchInterval.tv_sec = 0;
  dispatchInterval.tv_usec = kDispatchInterval;
  while (started_) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    event_base_loopexit(base_, &dispatchInterval);
    event_base_dispatch(base_);
    [pool release];
  }
  running_ = false;
  [outerPool release];
}

- (struct event_base *)base { 
  return base_;
}

- (bool)fetchURL:(NSURL *)url withBlock:(void (^)(HTTPResponse *response))onResponse {
  HTTPRequest *request = [[[HTTPRequest alloc] init] autorelease];
  request.method = @"GET";
  [request.headers setObject:url.host forKey:@"Host"];
  [request.headers setObject:@"iTunes/9.0.3 (Macintosh; U; Intel Mac OS X 10_6_2; en-ca)" forKey:@"User-Agent"];
  request.uri = (!url.query || !url.query.length) ? 
    url.path 
    : [NSString stringWithFormat:@"%@?%@", url.path, url.query, nil];
  return [self fetchRequest:request
    address:url.host
    port:url.port ? url.port.unsignedIntValue : 80
    withBlock:onResponse];
}

- (bool)fetchRequest:(HTTPRequest *)request 
  address:(NSString *)address
  port:(uint16_t)port
  withBlock:(void (^)(HTTPResponse *response))onResponse {
  onResponse = Block_copy(onResponse);
  struct evhttp_connection *conn = evhttp_connection_base_new(base_, NULL, address.UTF8String, port);
  void (^onReq)(struct evhttp_request *req) = Block_copy(^(evhttp_request *req) {
      HTTPResponse *resp = [[HTTPResponse alloc] init];
      if (req) {
        resp.status = evhttp_request_get_response_code(req);
        resp.headers = FromEvKeyValQ(evhttp_request_get_input_headers(req));
        const char *buf = (const char *)evbuffer_pullup(evhttp_request_get_input_buffer(req), -1);
        ssize_t buf_len =  evbuffer_get_length(evhttp_request_get_input_buffer(req));
        resp.body = [NSData 
          dataWithBytes:buf 
          length:evbuffer_get_length(evhttp_request_get_input_buffer(req))];
      } else { 
        resp.status = 0;
      }
      onResponse(resp);
      [resp release];
      evhttp_connection_free(conn);
      // hack: Making a reference to self keeps the loop alive while the request is still going.
      // this actually does a double free/retain
      [self release];
    });
  struct evhttp_request *req = evhttp_request_new(OnRequestComplete, (void *)onReq);
  [request.headers setValue:@"close" forKey:@"Connection"];
  [request.headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    NSString *key0 = (NSString *)key;
    NSString *value0 = (NSString *)obj;
    evhttp_add_header(
        evhttp_request_get_output_headers(req),
        ((NSString *)key).UTF8String,
        ((NSString *)obj).UTF8String);
  }];

  evhttp_cmd_type cmdType = EVHTTP_REQ_GET; 
  int st = evhttp_make_request(conn, req, cmdType, request.uri.UTF8String);
  if (st != 0) {
    ERROR("failed to create request");
    evhttp_connection_free(conn);
    evhttp_request_free(req);
    [self release];
    return false;
  } else { 
    [onReq retain];
    [self retain];
    return true;
  }
}


@end

static void EventCallback(int fd, short evt, void *ctx) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  Event *e = (Event *)ctx;
  id delegate = e.delegate;
  [delegate retain];
  if ((evt & EV_TIMEOUT) && [delegate respondsToSelector:@selector(eventTimeout:)])
    [delegate performSelector:@selector(eventTimeout:) withObject:e];
  if ((evt & EV_WRITE) && [delegate respondsToSelector:@selector(eventWriteReady:)])
    [delegate performSelector:@selector(eventWriteReady:) withObject:e];
  if ((evt & EV_READ) && [delegate respondsToSelector:@selector(eventReadReady:)])
    [delegate performSelector:@selector(eventReadReady:) withObject:e];
  [delegate release];
  [pool release];
}

@implementation Event 
@synthesize loop = loop_;
@synthesize delegate = delegate_;
@synthesize event = event_;

+ (id)timeoutEventWithLoop:(Loop *)loop interval:(uint64_t)interval {
  Event *e = [[Event alloc] init];
  e->loop_ = [loop retain];
  e->event_ = event_new(loop.base, -1, EV_TIMEOUT | EV_PERSIST, EventCallback, e);
  struct timeval t;
  t.tv_sec = interval / 1000000.0;
  t.tv_usec = interval - (t.tv_sec * 1000000);
  event_add(e->event_, &t);
  return [e autorelease]; 
}


- (void)dealloc {
  event_del(event_);
  event_free(event_);
  [loop_ release];
  [super dealloc];
}
@end

typedef void (^OnResponseBlock)(struct evhttp_request *req); 

static void OnRequestComplete(struct evhttp_request *req, void *context) {
  OnResponseBlock block = (OnResponseBlock)context;
  block(req);
  [block release];
}

static NSMutableDictionary *FromEvKeyValQ(struct evkeyvalq *kv) { 
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  if (kv) {
    struct evkeyval *e = kv->tqh_first;
    while (e) {
      NSString *key = [NSString stringWithUTF8String:e->key];
      NSString *value = [NSString stringWithUTF8String:e->value];
      [d setValue:value forKey:key];
      e = e->next.tqe_next;
    }
  }
  return d;
}


@implementation HTTPRequest 
@synthesize method = method_;
@synthesize uri = uri_;
@synthesize body = body_;
@synthesize headers = headers_;

- (id)init { 
  self = [super init];
  if (self) { 
    method_ = [@"GET" retain];
    uri_ = [@"/" retain];
    body_ = [[NSData data] retain];
    headers_ = [[NSMutableDictionary dictionary] retain];
  }
  return self;
}

- (void)dealloc { 
  [method_ release];
  [body_ release];
  [headers_ release];
  [super dealloc];
}
@end   

@implementation HTTPResponse
@synthesize status = status_;
@synthesize headers = headers_;
@synthesize body = body_;

- (id)init { 
  self = [super init];
  if (self) {
    status_ = 200;
    body_ = [[NSData data] retain];
    headers_ = [[NSMutableDictionary dictionary] retain];
  }
  return self;  
}

- (void)dealloc { 
  [body_ release];
  [headers_ release];
  [super dealloc];
}
@end
