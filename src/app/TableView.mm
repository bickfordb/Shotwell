#import "md0/TableView.h"
#import "md0/Log.h"

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
- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
  NSMenu *menu = [super menuForEvent:theEvent];
  // Support 
  if (menu) {
    NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];
    NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    int row = [self rowAtPoint:mousePoint];
    if (row >= 0) {  
      if ([selectedRowIndexes containsIndex:row] == NO) {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:YES];
      }
    }
  }
  return menu; 
}
@end


