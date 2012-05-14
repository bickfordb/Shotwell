#import <Cocoa/Cocoa.h>
#include <event2/event.h>
#include <event2/buffer.h>

@class Event;
@class Loop;
@class EventBuffer;
typedef void (^OnFireEvent)(Event *event, short flags);

@interface Event : NSObject { 
  struct event *event_;
  Loop *loop_;
  OnFireEvent fire_;
}

- (id)initWithLoop:(Loop *)loop fd:(int)fd flags:(short)flags;
@property (copy) OnFireEvent fire;
@property (readonly) struct event *event;
@property (assign) Loop *loop; // Loops hold onto events
- (void)add:(int64_t)timeout;
@end

@interface EventBuffer : NSObject { 
  struct evbuffer *buffer_;
}

- (struct evbuffer *)buffer;
+ (id)eventBuffer;
@end


bool Pull8(struct evbuffer *buf, uint8_t *dst);
bool Pull16(struct evbuffer *buf, uint16_t *dst);
bool Pull32(struct evbuffer *buf, uint32_t *dst);
