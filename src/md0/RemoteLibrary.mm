#include <event2/event.h>
#include <event2/buffer.h>
#include <event2/http.h>

#import "md0/HTTP.h"
#import "md0/JSON.h"
#import "md0/Log.h"
#import "md0/NSNetServiceAddress.h"
#import "md0/RemoteLibrary.h"
#import "md0/Util.h"

@implementation RemoteLibrary

@synthesize netService = netService_;
@synthesize loop = loop_;
@synthesize requestRefresh = requestRefresh_;
@synthesize tracks = tracks_;

- (id)initWithNetService:(NSNetService *)netService {
  self = [super init];
  if (self) { 
    self.netService = netService;
    self.loop = [Loop loop];
    self.tracks = nil;
    self.requestRefresh = false;
    void *weakSelf = (void *)self;
    [self.loop onTimeout:10000 with:^(Event *event, short flags) {
      RemoteLibrary *l = (RemoteLibrary *)weakSelf;
      if (l.requestRefresh) 
        [l refresh];
      l.requestRefresh = false;
      [event add:10000];
    }];
  }
  return self;
}

- (void)dealloc { 
  self.netService = nil;
  self.loop = nil;
  [super dealloc];
}

- (void)each:(void (^)(Track *t))block {
  if (!tracks_) 
    self.requestRefresh = true;
  else { 
    for (Track *t in tracks_) {
      block(t);  
    }
  }
}

- (void)refresh {
  NSString *address = self.netService.ipv4Address;
  int port = self.netService.port;
  NSString *aURL = [NSString stringWithFormat:@"http://%@:%d/library", address, port];
  NSURL *u = [NSURL URLWithString:aURL];
  [self.loop fetchURL:u with:^(HTTPResponse *response) {
    NSArray *trackDicts = [response.body decodeJSON];
    NSMutableArray *tracks = [NSMutableArray array];
    for (NSDictionary *d in trackDicts) {
      Track *t = [[[Track alloc] init] autorelease];   
      [d enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
        [t setValue:val forKey:key];
      }];
      t.url = [NSString stringWithFormat:@"http://%s:%d/tracks/%d",
        address.UTF8String, port, (int)t.id.intValue];
      [tracks addObject:t];
    }
    self.tracks = tracks; 
    self.lastUpdatedAt = Now();
  }];
}

- (int)count { 
  if (!self.tracks)
    self.requestRefresh = true;
  return self.tracks ? self.tracks.count : 0;
}

@end

