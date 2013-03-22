
#import "Log.h"
#import "SkipList.h"
#import "gtest_mac.h"

#define Long(x) [NSNumber numberWithLong:x]

NSComparator CompareNumbers = ^(id left, id right) {
  NSNumber *l = (NSNumber *)left;
  NSNumber *r = (NSNumber *)right;
  return l.longValue - r.longValue;
};


TEST(SkipListTest, Add) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  SkipList *sl = [[[SkipList alloc] initWithComparator:CompareNumbers] autorelease];
  int N = 100;
  int M = 5;
  for (int j = 0; j < M; j++) {
    for (int i = 0; i < N; i++) {
      [sl set:Long(i) to:Long(i)];
    }
    for (int i = 0; i < N; i++) {
      EXPECT_EQ([sl contains:Long(i)], true);
    }
    for (int i = N + 1; i < N + 10; i++) {
      EXPECT_EQ([sl contains:Long(i)], false);
    }
    for (int i = 0; i < N; i++) {
      [sl delete:Long(i)];
    }
    for (int i = 0; i < N; i++) {
      EXPECT_EQ([sl contains:Long(i)], false);
    }
  }
  [pool release];
}


TEST(SkipListTest, Clear) {
  SkipList *sl = [[[SkipList alloc] initWithComparator:CompareNumbers] autorelease];
  for (int i = 0; i < 10; i++) {
    [sl set:Long(i) to:Long(i)];
  }
  EXPECT_EQ(sl.count, 10);
  [sl clear];
  EXPECT_EQ(sl.count, 0);
}

TEST(SkipListTest, At) {
  SkipList *sl = [[[SkipList alloc] initWithComparator:CompareNumbers] autorelease];
  [sl set:Long(4) to:Long(4)];
  [sl set:Long(1) to:Long(1)];
  [sl set:Long(3) to:Long(3)];
  [sl set:Long(0) to:Long(0)];
  [sl set:Long(2) to:Long(2)];
  EXPECT_NSEQ([sl at:0], Long(0));
  EXPECT_NSEQ([sl at:1], Long(1));
  EXPECT_NSEQ([sl at:2], Long(2));
  EXPECT_NSEQ([sl at:3], Long(3));
  EXPECT_NSEQ([sl at:4], Long(4));

  [sl delete:Long(0)];
  EXPECT_NSEQ([sl at:0], Long(1));
  [sl delete:Long(3)];
  EXPECT_NSEQ([sl at:2], Long(4));
}


