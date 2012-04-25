#import "md0/Pthread.h"
#import "md0/Signals.h"

static void *RunBlockInThreadCallback(void *context) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  IgnoreSigPIPE();
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

