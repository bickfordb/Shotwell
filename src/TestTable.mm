
#include <iostream>

#include "gtest/gtest.h"

#import "Table.h"
#import "UUID.h"

TEST(TableTestCase, TableTest) {
  Table *t = [[[Table alloc] initWithPath:@"test.db"] autorelease];
  [t clear];
  int n = 10;
  for (int i = 0; i < n; i++) {
    id itemID = [NSData randomUUIDLike];
    NSDictionary *item = @{
      @"artist": @"Euryhtmics",
        @"title": @"foo",
        @"id": itemID};
    t[itemID] = item;
  }

  int *p = &n;
  [t each:^(id key, id val) {
    *p = *p - 1;
    EXPECT_TRUE(key != nil);
    EXPECT_TRUE(val != nil);
  }];
  EXPECT_EQ(n, 0);
}

