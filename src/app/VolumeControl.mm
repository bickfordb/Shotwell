#import <Cocoa/Cocoa.h>
#import "app/VolumeControl.h"

static NSString * const kLoudImage = @"loud";
static NSString * const kQuietImage = @"quiet";

@implementation VolumeControl
@synthesize onVolume = onVolume_;
@synthesize view = view_;
@synthesize slider = slider_;

- (void)setLevel:(double)amount {
  // FIXME: only do this on the main thread.
  self.slider.doubleValue = amount;
}

- (void)dealloc {
  [view_ release];
  [onVolume_ release];
  [slider_ release];
  [super dealloc];
}

- (double)level {
  return self.slider.doubleValue;
}

- (id)init {
  self = [super init];
  if (self) {
    self.view = [[[NSView alloc] initWithFrame:CGRectMake(0, 0, 22 + 22 + 3 + 3 + 100, 22)] autorelease];
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.view.autoresizesSubviews = YES;
    self.slider = [[[Slider alloc] initWithFrame:CGRectMake(22 + 3, 0, 100, 22)] autorelease];
    self.slider.minValue = 0.0;
    self.slider.maxValue = 1.0;
    self.slider.continuous = YES;
    self.slider.doubleValue = 0.5;
    self.slider.target = self;
    self.slider.autoresizingMask = NSViewWidthSizable;
    self.slider.action = @selector(onSliderAction:);
    NSImageView *quietIcon = [[[NSImageView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)] autorelease];
    quietIcon.image = [NSImage imageNamed:kQuietImage];
    [[self.slider cell] setControlSize:NSSmallControlSize];
    quietIcon.autoresizingMask = NSViewMaxXMargin;
    NSImageView *loudIcon = [[[NSImageView alloc] initWithFrame:CGRectMake(22 + 3 + 100 + 3, 0, 22, 22)] autorelease];
    loudIcon.image = [NSImage imageNamed:kLoudImage];
    loudIcon.autoresizingMask = NSViewMaxXMargin;
    [self.view addSubview:self.slider];
    [self.view addSubview:quietIcon];
    [self.view addSubview:loudIcon];
  }
  return self;
}

- (void)onSliderAction:(id)slider {
  double amt = self.slider.doubleValue;
  if (amt < 0.0)
    amt = 0;
  if (amt > 1.0)
    amt = 1.0;
  if (self.onVolume)
    self.onVolume(amt);
}

@end

