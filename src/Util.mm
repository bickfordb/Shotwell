#import "Util.h"

const uint64_t kUSPerS = 1000000ull;
const uint64_t kNSPerS = 1000000000ull;

/* Get the current time in ultra seconds */

NSDate *TimeSpecToDate(struct timespec t) {
  NSTimeInterval i = t.tv_sec;
  i += t.tv_nsec * (kNSPerS / kUSPerS);
  return [NSDate dateWithTimeIntervalSince1970:i];
}

uint64_t Now() {
  struct timeval t;
  gettimeofday(&t, NULL);
  uint64_t ret = t.tv_usec;
  ret += t.tv_sec * kUSPerS;
  return ret;
}

NSDate *ModifiedAt(NSString *path) {
  struct stat fsStatus;
  if (stat(path.UTF8String, &fsStatus) >= 0) {
    return TimeSpecToDate(fsStatus.st_mtimespec);
  } else {
    return nil;
  }
}

NSArray *GetSubDirectories(NSArray *dirs) {
  NSMutableArray *ret = [NSMutableArray array];
  for (NSString *aDir in dirs) {
    NSArray *subpaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:aDir error:nil];
    for (NSString *subpath in subpaths) {
      subpath = [aDir stringByAppendingPathComponent:subpath];
      BOOL isDir = NO;
      [[NSFileManager defaultManager] fileExistsAtPath:subpath isDirectory:&isDir];
      if (isDir) {
        [ret addObject:subpath];
      }
    }
  }
  return ret;
}

NSString *StringToNSString(const std::string *s) {
  if (!s)
    return nil;
  NSString *result = [[[NSString alloc] initWithBytes:s->c_str() length:s->length() encoding:NSUTF8StringEncoding] autorelease];
  return result;
}

void MakeDirectories(NSString *path) {
  if (!path || [path isEqualToString:@""] || [path isEqualToString:@"/"])
    return;
  MakeDirectories(path.stringByDeletingLastPathComponent);
  mkdir(path.UTF8String, 0755);
}

void RunOnMain(void (^block)(void)) {
  dispatch_async(dispatch_get_main_queue(), [block copy]);
}

bool Exists(NSString *path) {
  struct stat fsStatus;
  if (stat(path.UTF8String, &fsStatus) >= 0) {
    return true;
  } else {
    return false;
  }
}

NSString *LocalLibraryPath() {
  return [AppSupportPath() stringByAppendingPathComponent:@"Library"];
}

NSString *AppSupportPath() {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory,
      NSUserDomainMask,
      YES);
  NSString *path = [paths objectAtIndex:0];
  path = [path stringByAppendingPathComponent:@"Shotwell"];
  mkdir(path.UTF8String, 0755);
  return path;
}


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
  dispatch_async(dispatch_get_main_queue(), [block copy]);
}

void IgnoreSigPIPE(void) {
        // ignore SIGPIPE (or else it will bring our program down if the client
        // closes its socket).
        // NB: if running under gdb, you might need to issue this gdb command:
        //          handle SIGPIPE nostop noprint pass
        //     because, by default, gdb will stop our program execution (which we
        //     might not want).
        struct sigaction sa;

        memset(&sa, 0, sizeof(sa));
        sa.sa_handler = SIG_IGN;

        if (sigemptyset(&sa.sa_mask) < 0 || sigaction(SIGPIPE, &sa, 0) < 0) {
                perror("Could not ignore the SIGPIPE signal");
                exit(EXIT_FAILURE);
        }
}

void Notify(NSString *key, id sender, NSDictionary *userInfo) {
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center
    postNotificationName:key
    object:sender
    userInfo:userInfo];
}

dispatch_source_t CreateDispatchTimer(double seconds, dispatch_queue_t queue, dispatch_block_t block) {
  uint64_t interval = seconds * kNSPerS;

  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
  if (timer) {
    dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), interval, 0);
    dispatch_source_set_event_handler(timer, block);
    dispatch_resume(timer);
  }
  return timer;
}

