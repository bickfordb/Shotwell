#import "app/ITunesScan.h"
#import "app/Log.h"

void GetITunesTracks(OnITunesTrack block) {
  NSString *homePath = NSHomeDirectory();
  NSString *itunesXMLPath = [NSString stringWithFormat:@"%@/Music/iTunes/iTunes Music Library.xml", homePath];
  NSURL *itunesURL = [NSURL fileURLWithPath:itunesXMLPath];
  NSError *xmlError = nil;
  NSData *data = [NSData dataWithContentsOfURL:itunesURL];
  NSError *error = nil;

  NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
  id result = [NSPropertyListSerialization 
    propertyListWithData:data
    options:NSPropertyListMutableContainersAndLeaves
    format:&format
    error:&error];
  if (!result) {
    ERROR(@"encountered error loading itunes XML: %@", error);
    return;
  } 
  NSDictionary *tracks = [((NSDictionary *)result) objectForKey:@"Tracks"];
  [tracks enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Track *t = [[[Track alloc] init] autorelease];
    NSDictionary *trackInfo = (NSDictionary *)obj;
    t.artist = [trackInfo objectForKey:@"Artist"];
    t.title = [trackInfo objectForKey:@"Name"];
    t.album = [trackInfo objectForKey:@"Album"];
    t.genre = [trackInfo objectForKey:@"Genre"];
    t.trackNumber = [trackInfo objectForKey:@"Track Number"];
    NSString *location = [trackInfo objectForKey:@"Location"];
    if (location)  {
      NSURL *url = [NSURL URLWithString:location];
      t.url = url.isFileURL ? [url path] : [url absoluteString];
    }
    NSNumber *year = [trackInfo objectForKey:@"year"];
    if (year)
      t.year = year.stringValue;
    block(t); 
    [pool release];
  }];
}
