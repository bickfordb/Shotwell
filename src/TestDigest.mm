#import "app/NSStringDigest.h"
#import "test/gtest_mac.h"

TEST(DigestTest, SHA1) {
  EXPECT_NSEQ([@"hello there" sha1], @"6e71b3cac15d32fe2d36c270887df9479c25c640");  
}

