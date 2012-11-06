#import "app/MicroSecondsToDate.h"
#import "app/Util.h"

@implementation MicroSecondsToDate
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
  size_t len = strftime(buf, 125, "%m/%d/%y %H:%M%p", &t);
  return [NSString stringWithUTF8String:buf];
}
@end
