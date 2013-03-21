#import <Cocoa/Cocoa.h>
#import "Track.h"

typedef void (^OnITunesTrack)(NSMutableDictionary *track);

void GetITunesTracks(OnITunesTrack block);

// vim: filetype=objcpp

