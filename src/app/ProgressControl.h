#import <Cocoa/Cocoa.h>
#import "app/Slider.h"

typedef void(^OnElapsed)(int64_t seconds);

@interface ProgressControl : NSObject {
  NSView *view_;
  Slider *slider_;
  OnElapsed onElapsed_;
  int64_t duration_;
  int64_t elapsed_;
  NSTextField *elapsedTextField_;
  NSTextField *durationTextField_;
  bool isEnabled_;

}

@property (copy) OnElapsed onElapsed;
@property (retain) Slider *slider;
@property (retain) NSView *view;
@property int64_t elapsed;
@property int64_t duration;
@property bool isEnabled;
@property (retain) NSTextField *durationTextField;
@property (retain) NSTextField *elapsedTextField;
@end

// vim: filetype=objcpp
