#import "app/LibraryPopUpButton.h"
#import "app/Daemon.h"

@implementation LibraryPopUpButton
- (NSSet *)serviceTypes { 
  return [NSSet setWithObjects:kDaemonServiceType, nil];
}
@end
