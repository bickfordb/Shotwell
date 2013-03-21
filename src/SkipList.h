#ifndef DEBUGSKIPLIST
#define DEBUGSKIPLIST 0
#endif

#import <Cocoa/Cocoa.h>
#import "Enum.h"
// vim: filetype=objcpp
//
struct SkipListNode;

@protocol SkipListLike <EnumSeq, EnumMap>
- (id)initWithComparator:(NSComparator)comparator;
- (void)set:(id)key to:(id)object;
- (bool)contains:(id)key;
- (void)delete:(id)key;
- (long)count;
- (void)clear;
- (id)at:(long)index;
- (NSArray *)keys;
- (NSArray *)values;
- (NSArray *)items;
- (id)get:(id)key;
#if DEBUGSKIPLIST
- (void)validate;
#endif
@property (copy) NSComparator comparator;
@end

@interface SkipList : NSObject <SkipListLike> {
  NSComparator comparator_;
  struct SkipListNode *head_;
  long level_;
  long count_;
}
@end

/* A container around SkipList with all of the methods wrapped in @synchronize {} */
@interface ConcurrentSkipList : NSObject <SkipListLike> {
  SkipList *skipList_;
}
@end
