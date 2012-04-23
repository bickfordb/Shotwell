#import <Cocoa/Cocoa.h>

typedef enum {
  NoDirection = 0,// pointing at Eris
  Ascending = 1,
  Descending = 2
} Direction;

typedef NSComparisonResult (*ComparisonFunc)(id left, id right);

@interface SortField : NSObject { 
  Direction direction_;
  NSString *key_;
  ComparisonFunc comparator_;
}

@property (nonatomic) Direction direction;
@property (retain, nonatomic) NSString *key;
@property (nonatomic) ComparisonFunc comparator;
- (id)initWithKey:(NSString *)key direction:(Direction)direction comparator:(ComparisonFunc)comparator;
@end

NSComparator GetSortComparatorFromSortFields(NSArray *sortFields);
NSComparisonResult NaturalComparison(id left, id right);

// vim filetype=objcpp
