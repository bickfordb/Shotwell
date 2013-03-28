#import <Cocoa/Cocoa.h>
#import "Enum.h"

// A sorted thread safe sequence similar to NSArrayController, but without all the bindings oddness
// more of a sorted set, really
@interface SortedSeq : NSObject <EnumSeq, NSTableViewDataSource> /*<NSFastEnumeration> */

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

// NSArrayController-ish support
//- (id)arrangedObjects;
- (NSUInteger)countOfArrangedObjects;
- (id)objectInArrangedObjectsAtIndex:(NSUInteger)index;
- (id)arrangedObjectsAtIndexes:(NSIndexSet *)indices;
//- (void)getArrangedObjects:(id *)buffer range:(NSRange)inRange;
- (void)addObject:(id)something;
- (void)removeObject:(id)something;
- (void)removeBy:(FilterF1)block;

@end

