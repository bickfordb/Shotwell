#import "app/Log.h"
#import "app/TrackDetailView.h"
#import "app/Util.h"

@implementation TrackDetailView

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    webView_ = [[WebView alloc] initWithFrame:frame frameName:nil groupName:nil];
    webView_.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    webView_.mainFrameURL = [NSString stringWithFormat:@"file:///%@/TrackDetailView/index.html",
      [[NSBundle mainBundle] resourcePath]];
    [self addSubview:webView_];
    listeners_ = [[NSMutableArray array] retain];
    __block TrackDetailView *weakSelf = self;
    [listeners_ addObject:[[NSNotificationCenter defaultCenter]
                            addObserverForName:kTrackStarted
                            object:nil
                            queue:[NSOperationQueue mainQueue]
                            usingBlock:^(NSNotification *notification) {
                              Track *track = [notification userInfo][@"track"];
                              [weakSelf trackStarted:track];
                            }]];
  }
  return self;
}

- (void)dealloc {
  for (id i in listeners_) {
    [[NSNotificationCenter defaultCenter] removeObserver:i];
  }
  [listeners_ release];
  [webView_ release];
  [super dealloc];
}

- (void)openBrowser:(NSString *)url {
  DEBUG(@"openBrowser: %@", url);
  NSURL *url0 = [NSURL URLWithString:url];
  if (url0)
    [[NSWorkspace sharedWorkspace] openURL:url0];
}

- (void)trackStarted:(Track *)track {
  RunOnMain(^{
    [[webView_ windowScriptObject] callWebScriptMethod:@"onTrackStarted" withArguments:@[track]];
  });
}

- (void)trackSaved:(Track *)track {
  RunOnMain(^{
    [[webView_ windowScriptObject] callWebScriptMethod:@"onTrackSaved" withArguments:@[track]];
  });
}
- (void)trackAdded:(Track *)track {
  RunOnMain(^{
    [[webView_ windowScriptObject] callWebScriptMethod:@"onTrackAdded" withArguments:@[track]];
  });
}
- (void)trackDeleted:(Track *)track {
  RunOnMain(^{
    [[webView_ windowScriptObject] callWebScriptMethod:@"onTrackDeleted" withArguments:@[track]];
  });
}

- (void)trackEnded:(Track *)track {
  RunOnMain(^{
    [[webView_ windowScriptObject] callWebScriptMethod:@"onTrackEnded" withArguments:@[track]];
  });
}

@end
