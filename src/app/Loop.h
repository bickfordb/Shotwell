#import <Cocoa/Cocoa.h>
#include <event2/event.h>
#include <pthread.h>

#import "app/Event.h"

typedef void (^LoopOnLine)(NSString *line);
typedef void (^LoopOnData)(NSData *data);


@interface Loop : NSObject {
  bool running_;
  bool started_;
  struct event_base *base_;
  NSMutableSet *pendingEvents_;
  pthread_t threadID_;
}

@property (readonly, nonatomic) struct event_base *base;
@property (retain) NSMutableSet *pendingEvents;

- (void)monitorFd:(int)fd flags:(int)flags timeout:(int64_t)timeout with:(OnFireEvent)block;
- (void)every:(int64_t)timeout with:(void (^)())block;
- (void)onTimeout:(int64_t)timeout with:(OnFireEvent)block;
- (void)writeBuffer:(struct evbuffer *)buffer fd:(int)fd with:(void (^)(int succ))block;
- (void)readLine:(int)fd with:(void (^)(NSString *line))aBlock;
- (void)readData:(int)fd length:(size_t)length with:(void (^)(NSData *bytes))aBlock;
- (void)readLine:(int)fd buffer:(struct evbuffer *)buffer with:(LoopOnLine)block;
- (void)readData:(int)fd buffer:(struct evbuffer *)buffer length:(size_t)length with:(void (^)(NSData *bytes))block;
+ (Loop *)loop;
@end
