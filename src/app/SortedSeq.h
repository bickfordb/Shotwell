#import <Cocoa/Cocoa.h>

// A sorted thread safe sequence similar to NSArrayController, but without all the bindings oddness
// more of a sorted set, really
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
- (void)willChangeArrangedObjects:(NSIndexSet *)indices;
- (void)didChangeArrangedObjects:(NSIndexSet *)indices;

// NSArrayController-ish support
//- (id)arrangedObjects;
- (NSUInteger)countOfArrangedObjects;
- (id)objectInArrangedObjectsAtIndex:(NSUInteger)index;
- (id)arrangedObjectsAtIndexes:(NSIndexSet *)indices;
//- (void)getArrangedObjects:(id *)buffer range:(NSRange)inRange;
- (void)addObject:(id)something;
- (void)removeObject:(id)something;

@end

