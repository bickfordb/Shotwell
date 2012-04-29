#import "app/Pthread.h"
#import "app/Signals.h"

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

void ForkToMainWith(ClosedBlock block) {
  NSThread *mainThread = [NSThread mainThread];
  if (mainThread == [NSThread currentThread]) {
    block();
  } else { 
    block = [block copy];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      block();
      [pool release];
    }];
  }
}
