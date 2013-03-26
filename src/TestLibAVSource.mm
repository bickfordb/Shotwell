#include <iostream>

#include "gtest/gtest.h"
#include "gtest_mac.h"

#import "LibAVSource.h"

TEST(LibAVSourceTestCase, LibAVSourceTest) {
  NSURL *url = [NSURL fileURLWithPath:@"test-data/example.mp3"];
  LibAVSource *src = [[[LibAVSource alloc] initWithURL:url] autorelease];
  size_t len = 1024;
  uint8_t buf[len];
  NSError *err = nil;
  //EXPECT_EQ(src.elapsed, 0);
  err = [src getAudio:buf length:&len];
  EXPECT_EQ(err, ((NSError *)nil));
  EXPECT_EQ(len, 1024);
  err = [src getAudio:buf length:&len];
  EXPECT_EQ(err, ((NSError *)nil));
  EXPECT_EQ(len, 1024);
}

