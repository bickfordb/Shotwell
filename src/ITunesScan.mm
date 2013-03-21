#import "ITunesScan.h"
#import "Log.h"

void GetITunesTracks(OnITunesTrack block) {
  NSString *homePath = NSHomeDirectory();
  NSString *itunesXMLPath = [NSString stringWithFormat:@"%@/Music/iTunes/iTunes Music Library.xml", homePath];
  NSURL *itunesURL = [NSURL fileURLWithPath:itunesXMLPath];
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
    NSMutableDictionary *track = TrackNew();
    NSDictionary *trackInfo = (NSDictionary *)obj;
    track[kTrackArtist] = [trackInfo objectForKey:@"Artist"];
    track[kTrackTitle] = [trackInfo objectForKey:@"Name"];
    track[kTrackAlbum] = [trackInfo objectForKey:@"Album"];
    track[kTrackGenre] = [trackInfo objectForKey:@"Genre"];
    track[kTrackNumber] = [trackInfo objectForKey:@"Track Number"];
    NSString *location = [trackInfo objectForKey:@"Location"];
    if (location)  {
      NSURL *u = [NSURL URLWithString:location];
      if (u.isFileURL) {
        track[kTrackPath] = u.path;
      }
    }
    NSNumber *year = [trackInfo objectForKey:@"year"];
    if (year)
      track[kTrackYear] = year.stringValue;
    NSString *path = track[kTrackPath];
    if (path && path.length)
      block(track);
    [pool release];
  }];
}
