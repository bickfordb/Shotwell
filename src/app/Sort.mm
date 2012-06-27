#import "app/Log.h"
#import "app/Sort.h"
#import "app/NSStringNaturalComparison.h"

NSComparator NaturalComparison = ^(id left, id right) {
  NSString *l = left;
  NSString *r = right;
  NSComparisonResult ret = 0;
  // note: treat empty strings and nil values as the largest
  if (!left && !right)
    ret = 0;
  else if (!right)
    ret = -1;
  else if (!left)
    ret = 1;
  else if (![l length] && [r length])
    ret = 1;
  else if ([l length] && ![r length])
    ret = -1;
  else
    ret = [l naturalCompareCaseInsensitive:r];
  return ret;
};

NSComparator DefaultComparison = ^(id left, id right) {
  return [left compare:right];
};

NSComparator URLComparison = ^(id left, id right) {
  return [((NSURL *)left).absoluteString compare:((NSURL *)right).absoluteString];
};

