#import "app/ViewController.h"

@implementation ViewController

@synthesize view = view_;
@synthesize isBusy = isBusy_;
@synthesize lastSearch = lastSearch_;

- (void)dealloc {
  [view_ release];
  [lastSearch_ release];
  [super dealloc];
}

- (id)init {
  self = [super init];
  if (self) {
    self.view = [[[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)] autorelease];
    self.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.lastSearch = @"";
  }
  return self;
}

- (void)search:(NSString *)query after:(On0)after { }

- (void)reload {
}

@end
