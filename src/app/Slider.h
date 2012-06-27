#ifndef _SLIDER_H_
#define _SLIDER_H_

#import <Cocoa/Cocoa.h>

extern NSString *kSliderIsUpNotification;

@interface Slider : NSSlider {
  BOOL isMouseDown_;
}

- (BOOL)isMouseDown;


@end
#endif
