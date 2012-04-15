#import "md0/SortField.h"
#import "md0/NSStringNaturalComparison.h"

@implementation SortField 
@synthesize key = key_;
@synthesize direction = direction_;
@synthesize comparator = comparator_;

- (id)initWithKey:(NSString *)key direction:(Direction)direction comparator:(ComparisonFunc)comparator {
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
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}
@end

NSComparisonResult CompareWithSortFields(id l, id r, void *ctx) {
  NSArray *sortFields = (NSArray *)ctx;
  NSObject *left = (NSObject *)l;
  NSObject *right = (NSObject *)r;
  NSComparisonResult cmp = NSOrderedSame;
  for (SortField *f in sortFields) {
    NSString *key = f.key;
    Direction d = f.direction;
    id leftValue = [left valueForKey:key];
    id rightValue = [right valueForKey:key];
    cmp = f.comparator(leftValue, rightValue);
    if (f.direction == Descending) 
      cmp *= -1;
    if (cmp != NSOrderedSame) 
      break;
  }
  return cmp;
}

NSComparisonResult NaturalComparison(id left, id right) {
  NSString *l = left;
  NSString *r = right;
  NSComparisonResult ret;
  if (![l length] && [r length]) 
    ret = 1;
  else if ([l length] && ![r length])
    ret = -1;
  else
    ret = [l naturalCompareCaseInsensitive:r];
  return ret;
}


