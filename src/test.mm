
#import <Cocoa/Cocoa.h>
#include "gtest/gtest.h"

GTEST_API_ int main(int argc, char **argv) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  testing::InitGoogleTest(&argc, argv);
  int ret = RUN_ALL_TESTS();
  [pool release];
  return ret;
}
