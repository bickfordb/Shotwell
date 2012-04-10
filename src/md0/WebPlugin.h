#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "md0/Plugin.h"

@interface WebPlugin : Plugin {
  NSURL *url_;
  WebView *webView_;
  NSView *content_;
} 

- (id)initWithURL:(NSURL *)url;
@property (atomic, retain) NSURL *url;
- (NSView *)content;
- (void)showSize:(int)size isVertical:(BOOL)isVertical;
- (void)hide;
- (void)hideTrackTable;
- (void)log:(NSString *)msg;

@end
