#import "app/Util.h"

const uint64_t kUSPerS = 1000000;
const uint64_t kNSPerS = 1000000000;

/* Get the current time in ultra seconds */

uint64_t TimeSpecToUSec(struct timespec t) {
  uint64_t ret = t.tv_nsec * (kNSPerS / kUSPerS);
  ret += kUSPerS * t.tv_sec;
  return ret;
}

uint64_t Now() {
  struct timeval t;
  gettimeofday(&t, NULL);
  uint64_t ret = t.tv_usec;
  ret += t.tv_sec * kUSPerS;
  return ret;
}

uint64_t ModifiedAt(NSString *path) {
  struct stat fsStatus;
  if (stat(path.UTF8String, &fsStatus) >= 0) {
    return TimeSpecToUSec(fsStatus.st_mtimespec);
  } else {
    return 0;
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

