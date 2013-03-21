#include <iostream>

#include "gtest/gtest.h"

#import "UUID.h"

TEST(UUIDTestCase, UUIDTest) {
  NSData *d = [NSData randomUUIDLike];
  EXPECT_TRUE(d != nil);
}

