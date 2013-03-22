#import "DaemonBrowser.h"
#import "Daemon.h"

static DaemonBrowser *daemonBrowser = nil;

@implementation DaemonBrowser

- (void)removeRemoteLibraryService:(NSNetService *)svc {
}

- (void)addRemoteLibraryService:(NSNetService *)svc {
}

- (id)init {
  self = [super init];
  if (self) {
    [self setDelegate:self];
    [self searchForServicesOfType:kDaemonServiceType inDomain:@"local."];
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

