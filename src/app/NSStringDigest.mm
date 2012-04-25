#import "md0/NSStringDigest.h"
#include <CommonCrypto/CommonDigest.h>

@implementation NSString (Digest)

- (NSString *)sha1 { 
  const char *bytes = self.UTF8String;
  unsigned char m[20];
  CC_SHA1(bytes, strlen(bytes), m);
  char s[41];
  //sprintf(s, "%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x", 
  //  (int)m[0], (int)m[1], (int)m[2], (int)m[3], (int)m[4], (int)m[5], (int)m[6],
  //  (int)m[7], (int)m[8], (int)m[9], (int)m[10], (int)m[11], (int)m[12], (int)m[13],
  //  (int)m[14], (int)m[15], (int)m[16], (int)m[17], (int)m[18], (int)m[19])
  //s[40] = '\0';
  for (int i = 0; i < 20; i++) {
    sprintf(s + (i * 2), "%x", (int)m[i]);
  }
  return [NSString stringWithUTF8String:s];
}
@end
