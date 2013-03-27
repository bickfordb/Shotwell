#import <Cocoa/Cocoa.h>
#import "Log.h"
#import "ProgressControl.h"
#import "NSNumberTimeFormat.h"
#import "Player.h"
#import "Slider.h"
#import "Util.h"

@interface ProgressControl (Private)
@property BOOL isEnabled;
@end

@implementation ProgressControl {
  NSView *view_;
  Slider *slider_;
  int64_t duration_;
  int64_t elapsed_;
  NSTextField *elapsedTextField_;
  NSTextField *durationTextField_;
  BOOL isEnabled_;
}

@synthesize view = view_;

- (void)setDuration:(int64_t)duration {
  if (slider_.isMouseDown)
    return;
  if (duration < 0)
    duration = 0;
  if (duration_ != duration) {
    duration_ = duration;
    ForkToMainWith(^{
      durationTextField_.stringValue = [[NSNumber numberWithLongLong:duration] formatSeconds];
    });
  }
}

- (BOOL)isEnabled {
  return isEnabled_;
}

- (void)setIsEnabled:(BOOL)enabled {
  if (enabled == isEnabled_)
    return;
  isEnabled_ = enabled;
  ForkToMainWith(^{ slider_.enabled = enabled ? YES : NO; });
  duration_ = 0;
  elapsed_ = 0;
}

- (int64_t)duration {
  return duration_;
}

- (void)setElapsed:(int64_t)elapsed {
  if (elapsed < 0)
    elapsed = 0;
  if (slider_.isMouseDown)
    return;
  ForkToMainWith(^{
    elapsedTextField_.stringValue = [[NSNumber numberWithLongLong:elapsed] formatSeconds];
    slider_.doubleValue = elapsed / ((double)duration_);
  });
}

- (int64_t)elapsed {
  return (int64_t)(slider_.doubleValue * duration_);
}

- (void)dealloc {
  [self unbind:@"duration"];
  [self unbind:@"currentTrack"];
  [self unbind:@"elapsed"];
  [view_ release];
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
    view_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view_.autoresizesSubviews = YES;
    slider_ = [[Slider alloc] initWithFrame:CGRectMake(70, 0, 300, 22)];
    slider_.minValue = 0.0;
    slider_.maxValue = 1.0;
    slider_.continuous = YES;
    slider_.doubleValue = 0.5;
    slider_.enabled = NO;
    slider_.target = self;
    slider_.autoresizingMask = NSViewWidthSizable;
    slider_.action = @selector(onSliderAction:);

    elapsedTextField_ = [[NSTextField alloc] initWithFrame: CGRectMake(5, 3, 60, 15)];
    elapsedTextField_.font = [NSFont systemFontOfSize:9.0];
    elapsedTextField_.stringValue = @"";
    elapsedTextField_.alignment = NSRightTextAlignment;
    elapsedTextField_.drawsBackground = NO;
    elapsedTextField_.bordered = NO;
    elapsedTextField_.editable = NO;
    elapsedTextField_.autoresizingMask = NSViewMaxXMargin;
    elapsedTextField_.stringValue = [[NSNumber numberWithLongLong:0] formatSeconds];

    durationTextField_ = [[NSTextField alloc] initWithFrame:
      CGRectMake(5 + 60 + 5 + 300 + 5, 3, 60, 15)];
    durationTextField_.font = [NSFont systemFontOfSize:9.0];
    durationTextField_.stringValue = @"";
    durationTextField_.alignment = NSLeftTextAlignment;
    durationTextField_.drawsBackground = NO;
    durationTextField_.bordered = NO;
    durationTextField_.editable = NO;
    durationTextField_.autoresizingMask = NSViewMinXMargin;
    durationTextField_.stringValue = [[NSNumber numberWithLongLong:0] formatSeconds];

    [view_ addSubview:elapsedTextField_];
    [view_ addSubview:slider_];
    [view_ addSubview:durationTextField_];
    view_.frame = frame;
    [self bind:@"duration" toObject:[Player shared] withKeyPath:@"duration" options:nil];
    [self bind:@"elapsed" toObject:[Player shared] withKeyPath:@"elapsed" options:nil];
    [self bind:@"currentTrack" toObject:[Player shared] withKeyPath:@"track" options:nil];
  }
  return self;
}

- (void)setCurrentTrack:(NSMutableDictionary *)track {
  ForkToMainWith(^{
      if (!track) {
      self.isEnabled = NO;
      } else if (![Player shared].isSeeking) {
        slider_.enabled = YES;
      }
  });
}

- (id)currentTrack { return nil; }

- (void)onSliderAction:(id)slider {
  double amt = slider_.doubleValue;
  if (slider_.isMouseDown) {
    elapsedTextField_.stringValue = [[NSNumber numberWithLongLong:amt * duration_] formatSeconds];
  } else {
    [[Player shared] seek:amt * duration_];
  }
}

@end

