#import "NSObjectPthread.h"

#include <pthread.h>

typedef struct {
  id obj;
  SEL sel;
} ThreadContext;

static void *RunInThread(void *context) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  ThreadContext *c = (ThreadContext *)context;
  [c->obj performSelector:c->sel];
  [pool release];
  [c->obj release];
  free(c);
  return NULL;
}

@implementation NSObject (Pthread) 
- (void)runSelectorInThread:(SEL)selector {
  ThreadContext *c = (ThreadContext *)malloc(sizeof(ThreadContext));
  [self retain];
  c->obj = self;
  c->sel = selector;
  pthread_t thread_id;
  pthread_create(&thread_id, NULL, RunInThread, c);
}
@end
