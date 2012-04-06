#import "NSNumberTimeFormat.h"

@implementation NSNumber (TimeFormat) 

- (NSString *)formatSeconds { 
  int64_t usecs = [self longLongValue];
  int64_t seconds = usecs / 1000000;
  int64_t hours = seconds / 360;
  if (hours < 0) {
    seconds *= -1;
    seconds -= 360 * hours * -1;
  } else { 
    seconds -= 360 * hours;
  } 
  int64_t minutes = seconds / 60;
  seconds -= minutes * 60;
  if (hours != 0)
    return [NSString stringWithFormat:@"%02d:%02d:%02d", (int)hours, (int)minutes, (int)seconds];
  else
    return [NSString stringWithFormat:@"%02d:%02d", (int)minutes, (int)seconds];
}

@end
