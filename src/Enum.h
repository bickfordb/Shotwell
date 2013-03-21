#import <Cocoa/Cocoa.h>
// vim: set filetype=objcpp

typedef void (^EnumBlock)(id val, bool *stop);
typedef void (^MapEnumBlock)(id key, id val, bool *stop);

typedef id (^F0)();
typedef id (^F1)(id a);
typedef id (^F2)(id a, id b);
typedef bool (^FilterF0)();
typedef bool (^FilterF1)(id a);
typedef bool (^FilterF2)(id a, id b);

@protocol EnumSeq
- (void)each:(EnumBlock)block;
@end

@protocol EnumMap
- (void)eachItem:(MapEnumBlock)block;
@end

int IndexOf(id <EnumSeq> seq, id item);
NSArray *Map(id <EnumSeq> seq, F1 block);
NSArray *Filter(id <EnumSeq> seq, FilterF1 block);
id Fold(id initial, id <EnumSeq> items, F2 block);

@interface NSArray (Enumerated) <EnumSeq>
@end

