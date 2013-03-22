#import "PlaybackControls.h"
#import "Player.h"
#import "Util.h"

@implementation PlaybackControls {
  NSImage *startImage_;
  NSImage *stopImage_;
  On0 onPrevious_;
  On0 onPlay_;
  On0 onNext_;
  dispatch_source_t pollTimer_;
}
@synthesize onNext = onNext_;
@synthesize onPrevious = onPrevious_;
@synthesize onPlay = onPlay_;

- (void)dealloc {
  dispatch_release(pollTimer_);
  [stopImage_ release];
  [startImage_ release];

  [super dealloc];
}

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.segmentCount = 3;
    [[self cell] setTrackingMode:NSSegmentSwitchTrackingMomentary];
    self.segmentStyle = NSSegmentStyleTexturedRounded;
    [self setImage:[NSImage imageNamed:@"left"] forSegment:0];
    [self setImageScaling:NSImageScaleProportionallyUpOrDown forSegment:0];
    [self setImage:startImage_ forSegment:1];
    [self setImageScaling:NSImageScaleProportionallyUpOrDown forSegment:1];
    [self setImage:[NSImage imageNamed:@"right"] forSegment:2];
    [self setImageScaling:NSImageScaleProportionallyUpOrDown forSegment:2];
    [self sizeToFit];
    self.action = @selector(onClick:);
    self.target = self;
    startImage_ = [[NSImage imageNamed:@"start"] retain];
    stopImage_ = [[NSImage imageNamed:@"stop"] retain];
    __block PlaybackControls *weakSelf = self;
    pollTimer_ = CreateDispatchTimer(0.5, dispatch_get_main_queue(), ^{
        [weakSelf setImage:([Player shared].isPlaying ? weakSelf->stopImage_ : weakSelf->startImage_) forSegment:1];
    });
  }
  return self;
}

- (void)onClick:(id)sender {
  long idx = self.selectedSegment;
  On0 handler = nil;
  switch (idx) {
  case 0:
    handler = onPrevious_;
    break;
  case 1:
    handler = onPlay_;
    break;
  case 2:
    handler = onNext_;
    break;
  }
  if (handler)
    handler();
}
@end

