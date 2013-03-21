#import "Event.h"
#import "Loop.h"

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

@implementation EventBuffer

- (id)init {
  self = [super init];
  if (self) {
    buffer_ = evbuffer_new();
  }
  return self;
}

+ (EventBuffer *)eventBuffer {
  return [[[EventBuffer alloc] init] autorelease];
}

- (void)dealloc {
  evbuffer_free(buffer_);
  [super dealloc];
}

- (struct evbuffer *)buffer {
  return buffer_;
}

@end

bool Pull8(struct evbuffer *buf, uint8_t *dst) {
  return evbuffer_remove(buf, dst, 1) == 1;
}

bool Pull16(struct evbuffer *buf, uint16_t *dst) {
  uint16_t x = 0;
  int amt = evbuffer_remove(buf, &x, 2);
  if (amt == 2)
    *dst = ntohs(x);
  return amt == 2;
}

bool Pull32(struct evbuffer *buf, uint32_t *dst) {
  uint32_t x = 0;
  int amt = evbuffer_remove(buf, &x, 4);
  if (amt == 4)
    *dst = ntohl(x);
  return amt == 4;
}

