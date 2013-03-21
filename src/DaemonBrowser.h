#import <Cocoa/Cocoa.h>


@interface DaemonBrowser : NSNetServiceBrowser {
  NSSet *services_;
}
+ (DaemonBrowser *)shared;
@end

