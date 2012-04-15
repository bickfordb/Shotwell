#import "md0/Random.h"
#import <stdio.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <openssl/rand.h>

@implementation NSData (Random)
+ (NSData *)randomDataWithLength:(size_t)length  {
  uint8_t s[length];
  RAND_bytes(s, length);
  return [NSData dataWithBytes:s length:length];
}
@end



