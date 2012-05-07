#import "app/NSStringDigest.h"
#include <CommonCrypto/CommonDigest.h>
#include <assert.h>

static const char *hexchars = "0123456789abcdef";

static inline char hexchar(int i) {
  assert(i <= 16);
  return hexchars[i % 16];
}

@implementation NSString (Digest)

- (NSString *)sha1 { 
  const char *bytes = self.UTF8String;
  unsigned char m[21];
  CC_SHA1(bytes, strlen(bytes), m);
  char s[41];
  for (int i = 0; i < 20; i++) {
    int b = m[i];
    s[i * 2] = hexchars[(0xf0 & b) >> 4];
    s[i * 2 + 1] = hexchars[0xf & b];
  }
  s[40] = '\0';
  return [NSString stringWithUTF8String:s];
}
@end
