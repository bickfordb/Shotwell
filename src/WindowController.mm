#import "WindowController.h"

@implementation WindowController
@synthesize window = window_;

- (id)init {
  self = [super init];
  if (self) {
    self.window = [[[NSWindow alloc]
      initWithContentRect:CGRectMake(50, 50, 300, 300)
      styleMask:NSClosableWindowMask | NSTitledWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask
      backing:NSBackingStoreBuffered
      defer:YES] autorelease];
    self.window.autorecalculatesKeyViewLoop = YES;
    self.window.releasedWhenClosed = NO;
    ((NSView *)self.window.contentView).autoresizingMask = NSViewMinYMargin | NSViewHeightSizable;
    ((NSView *)self.window.contentView).autoresizesSubviews = YES;
  }
  return self;
}

- (void)dealloc {
  [window_ release];
  [super dealloc];
}
@end;

