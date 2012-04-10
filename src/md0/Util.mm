#include <sys/time.h>
#import "md0/Util.h"

const int64_t kSPerUS = 1000000;

int64_t Now() {
  struct timeval t;
  gettimeofday(&t, NULL);
  int64_t ret = t.tv_usec;
  ret += t.tv_sec * kSPerUS;
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

