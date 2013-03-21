#import <Cocoa/Cocoa.h>


@interface AppDelegate : NSObject <NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>
+ (AppDelegate *)shared;
@end


