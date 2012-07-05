#import "app/Log.h"
#import "app/JSON.h"
#import "test/gtest_mac.h"
#import "app/Tuple.h"

static const int n = 10000;

const char *testPayload = "{\"path\": \"/Users/bran/Music/rsynced/Clogs - The Creatures In The Garden of Lady Walton - 2010 v0/Clogs - The Creatures in the Garden of Lady Walton - 09 - Raise the Flag.mp3\", \"id\": 4561, \"isCoverArtChecked\": true, \"album\": \"The Creatures In The Garden Of Lady Walton\", \"isAudio\": true, \"trackNumber\": \"09\", \"coverArtID\": \"3ff72ff8f200c3ebc1f911b075928d18f4a9246f\", \"title\": \"Raise the Flag\", \"year\": \"2010\", \"duration\": 168000000, \"artist\": \"Clogs\", \"genre\": \"Rock\"}";

typedef void (^F)();

@interface NSData (UTF8)
- (NSString *)stringFromUTF8;
@end

@implementation NSData (UTF8)
- (NSString *)stringFromUTF8 {
  return [[[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding] autorelease];
}
@end

TEST(JSONTest, Partial) {
  id x = Tuple2(@"x", nil);
  EXPECT_TRUE(ToJSON(x) != nil);

}
