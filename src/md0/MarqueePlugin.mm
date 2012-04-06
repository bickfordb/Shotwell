#import "md0/MarqueePlugin.h"
#import "md0/Log.h"
#import "md0/Util.h"
#include <string>

using namespace std;

@implementation MarqueePlugin 
@synthesize track = track_;


- (void)setCoverArtURL:(NSURL *)coverArtURL {
  @synchronized(self) {
    [coverArtURL_ autorelease];
    coverArtURL_ = [coverArtURL_ retain];
  }
  [self render];
}
 
- (NSURL *)coverArtURL { 
  return coverArtURL_;
}

- (id)init {
  self = [super init];
  if (self) {
    webView_ = [[WebView alloc] initWithFrame:[[self content] frame] frameName:nil groupName:nil];
    webView_.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    track_ = NULL;
    coverArtURL_ = nil;
    [[self content] addSubview:webView_];
  }
  return self;
}

- (void)dealloc { 
  [webView_ removeFromSuperview];
  [webView_ autorelease];
  [coverArtURL_ autorelease];
  [super dealloc];
}

- (void)trackStarted:(NSDictionary *)track {
  self.track = track;
  [self render];
}

- (void)render { 
  NSMutableString *html = [NSMutableString stringWithCapacity:1];
  [html appendString:@"<html>"];
  [html appendString:@"<head>"];
  [html appendString:@"<style>"];
  [html appendString:@"* { font-family: lucida grande; color: white; background: black;}"];
  [html appendString:@"p.title { font-weight: bold; }"];
  [html appendString:@"p.artist, p.album { font-style: italic; }"];
  [html appendString:@"</style>"];
  [html appendString:@"</head>"];
  [html appendString:@"<body>"];
  
  if (coverArtURL_) { 
    [html appendFormat:@"<p><img src=\"%@\" /></p>", coverArtURL_];
  }

  [html appendFormat:@"<p class=title>%@</p>", [track_ objectForKey:kTitle]];
  [html appendFormat:@"<p class=artist>%@</p>", [track_ objectForKey:kArtist]];
  [html appendFormat:@"<p class=album>%@</p>", [track_ objectForKey:kAlbum]];
  [html appendString:@"</body>"];
  [html appendString:@"</html>"];
  [[webView_ mainFrame] 
    loadHTMLString:html 
    baseURL:[NSURL URLWithString:@"http://127.0.0.1/"]];
  [self showVertical:YES];
}

- (void)trackEnded:(NSDictionary *)track { 
  self.track = nil;
  [self hide];
}

@end
