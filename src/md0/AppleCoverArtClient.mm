#import "md0/AppleCoverArtClient.h"
#import "md0/JSON.h"
#import "md0/NSURLAdditions.h"
#import "md0/Track.h"
#import "md0/HTTP.h"

static const int64_t kPollInterval = 500000;

static NSString * const kITunesAffiliateURL = @"http://itunes.apple.com/search";

@interface AppleCoverArtClient (P)
- (void)search:(NSString *)d entity:(NSString *)entity withResult:(void(^)(NSArray *results))onResults;
@end

@implementation AppleCoverArtClient
@synthesize loop = loop_;

- (id)init {
  self = [super init];
  if (self) { 
    self.loop = [Loop loop];
  }
  return self;
}

- (void)search:(NSString *)term withArtworkData:(void (^)(NSData *d))block {
  block = [block copy];
  [self search:term entity:@"album" withResult:^(NSArray *results) {
    if (results && results.count) { 
      NSString *artworkURL = [[results objectAtIndex:0] objectForKey:@"artworkUrl100"];
      artworkURL = [artworkURL
        stringByReplacingOccurrencesOfString:@".100x100" withString:@".600x600"];
      if (artworkURL && artworkURL.length) {
        [self.loop fetchURL:[NSURL URLWithString:artworkURL] with:^(HTTPResponse *response) { 
          block(response.status == 200 ? response.body : nil);
        }];
      } else { 
        block(nil);
      }
    } else {
      block(nil);
    }
  }];
}

- (void)search:(NSString *)term entity:(NSString *)entity withResult:(void(^)(NSArray *results))onResults { 
  onResults = [onResults copy]; 
  NSURL *url = [NSURL URLWithString:kITunesAffiliateURL];
  url = [url pushKey:@"term" value:term];
  url = [url pushKey:@"entity" value:entity];
  [loop_ fetchURL:url with:^(HTTPResponse *r) { 
    NSArray *results = [NSArray array];
    if (r.status == 200) {
      NSDictionary *data = (NSDictionary *)r.body.decodeJSON;
      results = [data objectForKey:@"results"];
    }
    onResults(results);
  }];
}

- (void)dealloc { 
  self.loop = nil;
  [super dealloc];
}
@end

