#import "app/ViewController.h"

@implementation ViewController

@synthesize view = view_;

- (void)dealloc {
  [view_ release];
  [super dealloc];  
}

- (id)init { 
  self = [super init];
  if (self) {
    self.view = [[[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)] autorelease];
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  }
  return self;
}

- (void)search:(NSString *)query {

}

- (void)reload { 
}

@end
