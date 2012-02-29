
#import <Cocoa/Cocoa.h>

extern NSString *kSliderIsUpNotification;

@interface MD1Slider : NSSlider {
  BOOL isMouseDown_;  
}

- (BOOL)isMouseDown;


@end

