#import "app/ServicePopUpButton.h"
#import "app/Log.h"

@implementation ServicePopUpButton
@synthesize services = services_;
@synthesize loop = loop_;
@synthesize onService = onService_;
@synthesize browser = browser_;

- (void)dealloc { 
  [browser_ release];
  [loop_ release];
  [onService_ release];
  [services_ release];
  [super dealloc];
}

- (id)initWithFrame:(CGRect)frame serviceTypes:(NSSet *)serviceTypes { 
  self = [super initWithFrame:frame];
  if (self) {
    self.services = [NSMutableArray array];
    self.loop = [Loop loop];
    self.browser = [[[NSNetServiceBrowser alloc] init] autorelease];
    [self.browser setDelegate:self];
    for (NSString *serviceType in serviceTypes) {
      [self.browser searchForServicesOfType:serviceType inDomain:@"local."];
    }
    self.target = self;
    self.action = @selector(onClick:);
  }
  return self;
}

- (void)onClick:(id)sender { 
  int i = (int)self.indexOfSelectedItem;
  if (i >= 0 && i < services_.count && onService_) {
    onService_([[services_ objectAtIndex:i] valueForKey:@"value"]);
  }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing {
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
  INFO(@"found service: %@", netService);
  [netService retain];
  [netService setDelegate:self];
  [netService resolveWithTimeout:10.0];
}
- (void)appendItemWithTitle:(NSString *)title value:(id)value {
  NSMutableDictionary *d = [NSMutableDictionary dictionary];
  [d setValue:title forKey:@"title"];
  [d setValue:value forKey:@"value"];
  [self.services addObject:d];
  [self reload];
}

- (void)reload {
  int index = self.indexOfSelectedItem;
  [self removeAllItems];
  for (NSDictionary *d in self.services) {
    [self addItemWithTitle:[d objectForKey:@"title"]];
  }
  if (index < 0) {
    index = 0;
  }
  [self selectItemAtIndex:index];
}

- (void)netServiceDidResolveAddress:(NSNetService *)netService {
  [self appendItemWithTitle:netService.name value:netService];
  [netService release];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSMutableDictionary *)errorDict {
  [sender release];
}

- (NSMutableDictionary *)getItem:(NSNetService *)netService {
  return nil;
}

@end
