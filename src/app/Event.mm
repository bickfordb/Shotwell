#import "md0/Event.h"
#import "md0/Loop.h"

static void EventCallback(int fd, short flags, void *ctx) {
  Event *e = (Event *)ctx;
  if (e) { 
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [e retain];
    NSMutableSet *pendingEvents = e.loop.pendingEvents;
    @synchronized(pendingEvents) {
      [pendingEvents removeObject:e];  
    }
    if (e.fire) {
      e.fire(e, flags);
    }
    [e release];
    [pool release];
  }
} 

@implementation Event 
@synthesize loop = loop_;
@synthesize event = event_;
@synthesize fire = fire_;

- (id)initWithLoop:(Loop *)loop fd:(int)fd flags:(short)flags {
  // no persistent events!
  flags = flags & ~EV_PERSIST;
  self = [super init];
  if (self) {
    self.loop = loop;
    event_ = event_new(loop.base, fd, flags, EventCallback, self);
  }
  return self;
}

- (void)add:(int64_t)timeout {
  NSMutableSet *pendingEvents = self.loop.pendingEvents;
  @synchronized(pendingEvents) { 
    [pendingEvents addObject:self];
  }
  struct timeval t;
  if (timeout > 0) {
    t.tv_sec = timeout / 1000000;
    t.tv_usec = timeout - (t.tv_sec * 1000000);
    event_add(event_, &t);
  } else { 
    event_add(event_, NULL);
  }
}

- (void)dealloc {
  self.fire = nil;
  self.loop = nil;
  event_free(event_);
  [super dealloc];
}
@end

