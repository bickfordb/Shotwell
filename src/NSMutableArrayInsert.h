#import <Cocoa/Cocoa.h>

@interface NSMutableArray (Insert)
- (void)insert:(id)obj sortedWithComparator:(NSComparator)c;
@end
// vim: filetype=objc
