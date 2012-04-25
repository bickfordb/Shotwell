#import "app/NSMutableArrayInsert.h"

static NSUInteger Insert(NSMutableArray *a, id obj, NSComparator comparator, NSUInteger start, NSUInteger end) {
  if (start == end)
    return start;
  NSUInteger mid = start + ((end - start) / 2);
  id midObj = [a objectAtIndex:mid];
  NSComparisonResult cmp = comparator(obj, midObj);
  if (cmp == NSOrderedAscending) {
    return Insert(a, obj, comparator, start, mid);
  } else if (cmp == NSOrderedSame) {
    return mid;
  } else { 
    return Insert(a, obj, comparator, mid + 1, end);  
  }
}

@implementation NSMutableArray (Insert)

- (void)insert:(id)obj sortedWithComparator:(NSComparator)c {
  if (self.count == 0 || !c) {
    [self addObject:obj];
    return;
  }
  NSUInteger idx = Insert(self, obj, c, 0, self.count - 1);
  [self insertObject:obj atIndex:idx];
}

@end

