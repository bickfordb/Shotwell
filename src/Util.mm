#import "Util.h"

const uint64_t kUSPerS = 1000000;
const uint64_t kNSPerS = 1000000000;

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
