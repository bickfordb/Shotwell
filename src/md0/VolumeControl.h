#import <Cocoa/Cocoa.h>
#import "md0/Slider.h"

typedef void(^OnVolume)(double pct);

@interface VolumeControl : NSObject { 
  NSView *view_;
  Slider *slider_;
  OnVolume onVolume_; 
}
@property (copy) OnVolume onVolume;
@property (retain) Slider *slider;
@property (retain) NSView *view;
@property double level;
@end

// vim: filetype=objcpp
