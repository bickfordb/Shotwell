#ifndef _MARQUEE_PLUGIN_H_
#define _MARQUEE_PLUGIN_H_

#include <WebKit/WebKit.h>
#import "Plugin.h"

@interface MarqueePlugin : Plugin {
  WebView *webView_;
  NSDictionary *track_;
  NSURL *coverArtURL_;
}

- (void)render;
@property (retain, atomic) NSDictionary *track;
@end

#endif
