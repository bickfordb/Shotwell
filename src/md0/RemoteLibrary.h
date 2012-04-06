
#import <Cocoa/Cocoa.h>
#include <stdint.h>
#include <event2/event.h>

#import "Library.h"
#import "Loop.h"

@interface RemoteLibrary : Library { 
  NSNetService *netService_;
  Loop *loop_;
  NSArray *tracks_;
  bool requestRefresh_;
}
@property (atomic, retain) NSNetService *netService;

- (void)refresh;
- (id)initWithNetService:(NSNetService *)netService;

@end
// vim: filetype=objcpp
