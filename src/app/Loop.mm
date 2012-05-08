#include <event2/buffer.h>
#include <event2/thread.h>
#include <unistd.h>

#import "app/Loop.h"
#import "app/Log.h"
#import "app/Event.h"
#import "app/Signals.h"
#import "app/PThread.h"

static NSMutableDictionary *FromEvKeyValQ(struct evkeyvalq *kv);
static void OnRequestComplete(struct evhttp_request *req, void *context);

static const int kDispatchInterval = 10000; // .01 seconds
static const int kCheckRunningInterval = 1000; // .001 seconds

@interface Loop (P) 
- (void)run;
@end

@implementation Loop 
@synthesize pendingEvents = pendingEvents_;

+ (void)initialize {
  evthread_use_pthreads();
}

- (id)init { 
  self = [super init];
  if (self) { 
    base_ = event_base_new();
    running_ = false;
    started_ = true;
    pendingEvents_ = [[NSMutableSet set] retain];
    __block Loop *weakSelf = self;
    ForkWith(^{ [weakSelf run]; });
  }
  return self;
}

- (void)dealloc { 
  started_ = false;
  event_base_loopbreak(base_);
  while (running_) { ; }
  [pendingEvents_ release];
  event_base_free(base_);
  [super dealloc];
}

- (void)run { 
  running_ = true;
  IgnoreSigPIPE();
  struct timeval dispatchInterval;
  dispatchInterval.tv_sec = 0;
  dispatchInterval.tv_usec = kDispatchInterval;
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  while (started_) {
    usleep(10000);
    event_base_loopexit(base_, &dispatchInterval);
    event_base_dispatch(base_);
  }
  [pool release];
  running_ = false;
}

- (struct event_base *)base { 
  return base_;
}
- (void)every:(int64_t)timeout with:(void (^)())block {
  block = [block copy];
  [self onTimeout:timeout with:^(Event *e, short flags) {
    block();
    [e add:timeout];
  }];
}

- (void)onTimeout:(int64_t)timeout with:(void (^)(Event *e, short flags))block {
  [self monitorFd:-1 flags:0 timeout:timeout with:block];
}

- (void)monitorFd:(int)fd flags:(int)flags timeout:(int64_t)timeout with:(OnFireEvent)block {
  if (timeout > 0)
    flags |= EV_TIMEOUT;
  Event *e = [[[Event alloc] initWithLoop:self fd:fd flags:flags] autorelease];
  e.fire = block;
  [e add:timeout];
}

- (void)writeBuffer:(struct evbuffer *)buffer fd:(int)fd with:(void (^)(int succ))block {
  block = [block copy];
  [self monitorFd:fd flags:EV_WRITE timeout:-1 with:^(Event *event, short flags) {
    int write_st = evbuffer_write(buffer, fd);
    if ((write_st < 0) && (errno == EAGAIN || errno == EINTR)) 
      write_st = 0;
    if (evbuffer_get_length(buffer) > 0 && write_st >= 0) {
      [event add:-1];
    } else { 
      evbuffer_free(buffer);
      block(write_st >= 0 ? 0 : write_st);
    }
  }];
}

- (void)readLine:(int)fd with:(void (^)(NSString *line))block {
  struct evbuffer *buf = evbuffer_new();
  assert(buf);
  [self readLine:fd buffer:buf with:block];
}

- (void)readLine:(int)fd buffer:(struct evbuffer *)buffer with:(void (^)(NSString *line))block { 
  block = [block copy];
  [self monitorFd:fd flags:EV_READ timeout:-1 with:^(Event *event, short flags) {
    for (;;) { 
      char c = 0;
      int read_len = read(fd, &c, 1);
      if (read_len < 0 && errno != EAGAIN && errno != EINTR)
        break;
      if (read_len <= 0) {
        [event add:-1];   
        break;
      }
      evbuffer_add(buffer, &c, 1);
      if (c != '\n') 
        continue;
      int blen = evbuffer_get_length(buffer);
      NSString *s = [[NSString alloc] 
        initWithBytes:evbuffer_pullup(buffer, blen)
        length:blen
        encoding:NSUTF8StringEncoding];
      block(s);
      evbuffer_free(buffer);
      [s release];
      break;
    }
  }];
}
  
- (void)readData:(int)fd length:(size_t)length with:(void (^)(NSData *bytes))block {
  struct evbuffer *buffer = evbuffer_new();
  [self readData:fd buffer:buffer length:length with:block];
}

- (void)readData:(int)fd buffer:(struct evbuffer *)buffer length:(size_t)length with:(void (^)(NSData *bytes))block {
  block = [block copy];
  [self 
    monitorFd:fd
    flags:EV_READ
    timeout:-1
    with:^(Event *event, short flag) {
      NSString *s = nil;
      for (;;) {
        if (evbuffer_get_length(buffer) == length)
          break;
        if (evbuffer_read(buffer, fd, 1) <= 0)
          break;
      }
      if (evbuffer_get_length(buffer) != length) {
        [event add:-1];
      } else { 
        NSData *ret = [NSData dataWithBytes:evbuffer_pullup(buffer, length) length:length];
        evbuffer_free(buffer);
        block(ret);
      }
    }];
}

+ (Loop *)loop {
  return [[[Loop alloc] init] autorelease];
}

@end



