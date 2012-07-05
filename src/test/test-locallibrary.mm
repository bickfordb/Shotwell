#import "app/Log.h"
#import "app/JSON.h"
#import "test/gtest_mac.h"
#import "app/LocalLibrary.h"

TEST(LocalLibraryTest, GetPut) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  system("rm -rf /tmp/library-test");
  system("rm -rf /tmp/library-test-cover-art");
  Track *t = [[[Track alloc] init] autorelease];
  t.path = @"/tmp/x.mp3";
  EXPECT_TRUE(t.id == nil);
  LocalLibrary *library = [[[LocalLibrary alloc] initWithDBPath:@"/tmp/library-test" coverArtPath:nil] autorelease];
  [library save:t];
  EXPECT_TRUE(t.id != nil);
  Track *other = [library get:t.id];
  EXPECT_TRUE(other != nil);
  EXPECT_NSEQ(t, other);
  [pool release];
}

TEST(LocalLibraryTest, Index) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  system("rm -rf /tmp/library-test");
  system("rm -rf /tmp/library-test-cover-art");
  LocalLibrary *library = [[[LocalLibrary alloc] initWithDBPath:@"/tmp/library-test" coverArtPath:nil] autorelease];
  Track *t = [library index:@"test-data/example.mp3"];
  EXPECT_TRUE(t != nil);
  EXPECT_TRUE(t.id != nil);
  EXPECT_NSEQ(t.path, @"test-data/example.mp3");
  EXPECT_NSEQ(t.artist, @"Brandon Bickford");
  // Make sure we handle duplicates OK
  Track *other = [library index:@"test-data/example.mp3"];
  EXPECT_NSEQ(t.id, other.id);
  [pool release];
}
