#import "app/MicroSecondsToHMS.h"
#import "app/Util.h"

@implementation MicroSecondsToHMS
+ (BOOL)allowsReverseTransformation {
  return NO;
}
- (id)transformedValue:(id)value {
  NSNumber *v = (NSNumber *)value;
  uint64_t i = [v unsignedLongLongValue];
  time_t secs = i / kUSPerS;
  struct tm t;
  localtime_r(&secs, &t);
  char buf[128];
  const char *fmt = secs > 3600 ? "%H:%M:%S" : "%M:%S";
  size_t len = strftime(buf, 125, fmt, &t);
  return @(buf);
}
@end
