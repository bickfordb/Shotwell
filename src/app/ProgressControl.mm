#import <Cocoa/Cocoa.h>
#import "app/Log.h"
#import "app/ProgressControl.h"
#import "app/NSNumberTimeFormat.h"

@implementation ProgressControl 
@synthesize onElapsed = onElapsed_;
@synthesize view = view_;
@synthesize slider = slider_;
@synthesize elapsed = elapsed_;
@synthesize isEnabled = isEnabled_;
@synthesize duration = duration_;
@synthesize elapsedTextField = elapsedTextField_;
@synthesize durationTextField = durationTextField_;

- (void)setDuration:(int64_t)duration {
  if (slider_.isMouseDown)
    return;
  if (duration < 0)
    duration = 0;
  if (duration_ != duration) {
    duration_ = duration;
    self.durationTextField.stringValue = [[NSNumber numberWithLongLong:duration] formatSeconds];
  }
}

- (bool)isEnabled { 
  return isEnabled_;
}

- (void)setIsEnabled:(bool)enabled {
  if (enabled == isEnabled_) 
    return;
  isEnabled_ = enabled;
  slider_.enabled = enabled ? YES : NO; 
  self.duration = 0;
  self.elapsed = 0;
}

- (int64_t)duration {
  return duration_;
}

- (void)setElapsed:(int64_t)elapsed { 
  if (elapsed < 0)
    elapsed = 0;
  if (slider_.isMouseDown) 
    return;
  self.elapsedTextField.stringValue = [[NSNumber numberWithLongLong:elapsed] formatSeconds];
  slider_.doubleValue = elapsed / ((double)duration_);
}

- (int64_t)elapsed { 
  return (int64_t)(slider_.doubleValue * duration_);
}

- (void)dealloc {
  [view_ release];
  [onElapsed_ release];
  [slider_ release];
  [elapsedTextField_ release];
  [durationTextField_ release];
  [super dealloc];
}

- (id)initWithFrame:(CGRect)frame; { 
  self = [super init];
  if (self) {
    duration_ = 0;
    elapsed_ = 0;
    self.view = [[[NSView alloc] initWithFrame:CGRectMake(0, 0, 435, 22)] autorelease];
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.view.autoresizesSubviews = YES;
    self.slider = [[[Slider alloc] initWithFrame:CGRectMake(70, 0, 300, 22)] autorelease];
    self.slider.minValue = 0.0;
    self.slider.maxValue = 1.0;
    self.slider.continuous = YES;
    self.slider.doubleValue = 0.5;
    self.slider.target = self;
    self.slider.autoresizingMask = NSViewWidthSizable;
    self.slider.action = @selector(onSliderAction:);

    self.elapsedTextField = [[[NSTextField alloc] initWithFrame:
      CGRectMake(5, 3, 60, 15)] autorelease];
    self.elapsedTextField.font = [NSFont systemFontOfSize:9.0];
    self.elapsedTextField.stringValue = @"";
    self.elapsedTextField.alignment = NSRightTextAlignment;
    self.elapsedTextField.drawsBackground = NO;
    self.elapsedTextField.bordered = NO;
    self.elapsedTextField.editable = NO;
    self.elapsedTextField.autoresizingMask = NSViewMaxXMargin;

    self.durationTextField = [[[NSTextField alloc] initWithFrame:
      CGRectMake(5 + 60 + 5 + 300 + 5, 3, 60, 15)] autorelease];
    self.durationTextField.font = [NSFont systemFontOfSize:9.0];
    self.durationTextField.stringValue = @"";
    self.durationTextField.alignment = NSLeftTextAlignment;
    self.durationTextField.drawsBackground = NO;
    self.durationTextField.bordered = NO;
    self.durationTextField.editable = NO;
    self.durationTextField.autoresizingMask = NSViewMinXMargin;

    [self.view addSubview:self.elapsedTextField];
    [self.view addSubview:self.slider];
    [self.view addSubview:self.durationTextField];
    self.view.frame = frame;

  }
  return self;
}

- (void)onSliderAction:(id)slider { 
  double amt = self.slider.doubleValue; 
  if (slider_.isMouseDown) {
    self.elapsedTextField.stringValue = [[NSNumber numberWithLongLong:amt * duration_] formatSeconds];
  } else if (self.onElapsed) {
    self.onElapsed(amt * duration_);
  }
}

@end

