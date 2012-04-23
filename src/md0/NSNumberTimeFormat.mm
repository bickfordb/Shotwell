#import "NSNumberTimeFormat.h"

static const int kSecondsPerHour = 3600;
static const int kSecondsPerMinute = 60;

@implementation NSNumber (TimeFormat) 

- (NSString *)formatSeconds { 
  int64_t usecs = [self longLongValue];
  int64_t seconds = usecs / 1000000;
  int64_t hours = seconds / kSecondsPerHour;
  if (hours < 0) {
    seconds *= -1;
    seconds -= kSecondsPerHour * hours * -1;
  } else { 
    seconds -= kSecondsPerHour * hours;
  } 
  int64_t minutes = seconds / kSecondsPerMinute;
  seconds -= minutes * kSecondsPerMinute;
  if (hours != 0)
    return [NSString stringWithFormat:@"%02d:%02d:%02d", (int)hours, (int)minutes, (int)seconds];
  else
    return [NSString stringWithFormat:@"%02d:%02d", (int)minutes, (int)seconds];
}

@end
