#include <unistd.h>

#import "md0/Loop.h"
#import "md0/NSObjectPthread.h"

static const int kDispatchInterval = 10000;
static const int kCheckRunningInterval = 1000;

@interface Loop (P) 
- (void)run;
@end

@implementation Loop 
- (id)init { 
  self = [super init];
  if (self) { 
    running_ = false;
    started_ = false;
    eventBase_ = event_base_new();
  }
  return self;
}
 
- (void)dealloc { 
  if (started_) 
    [self stop];
  event_base_free(eventBase_);
  [super dealloc];
}

- (void)start { 
  if (started_)
    return;
  started_ = true;
  [self runSelectorInThread:@selector(run)];
}

- (void)run { 
  NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];
  running_ = true;
  struct timeval dispatchInterval;
  dispatchInterval.tv_sec = 0;
  dispatchInterval.tv_usec = kDispatchInterval;
  while (started_) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    event_base_loopexit(eventBase_, &dispatchInterval);
    event_base_dispatch(eventBase_);
    [pool release];
  }
  running_ = false;
  [outerPool release];
}

- (void)stop {
  if (!started_)
    return;
  started_ = false;
  while (running_) {
    usleep(kCheckRunningInterval); 
  }
}

- (struct event_base *)eventBase { 
  return eventBase_;
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
  e->event_ = event_new(loop.eventBase, -1, EV_TIMEOUT | EV_PERSIST, EventCallback, e);
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

