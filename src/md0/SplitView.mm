#import "md0/SplitView.h"

@implementation SplitView

- (id)initWithFrame:(CGRect)frame { 
  self = [super initWithFrame:frame];
  if (self) { 
    dividerThickness_ = 1.0;
    [self setDividerColor:[NSColor clearColor]];
  }
  return self;
}

- (void)setDividerThickness:(CGFloat)thickness {
  dividerThickness_ = thickness;
}

- (CGFloat)dividerThickness {
  return dividerThickness_;
}

- (NSColor *)dividerColor {
  return !dividerColor_ ? [super dividerColor] : dividerColor_;
}

- (void)setDividerColor:(NSColor *)dividerColor { 
  [dividerColor_ autorelease];
  dividerColor_ = [dividerColor retain];
}

- (void)dealloc { 
  [dividerColor_ autorelease];  
  [super dealloc];
}

@end
