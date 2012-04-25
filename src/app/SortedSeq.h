#import <Cocoa/Cocoa.h>

// A sorted thread safe sequence similar to NSArrayController, but without all the bindings oddness


@interface SortedSeq : NSObject <NSFastEnumeration> { 
  NSComparator comparator_;
  NSPredicate *predicate_;
  NSMutableArray *filteredItems_;
  NSMutableArray *items_;
  NSObject *ilock_;
}

@property (copy) NSComparator comparator;
@property (retain) NSPredicate *predicate; 

- (void)clear;
- (void)remove:(id)something;
- (void)add:(id)something;
- (id)get:(int)index;
- (id)getMany:(NSIndexSet *)indices;
- (int)index:(id)needle;
- (int)count;
- (NSArray *)all;
- (NSArray *)array;

@end

