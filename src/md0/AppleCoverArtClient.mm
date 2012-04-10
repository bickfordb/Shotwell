#import "md0/AppleCoverArtClient.h"
#import "md0/JSON.h"
#import "md0/NSURLAdditions.h"
#import "md0/Track.h"

static const int64_t kPollInterval = 500000;

static NSString * const kITunesAffiliateURL = @"http://itunes.apple.com/search";

@interface AppleCoverArtClient (P)
- (void)search:(NSString *)d
  entity:(NSString *)entity
  withResult:(void(^)(NSArray *results))onResults;
@end

@implementation AppleCoverArtClient

- (id)init {
  self = [super init];
  if (self) { 
    queries_ = [[NSMutableArray array] retain];
    loop_ = [[Loop alloc] init];
    timeoutEvent_ = [[Event timeoutEventWithLoop:loop_ interval:kPollInterval] retain];
    timeoutEvent_.delegate = self;
    //level_ = [[Level alloc] initWithPath:@"/Users/bran/x.db"];
  }
  return self;
}

- (void)eventTimeout:(Event *)e {
}

- (void)queryTrack:(Track *)track block:(void (^)(NSString *artworkURL))block { 
  NSMutableDictionary *q = [NSMutableDictionary dictionary];
  [q setObject:track forKey:@"track"];
  block = Block_copy(block);
  [q setObject:block forKey:@"block"];
  NSString *term = [NSString stringWithFormat:@"%@ %@", track.artist, track.album, nil];
  [self 
    search:term
    entity:@"album"
    withResult:^(NSArray *results) {
      NSString *artworkURL = nil;
      if (results.count > 0) {
        NSDictionary *first = [results objectAtIndex:0]; 
        artworkURL = [[first objectForKey:@"artworkUrl100"]
          stringByReplacingOccurrencesOfString:@".100x100" withString:@".600x600"];
      }
      block(artworkURL);
    }];
}

- (void)search:(NSString *)term entity:(NSString *)entity withResult:(void(^)(NSArray *results))onResults { 
  onResults = [onResults copy]; 
  NSURL *url = [NSURL URLWithString:kITunesAffiliateURL];
  url = [url pushKey:@"term" value:term];
  url = [url pushKey:@"entity" value:entity];
  [loop_ fetchURL:url withBlock:^(HTTPResponse *r) { 
    NSDictionary *data = (NSDictionary *)r.body.decodeJSON;
    if (r.status != 200 || !data) 
      return;
    NSArray *results = [data objectForKey:@"results"];
    if (!results)
      return;
    onResults(results); 
  }];
}

- (void)dealloc { 
  NSLog(@"dealloc: %@", self);
  [timeoutEvent_ release];
  [loop_ release];
  [queries_ release];
  [super dealloc];
}
@end

