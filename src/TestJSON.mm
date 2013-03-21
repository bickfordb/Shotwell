#include <iostream>

#include "gtest/gtest.h"
#include "gtest_mac.h"

#import "JSON.h"

TEST(JSONTestCase, JSONTest) {
  NSString *s = @"{\"foo\": \"bar\", \"baz\": {\"iz\": \"tooz\"}, \"fiz\": [1, 2, 3]}";
  id result = FromJSONBytes(s.UTF8String);
  NSDictionary *expected = @{
    @"foo": @"bar",
    @"baz": @{
      @"iz": @"tooz"
    },
    @"fiz": @[@1, @2, @3]};
  EXPECT_NSEQ(result, expected);
}

TEST(JSONTestCase, StringFragmentTest) {
  EXPECT_NSEQ(@"foo", FromJSONBytes(@"\"foo\"".UTF8String));
}

TEST(JSONTestCase, NumberFragmentTest) {
  EXPECT_NSEQ(@1, FromJSONBytes(@"1".UTF8String));
}

TEST(JSONTestCase, BoolFragmentTest) {
  EXPECT_NSEQ(@NO, FromJSONBytes(@"false".UTF8String));
  EXPECT_NSEQ(@YES, FromJSONBytes(@"true".UTF8String));
}

TEST(JSONTestCase, NullFragmentTest) {
  id n = FromJSONBytes(@"null".UTF8String);
  EXPECT_TRUE(n == [NSNull null]);
}

void CheckPList(id initial) {
  NSError *error = nil;
  NSData *plist = [NSPropertyListSerialization
    dataWithPropertyList:initial format:NSPropertyListBinaryFormat_v1_0 options:NSPropertyListMutableContainersAndLeaves error:&error];
  EXPECT_TRUE(error == nil);
  EXPECT_TRUE(plist != nil);

  id result = [NSPropertyListSerialization propertyListWithData:plist options:0 format:NULL error:&error];
  EXPECT_TRUE(error == nil);
  EXPECT_TRUE(result != nil);
  EXPECT_NSEQ(initial, result);
}

TEST(PListTestCase, PListTest) {
  CheckPList(@"foo");
  CheckPList(@1);
  CheckPList(@false);
  CheckPList(@true);
  CheckPList(@{
    @"foo": @[@1, @2, @3],
    @"bar": @2
  });
}


