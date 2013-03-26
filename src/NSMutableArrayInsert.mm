#import "NSMutableArrayInsert.h"

@implementation NSMutableArray (Insert)

- (void)insert:(id)needle comparator:(NSComparator)cmp firstIndex:(NSUInteger)firstIndex lastIndex:(NSUInteger)lastIndex {
  NSUInteger midIndex = firstIndex + ((lastIndex - firstIndex) / 2);
  id target = self[midIndex];
  NSComparisonResult compare = cmp(needle, target);
  if (compare == NSOrderedAscending) {
    if (firstIndex == lastIndex) {
      [self insertObject:needle atIndex:lastIndex];
    } else {
      [self insert:needle comparator:cmp firstIndex:firstIndex lastIndex:midIndex];
    }
  } else if (compare == NSOrderedSame) {
    [self insertObject:needle atIndex:firstIndex];
  } else {
    if (firstIndex == lastIndex) {
      [self insertObject:needle atIndex:firstIndex + 1];
    } else {
      [self insert:needle comparator:cmp firstIndex:midIndex + 1 lastIndex:lastIndex];
    }
  }
}

- (void)insert:(id)obj withComparator:(NSComparator)cmp {
  if (self.count == 0) {
    [self addObject:obj];
  } else {
    NSUInteger lastIndex = self.count - 1;
    [self insert:obj comparator:cmp firstIndex:0 lastIndex:lastIndex];
  }
}

@end

