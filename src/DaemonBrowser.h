#import <Cocoa/Cocoa.h>


@interface DaemonBrowser : NSNetServiceBrowser <NSNetServiceBrowserDelegate> {
  NSSet *services_;
}
+ (DaemonBrowser *)shared;
- (void)removeRemoteLibraryService:(NSNetService *)svc;
- (void)addRemoteLibraryService:(NSNetService *)svc;
@end

