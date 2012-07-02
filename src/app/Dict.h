#import <Cocoa/Cocoa.h>
// vim: filetype=objcpp

@interface Dict : NSObject {
  NSMutableDictionary *dictionary_;
}
- (void)clear;
- (void)set:(id)key value:(id)value;
- (id)get:(id)key;
- (id)pop:(id)key;
+ (id)dict;
- (NSArray *)keys;
- (NSArray *)values;
- (NSArray *)items;

@end


