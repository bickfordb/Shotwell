
#import "Slider.h"

NSString *kSliderIsUpNotification = @"SliderIsUpNotification";

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
  [[NSNotificationCenter defaultCenter] postNotificationName:kSliderIsUpNotification object:self];
}

- (BOOL)isMouseDown {
  return isMouseDown_;
}

 
@end
