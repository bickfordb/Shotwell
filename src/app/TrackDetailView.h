// vim: set filetype=objcpp
//
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "app/Track.h"

@interface TrackDetailView : NSView {
  WebView *webView_;
  NSMutableArray *listeners_;
}
@end
