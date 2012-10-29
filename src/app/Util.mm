#import "app/Util.h"

const int64_t kUSPerS = 1000000;
const int64_t kNSPerS = 1000000000;

/* Get the current time in ultra seconds */

int64_t TimeSpecToUSec(struct timespec t) {
  int64_t ret = t.tv_nsec;
  ret += kNSPerS * t.tv_sec;
  return ret;
}

int64_t Now() {
  struct timeval t;
  gettimeofday(&t, NULL);
  int64_t ret = t.tv_usec;
  ret += t.tv_sec * kUSPerS;
  return ret;
}

int64_t ModifiedAt(NSString *path) {
  struct stat fsStatus;
  if (stat(path.UTF8String, &fsStatus) >= 0) {
    return TimeSpecToUSec(fsStatus.st_mtimespec);
  } else {
    return -1;
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

NTPTime TimeValToNTP(struct timeval t) {
  NTPTime ret;
  ret.sec = t.tv_sec + 0x83aa7e80;
#define FRAC 0
  ret.frac = (uint32_t)((double)t.tv_usec * 1e-6 * FRAC);
  return ret;
}

NSString *StringToNSString(const std::string *s) {
  if (!s)
    return nil;
  NSString *result = [[[NSString alloc] initWithBytes:s.c_str() length:s.length() encoding:NSUTF8StringEncoding] autorelease];
  return result;
}

