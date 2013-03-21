#include <event2/event.h>
#include <event2/buffer.h>
#include <event2/http.h>

#import "HTTP.h"
#import "JSON.h"
#import "Log.h"
#import "NSNetServiceAddress.h"
#import "RemoteLibrary.h"
#import "Util.h"

int kRefreshInterval = 10000;

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
    __block RemoteLibrary *weakSelf = self;
    [self.loop onTimeout:10000 with:^(Event *event, short flags) {
      if (weakSelf.requestRefresh)
        [weakSelf refresh];
      weakSelf.requestRefresh = false;
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

- (void)each:(void (^)(NSMutableDictionary *t))block {
  if (!tracks_)
    self.requestRefresh = true;
  else {
    for (NSMutableDictionary *t in tracks_) {
      block(t);
    }
  }
}

- (void)refresh {
  NSString *address = self.netService.ipv4Address;
  int port = self.netService.port;
  NSString *aURL = [NSString stringWithFormat:@"http://%@:%d/tracks", address, port];
  NSURL *u = [NSURL URLWithString:aURL];
  [self.loop fetchURL:u with:^(HTTPResponse *response) {
    NSArray *trackDicts = FromJSONData(response.body);
    NSMutableArray *tracks = [NSMutableArray array];
    for (NSDictionary *d in trackDicts) {
      NSMutableDictionary *d0 = [NSMutableDictionary dictionaryWithDictionary:d];
      [tracks addObject:d0];
    }
    self.tracks = tracks;
    self.lastUpdatedAt = [NSDate date];
    for (id t in self.tracks) {
      [self notifyTrack:t change:kLibraryTrackAdded];
    }
  }];
}

- (int)count {
  if (!self.tracks)
    self.requestRefresh = true;
  return self.tracks ? self.tracks.count : 0;
}

/*
- (NSURL *)coverArtURLForTrack:(Track *)t {
  NSString *c = t.coverArtID;
  return c ? [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/art/%@", netService_.ipv4Address, netService_.port, c]] : nil;
}

- (NSURL *)urlForTrack:(Track *)t {
  return [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/tracks/%llu", netService_.ipv4Address, netService_.port, t.id]];
}
*/
@end

