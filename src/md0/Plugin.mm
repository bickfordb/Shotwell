#import "md0/Plugin.h"
#import "md0/AppDelegate.h"

@implementation Plugin

- (id)init {
  self = [super init];
  if (self) { 
    content_ = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    content_.autoresizesSubviews = YES;
    content_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    content_.focusRingType = NSFocusRingTypeNone;
  }
  return self;
}

- (NSView *)content {
  return content_;
}

- (void)dealloc { 
  NSSplitView *split = (NSSplitView *)[content_ superview];
  [content_ removeFromSuperview];
  [split adjustSubviews];
  [content_ autorelease];
  [super dealloc];
}

- (void)start {
} 

- (void)stop {
} 

- (void)hide { 
  NSSplitView *split = (NSSplitView *)[content_ superview];
  [content_ removeFromSuperview];
  [split adjustSubviews];
}

- (void)showVertical:(bool)isVertical {
  [self hide];
  NSSplitView *split;
  AppDelegate *delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
  if (isVertical) 
    split = [delegate contentVerticalSplit];
  else
    split = [delegate contentHorizontalSplit];
  CGRect frame = NSZeroRect;
  if (isVertical) {
    frame.size.height = split.frame.size.height;
    frame.size.width = 200;
  } else { 
    frame.size.height = 200;
    frame.size.width = split.frame.size.width;
  }
  content_.frame = frame;
  [split addSubview:content_];
}

- (void)hideTrackTable {

}
- (void)trackStarted:(NSDictionary *)track {
}

- (void)trackEnded:(NSDictionary *)track { 
}

- (void)trackUpdated:(NSDictionary *)track {

}

@end
