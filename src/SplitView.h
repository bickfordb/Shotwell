#ifndef _SPLIT_VIEW_H_
#define _SPLIT_VIEW_H_
#import <Cocoa/Cocoa.h>

@interface SplitView : NSSplitView {
  CGFloat dividerThickness_;
  NSColor *dividerColor_;
}

- (void)setDividerThickness:(CGFloat)thickness;
- (void)setDividerColor:(NSColor *)color;
@end

#endif
