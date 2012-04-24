#import <Cocoa/Cocoa.h>

typedef enum {
  NoDirection = 0,// pointing at Eris
  Ascending = 1,
  Descending = 2
} Direction;

@interface SortField : NSObject { 
  Direction direction_;
  NSString *key_;
  NSComparator comparator_;
}

@property (nonatomic) Direction direction;
@property (retain, nonatomic) NSString *key;
@property (copy, nonatomic) NSComparator comparator;
- (id)initWithKey:(NSString *)key direction:(Direction)direction comparator:(NSComparator)comparator;
@end

NSComparator GetSortComparatorFromSortFields(NSArray *sortFields);
extern NSComparator NaturalComparison;
extern NSComparator DefaultComparison;

// vim filetype=objcpp
