#import "app/CoverArtScraper.h"
static NSString * const kITunesAffiliateURL = @"http://itunes.apple.com/search";

NSData *ScrapeCoverArt(NSString *query) {
  return nil;
}
//@interface CoverArtScraper : NSObject {
//}
//- (NSData *)query:(NSString *)artistAlbum;
//
//- (void)search:(NSString *)d entity:(NSString *)entity withResult:(void(^)(int status, NSArray *results))onResults;
//- (void)searchCoverArt:(NSString *)term withArtworkData:(void (^)(int status, NSData *d))block;
//@end
//@implementation CoverArtScraper
//
//- (NSData *)query:(NSString *)artistAlbum {
//  return nil;
//}
//
//- (void)search:(NSString *)term withArtworkData:(void (^)(int code, NSData *d))block {
//  __block LocalLibrary *weakSelf = self;
//  block = [block copy];
//  [self search:term entity:@"album" withResult:^(int status, NSArray *results) {
//    if (results && results.count) {
//      NSString *artworkURL = [[results objectAtIndex:0] objectForKey:@"artworkUrl100"];
//      artworkURL = [artworkURL
//        stringByReplacingOccurrencesOfString:@".100x100" withString:@".600x600"];
//      if (artworkURL && artworkURL.length) {
//        [weakSelf->coverArtLoop_ fetchURL:[NSURL URLWithString:artworkURL] with:^(HTTPResponse *response) {
//          block(response.status, response.status == 200 ? response.body : nil);
//        }];
//      } else {
//        block(status, nil);
//      }
//    } else {
//      block(status, nil);
//    }
//  }];
//}
//
//- (void)search:(NSString *)term entity:(NSString *)entity withResult:(void(^)(int status, NSArray *results))onResults {
//  onResults = [onResults copy];
//  NSURL *url = [NSURL URLWithString:kITunesAffiliateURL];
//  url = [url pushKey:@"term" value:term];
//  url = [url pushKey:@"entity" value:entity];
//  [coverArtLoop_ fetchURL:url with:^(HTTPResponse *r) {
//    NSArray *results = [NSArray array];
//    if (r.status == 200) {
//      NSDictionary *data = (NSDictionary *)FromJSONData(r.body);
//      results = [data objectForKey:@"results"];
//    }
//    onResults(r.status, results);
//  }];
//}
//@end

