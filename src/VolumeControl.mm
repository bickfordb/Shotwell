#import <Cocoa/Cocoa.h>
#import "VolumeControl.h"
#import "Player.h"

static NSString * const kLoudImage = @"loud";
static NSString * const kQuietImage = @"quiet";

@implementation VolumeControl {
  NSTimer *timer_;
  NSView *view_;
  Slider *slider_;
}
@synthesize view = view_;

- (void)dealloc {
  [timer_ invalidate];
  [view_ release];
  [slider_ release];
  [super dealloc];
}

- (id)init {
  self = [super init];
  if (self) {
    view_ = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 22 + 22 + 3 + 3 + 100, 22)];
    view_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    view_.autoresizesSubviews = YES;
    slider_ = [[Slider alloc] initWithFrame:CGRectMake(22 + 3, 0, 100, 22)];
    slider_.minValue = 0.0;
    slider_.maxValue = 1.0;
    slider_.continuous = YES;
    slider_.doubleValue = 0.5;
    slider_.target = self;
    slider_.autoresizingMask = NSViewWidthSizable;
    slider_.action = @selector(onSliderAction:);
    NSImageView *quietIcon = [[[NSImageView alloc] initWithFrame:CGRectMake(0, 0, 22, 22)] autorelease];
    quietIcon.image = [NSImage imageNamed:kQuietImage];
    [[slider_ cell] setControlSize:NSSmallControlSize];
    quietIcon.autoresizingMask = NSViewMaxXMargin;
    NSImageView *loudIcon = [[[NSImageView alloc] initWithFrame:CGRectMake(22 + 3 + 100 + 3, 0, 22, 22)] autorelease];
    loudIcon.image = [NSImage imageNamed:kLoudImage];
    loudIcon.autoresizingMask = NSViewMaxXMargin;
    [view_ addSubview:slider_];
    [view_ addSubview:quietIcon];
    [view_ addSubview:loudIcon];
    timer_ = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(copyVolume:) userInfo:nil repeats:YES];
  }
  return self;
}

- (void)copyVolume:(NSTimer *)sender {
  [self performSelectorOnMainThread:@selector(copyVolume0:) withObject:sender waitUntilDone:YES];
}

- (void)copyVolume0:(NSTimer *)sender {
  slider_.doubleValue = [Player shared].volume;
}

- (void)onSliderAction:(id)slider {
  double amt = slider_.doubleValue;
  if (amt < 0.0)
    amt = 0;
  if (amt > 1.0)
    amt = 1.0;
  [Player shared].volume = amt;
}

@end

