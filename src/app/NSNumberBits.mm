#import "app/NSNumberBits.h"

@implementation NSNumber (Bits)
- (NSNumber *)and:(uint32_t)bits {
  return [NSNumber numberWithUnsignedInt:self.unsignedIntValue & bits];
}
- (NSNumber *)or:(uint32_t)bits {
  return [NSNumber numberWithUnsignedInt:self.unsignedIntValue | bits];
}
@end
