#import <Cocoa/Cocoa.h>

@interface NSMutableArray (Insert)
- (void)insert:(id)obj withComparator:(NSComparator)c;
@end
// vim: filetype=objc
