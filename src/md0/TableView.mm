#import "md0/TableView.h"

@implementation TableView
@synthesize onKeyDown = onKeyDown_;

- (void)dealloc { 
  self.onKeyDown = nil;
  [super dealloc];
}

- (void)keyDown:(NSEvent *)event { 
  if (self.onKeyDown) {
    if (!self.onKeyDown(event))
      return;
  }
  [super keyDown:event];
}

@end


