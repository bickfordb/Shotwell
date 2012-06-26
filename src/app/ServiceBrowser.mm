#import "app/ServiceBrowser.h"

@implementation ServiceBrowser
- (id)initWithType:(NSString *)type onAdded:(OnNetService)onAdded onRemoved:(OnNetService)onRemoved {
  self = [super init];
  if (self) {
    onAdded_ = [[onAdded copy] retain];
    onRemoved_ = [[onRemoved copy] retain];
    self.delegate = self;
    [self searchForServicesOfType:type inDomain:@"local."];
  }
  return self;
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing {
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
  [netService retain];
  [netService setDelegate:self];
  [netService resolveWithTimeout:10.0];
}

- (void)netServiceDidResolveAddress:(NSNetService *)netService {
  if (onAdded_) {
    onAdded_(netService);
  }
  [netService release];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSMutableDictionary *)errorDict {
  [sender release];
}

- (void)dealloc {
  [onAdded_ release];
  [onRemoved_ release];
  [super dealloc];
}

@end
