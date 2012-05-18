#include <sys/time.h>
#import "app/Util.h"

const int64_t kUSPerS = 1000000;

int64_t Now() {
  struct timeval t;
  gettimeofday(&t, NULL);
  int64_t ret = t.tv_usec;
  ret += t.tv_sec * kUSPerS;
  return ret;
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

NTPTime TimeValToNTP(struct timeval t) {
  NTPTime ret;
  ret.sec = t.tv_sec + 0x83aa7e80;
#define FRAC 0
  ret.frac = (uint32_t)((double)t.tv_usec * 1e-6 * FRAC);
  return ret;
}

