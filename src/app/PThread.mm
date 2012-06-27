#import "app/Pthread.h"
#import "app/Signals.h"
#import "app/Types.h"

@interface PThreadClosed : NSObject {
  On0 code_;
}

@property (copy) On0 code;
- (void)fire;
@end

@implementation PThreadClosed
@synthesize code = code_;

- (void)dealloc {
  [code_ release];
  [super dealloc];
}

- (void)fire {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  if (code_)
    code_();
  [pool release];
  [self release];
}
@end

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
    // NB intentionally not autoreleased
    PThreadClosed *c = [[PThreadClosed alloc] init];
    c.code = block;
    [c performSelectorOnMainThread:@selector(fire) withObject:nil waitUntilDone:NO];
  }
}
