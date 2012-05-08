#import "app/Log.h"
#import "app/SortField.h"
#import "app/NSStringNaturalComparison.h"

@implementation SortField 
@synthesize key = key_;
@synthesize direction = direction_;
@synthesize comparator = comparator_;


- (id)initWithKey:(NSString *)key direction:(Direction)direction comparator:(NSComparator)comparator {
  self = [super init];
  if (self) { 
    self.key = key;
    self.direction = direction;
    self.comparator = comparator;
  }
  return self;
}

- (void)dealloc { 
  self.key = nil;
  self.comparator = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}
@end

NSComparator GetSortComparatorFromSortFields(NSArray *sortFields) {
  NSComparator comparator = ^(id l, id r) {
    NSObject *left = (NSObject *)l;
    NSObject *right = (NSObject *)r;
    NSComparisonResult cmp = NSOrderedSame;
    for (SortField *f in sortFields) {
      INFO(@"f: %@", f); 
      NSString *key = f.key;
      Direction d = f.direction;
      id leftValue = [left valueForKey:key];
      id rightValue = [right valueForKey:key];
      if (!leftValue && !rightValue) 
        cmp = NSOrderedSame;
      else if (!leftValue) 
        cmp = NSOrderedDescending;
      else if (!rightValue) 
        cmp = NSOrderedAscending;
      else
        cmp = f.comparator ? f.comparator(leftValue, rightValue) : NSOrderedSame;
      if (f.direction == Descending) 
        cmp *= -1;
      if (cmp != NSOrderedSame) 
        break;
    }
    return cmp;
  };
  comparator = [comparator copy];
  return comparator;
}

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

