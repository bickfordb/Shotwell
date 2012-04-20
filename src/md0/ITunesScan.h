#import <Cocoa/Cocoa.h>
#import "md0/Track.h"

typedef void (^OnITunesTrack)(Track *t);

void GetITunesTracks(OnITunesTrack block);

// vim: filetype=objcpp

