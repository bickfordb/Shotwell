#import <Cocoa/Cocoa.h>
#include <event2/event.h>
#include <pthread.h>

@class Loop;
@interface Event : NSObject { 
  struct event *event_;
  Loop *loop_;
  id delegate_;
}

@property (assign, nonatomic) id delegate;
@property (readonly) struct event *event;
@property (atomic, retain) Loop *loop;
+ (id)timeoutEventWithLoop:(Loop *)loop interval:(uint64_t)interval;
@end

@interface Loop : NSObject {
  bool running_;
  bool started_;
  pthread_t threadID_;
  struct event_base *eventBase_;
}
- (void)start;
- (void)stop;
@property (readonly, nonatomic) struct event_base *eventBase;  
@end

