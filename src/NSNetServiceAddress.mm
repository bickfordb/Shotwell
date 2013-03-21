#import "NSNetServiceAddress.h"
#include <arpa/inet.h>

@implementation NSNetService (Address)
- (NSString *)ipv4Address {
  for (NSData *boxedAddr in self.addresses) {
    struct sockaddr *addr = (struct sockaddr *)boxedAddr.bytes;
    if (addr->sa_family == AF_INET) {
      struct sockaddr_in *ipv4addr = (struct sockaddr_in *)addr;
      char buf[255];
      inet_ntop(AF_INET, &ipv4addr->sin_addr, buf, 255);
      return [NSString stringWithUTF8String:buf];
    }
  }
  return nil;
}
@end

