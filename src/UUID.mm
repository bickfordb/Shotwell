#import "UUID.h"
#include <stdio.h>

static unsigned seed = 0;

@implementation NSData (UUID)

+ (NSData *)randomUUIDLike {
  unsigned char buf[16];
  uint32_t r;
  for (int i = 0; i < 16; i += sizeof(r))  {
    r = arc4random();
    memcpy(buf + i, &r, sizeof(r));
  }
  return [NSData dataWithBytes:buf length:16];
}

- (NSString *)UUIDDescription {
  const unsigned char *x = (const unsigned char *)self.bytes;
  if (self.length == 16) {
    return [NSString stringWithFormat:@"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x%02x%02x",
           x[0], x[1], x[2], x[3],
           x[4], x[5], x[6], x[7],
           x[8], x[9], x[10], x[11],
           x[12], x[13], x[14], x[15]];
  } else {
    return @"";
  }
}

- (NSString *)hex {
  NSString *ret;
  int n = self.length;
  const unsigned char *src = (const unsigned char *)self.bytes;
  char *s = (char *)malloc((n * 2) + 1);
  for (int i = 0; i < n; i++) {
    sprintf(s + (i * 2), "%02x", src[i]);
  }
  return [[[NSString alloc] initWithBytesNoCopy:s length:(n * 2) + 1 encoding:NSUTF8StringEncoding freeWhenDone:YES] autorelease];
}


@end

