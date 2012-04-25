#import <Cocoa/Cocoa.h>

#import "app/Track.h"

@interface Plugin : NSObject { 
}

- (void)trackStarted:(Track *)t;
- (void)trackEnded:(Track *)t;
- (void)trackAdded:(Track *)t;
- (void)trackSaved:(Track *)t;
- (void)trackDeleted:(Track *)t;

@end
