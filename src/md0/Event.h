#import <Cocoa/Cocoa.h>
#include <event2/event.h>

@class Event;
@class Loop;
typedef void (^OnFireEvent)(Event *event, short flags);

@interface Event : NSObject { 
  struct event *event_;
  Loop *loop_;
  OnFireEvent fire_;
}

- (id)initWithLoop:(Loop *)loop fd:(int)fd flags:(short)flags;
@property (retain) OnFireEvent fire;
@property (readonly) struct event *event;
@property (assign) Loop *loop; // Loops hold onto events
- (void)add:(int64_t)timeout;
@end

