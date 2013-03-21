#import "LibraryPopUpButton.h"
#import "Daemon.h"

@implementation LibraryPopUpButton
- (NSSet *)serviceTypes {
  return [NSSet setWithObjects:kDaemonServiceType, nil];
}
@end
