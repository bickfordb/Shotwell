#import <Cocoa/Cocoa.h>
#import "app/SkipList.h"
#import "app/Enum.h"

// A sorted thread safe sequence similar to NSArrayController, but without all the bindings oddness
// more of a sorted set, really
@interface SortedSeq : NSObject <EnumSeq> /*<NSFastEnumeration> */ {
  NSPredicate *predicate_;
  NSComparator comparator_;
  SkipList *filteredItems_;
  SkipList *items_;
  NSObject *ilock_;
}

@property (copy) NSComparator comparator;
@property (retain) NSPredicate *predicate;

- (void)clear;
- (void)remove:(id)something;
- (void)add:(id)something;
- (id)get:(int)index;
- (id)getMany:(NSIndexSet *)indices;
//- (int)index:(id)needle;
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

