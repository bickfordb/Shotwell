#import "md0/Pthread.h"

static void *RunBlockInThreadCallback(void *context) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  ClosedBlock block = (ClosedBlock)context;
  block();
  [block release];
  [pool release];
  return NULL;
}

pthread_t ForkWith(ClosedBlock block) {
  block = [block copy];
  pthread_t thread_id;
  pthread_create(&thread_id, NULL, RunBlockInThreadCallback, (void *)block);
  return thread_id;
};

