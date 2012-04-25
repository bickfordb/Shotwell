#import <Cocoa/Cocoa.h>
#import "app/Track.h"

typedef void (^OnITunesTrack)(Track *t);

void GetITunesTracks(OnITunesTrack block);

// vim: filetype=objcpp

