#include <iostream>

#include "gtest/gtest.h"
#include "gtest_mac.h"

#import "NSMutableArrayInsert.h"

NSComparator CompareObject = ^(id left, id right) {
  return (NSComparisonResult)[left compare:right];
};

TEST(ArrayTestCase, ArrayTest) {
  NSMutableArray *result = [NSMutableArray array];
  [result insert:@"d" withComparator:CompareObject];
  [result insert:@"b" withComparator:CompareObject];
  [result insert:@"a" withComparator:CompareObject];
  [result insert:@"c" withComparator:CompareObject];
  [result insert:@"e" withComparator:CompareObject];
  NSArray *expected = [NSMutableArray arrayWithArray:@[@"a", @"b", @"c", @"d", @"e"]];
  EXPECT_NSEQ(result, expected);
}

