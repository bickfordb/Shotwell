#import "app/HTTP.h"
#import "app/Log.h"
#include <event2/buffer.h>
#include <event2/http.h>
#include <event2/keyvalq_struct.h>

typedef void (^OnResponseBlock)(struct evhttp_request *req); 

static void OnRequestComplete(struct evhttp_request *req, void *context) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSArray *reqContext = (NSArray *)context;
  Loop *loop = (Loop *)([((NSValue *)[reqContext objectAtIndex:0]) pointerValue]);
  OnResponseBlock block = (OnResponseBlock)[reqContext objectAtIndex:1];
  block(req);
  [block release];
  [loop.pendingEvents removeObject:reqContext];
  [pool release];
}

NSMutableDictionary *FromEvKeyValQ(struct evkeyvalq *kv) { 
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

@implementation Loop (HTTP)

- (bool)fetchURL:(NSURL *)url with:(void (^)(HTTPResponse *response))onResponse {
  HTTPRequest *request = [[[HTTPRequest alloc] init] autorelease];
  request.method = @"GET";
  [request.headers setObject:url.host forKey:@"Host"];
  // Everyone loves iTunes!
  [request.headers setObject:@"iTunes/9.0.3 (Macintosh; U; Intel Mac OS X 10_6_2; en-ca)" forKey:@"User-Agent"];
  request.uri = (!url.query || !url.query.length) ? 
    url.path 
    : [NSString stringWithFormat:@"%@?%@", url.path, url.query, nil];
  return [self fetchRequest:request
    address:url.host
    port:url.port ? url.port.unsignedIntValue : 80
    with:onResponse];
}

- (bool)fetchRequest:(HTTPRequest *)request 
    address:(NSString *)address
    port:(uint16_t)port
    with:(void (^)(HTTPResponse *response))onResponse {
  onResponse = [onResponse copy];
  struct evhttp_connection *conn = evhttp_connection_base_new(base_, NULL, address.UTF8String, port);
  void (^onReq)(struct evhttp_request *req) = ^(evhttp_request *req) {
    HTTPResponse *resp = [[HTTPResponse alloc] init];
    if (req) {
      resp.status = evhttp_request_get_response_code(req);
      resp.headers = FromEvKeyValQ(evhttp_request_get_input_headers(req));
      const char *buf = (const char *)evbuffer_pullup(evhttp_request_get_input_buffer(req), -1);
      ssize_t buf_len =  evbuffer_get_length(evhttp_request_get_input_buffer(req));
      resp.body = [NSData dataWithBytes:buf length:evbuffer_get_length(evhttp_request_get_input_buffer(req))];
    } else { 
      resp.status = 0;
    }
    onResponse(resp);
    [resp release];
    evhttp_connection_free(conn);
  };
  onReq = [onReq copy];
  NSArray *onReqContext = [NSArray arrayWithObjects:[NSValue valueWithPointer:(void *)self], onReq, nil];
  struct evhttp_request *req = evhttp_request_new(OnRequestComplete, onReqContext);
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
    ERROR(@"failed to create request");
    evhttp_connection_free(conn);
    evhttp_request_free(req);
    return false;
  } else { 
    [self.pendingEvents addObject:onReqContext];
    return true;
  }
}
@end

