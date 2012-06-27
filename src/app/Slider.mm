
#import "Slider.h"

@implementation Slider

- (id)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    isMouseDown_ = NO;
  }
  return self;
}

- (void)mouseDown:(NSEvent *)event {
  isMouseDown_ = YES;
  [super mouseDown:event];
  isMouseDown_ = NO;
  // call action again
  if (self.target)
    [self.target performSelector:self.action withObject:self];
}

- (BOOL)isMouseDown {
  return isMouseDown_;
}


@end
