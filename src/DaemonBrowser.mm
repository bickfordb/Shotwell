#import "DaemonBrowser.h"

static DaemonBrowser *daemonBrowser = nil;

@implementation DaemonBrowser

- (id)init {
  self = [super init];
  if (self) {
    [self.daemonBrowser setDelegate:self];
    [self.daemonBrowser searchForServicesOfType:kDaemonServiceType inDomain:@"local."];
  }
  return self;
}

+ (DaemonBrowser *)shared {
  if (!daemonBrowser) {
    daemonBrowser = [[DaemonBrowser alloc] init];
  }
  return daemonBrowser;
}

@end

