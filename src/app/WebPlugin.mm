#import "app/AppDelegate.h"
#import "app/Log.h"
#import "app/WebPlugin.h"

@implementation WebPlugin
@synthesize url = url_;

- (id)initWithURL:(NSURL *)url {
  self = [super init];
  if (self) {
    content_ = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    content_.autoresizesSubviews = YES;
    content_.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    content_.focusRingType = NSFocusRingTypeNone;
    url_ = [url retain];
    webView_ = [[WebView alloc] initWithFrame:[[self content] frame] frameName:nil groupName:nil];
    webView_.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
    webView_.mainFrameURL = url.absoluteString;
    [self.content addSubview:webView_];
    [webView_.windowScriptObject setValue:self forKey:@"plugin"];
  }
  return self;
}

- (BOOL)hidden { 
  return !(self.content.superview);
}

- (AppDelegate *)controller  {
  return (AppDelegate *)[[NSApplication sharedApplication] delegate];
}

- (void)trackStarted:(NSMutableDictionary *)track { 
  [self performSelectorOnMainThread:@selector(trackStarted0:) withObject:track waitUntilDone:NO];
}

- (void)trackStarted0:(NSMutableDictionary *)track { 
  NSArray *args = [NSArray arrayWithObjects:track, nil];
  id window = [webView_ windowScriptObject];
  [window callWebScriptMethod:@"onTrackStarted" withArguments:args];
  [window setValue:Block_copy(^(NSString *s) { DEBUG(@"logit: %@", s); }) forKey:@"logit"];
}

- (void)openBrowser:(NSString *)url {
  DEBUG(@"openBrowser: %@", url);
  NSURL *url0 = [NSURL URLWithString:url];
  if (url0) 
    [[NSWorkspace sharedWorkspace] openURL:url0];
}

- (void)trackSaved:(NSMutableDictionary *)track { 
  [self performSelectorOnMainThread:@selector(trackSaved0:) withObject:track waitUntilDone:NO];
}

- (void)trackSaved0:(NSMutableDictionary *)track { 
  NSArray *args = [NSArray arrayWithObjects:track, nil];
  id window = [webView_ windowScriptObject];
  [window callWebScriptMethod:@"onTrackSaved" withArguments:args];
}

- (void)trackAdded:(NSMutableDictionary *)track { 
  [self performSelectorOnMainThread:@selector(trackAdded0:) withObject:track waitUntilDone:NO];
}

- (void)trackAdded0:(NSMutableDictionary *)track { 
  NSArray *args = [NSArray arrayWithObjects:track, nil];
  id window = [webView_ windowScriptObject];
  [window callWebScriptMethod:@"onTrackAdded" withArguments:args];
}

- (void)trackDeleted:(NSMutableDictionary *)track { 
  [self performSelectorOnMainThread:@selector(trackDeleted0:) withObject:track waitUntilDone:NO];
}

- (void)trackDeleted0:(NSMutableDictionary *)track { 
  NSArray *args = [NSArray arrayWithObjects:track, nil];
  id window = [webView_ windowScriptObject];
  [window callWebScriptMethod:@"onTrackDeleted" withArguments:args];
}

- (void)trackEnded:(NSMutableDictionary *)track { 
  [self performSelectorOnMainThread:@selector(trackEnded0:) withObject:track waitUntilDone:NO];
}

- (void)trackEnded0:(NSMutableDictionary *)track { 
  NSArray *args = [NSArray arrayWithObjects:track, nil];
  id window = [webView_ windowScriptObject];
  [window callWebScriptMethod:@"onTrackEnded" withArguments:args];
}

- (void)dealloc { 
  [webView_ removeFromSuperview];
  [webView_ release];
  [url_ release];
  NSSplitView *split = (NSSplitView *)[content_ superview];
  [content_ removeFromSuperview];
  [split adjustSubviews];
  [content_ autorelease];
  [super dealloc]; 
}

- (NSView *)content {
  return content_;
}

+ (NSString *)webScriptNameForKey:(const char *)name {
  return [NSString stringWithUTF8String:name];
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
  return NO;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
  return NO;
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector {
  NSString *s = NSStringFromSelector(aSelector);
  s = [s stringByReplacingOccurrencesOfString:@":" withString:@"_"];
  return s;
}

- (void)hide { 
  NSSplitView *split = (NSSplitView *)[content_ superview];
  [content_ removeFromSuperview];
  [split adjustSubviews];
}

- (void)showSize:(int)size isVertical:(BOOL)isVertical {
  [self hide];
  NSSplitView *split;
  AppDelegate *delegate = (AppDelegate *)[[NSApplication sharedApplication] delegate];
  if (isVertical) 
    split = [delegate contentVerticalSplit];
  else
    split = [delegate contentHorizontalSplit];
  CGRect frame = NSZeroRect;
  CGRect firstFrame = [[split.subviews objectAtIndex:0] frame];
  if (isVertical) {
    frame.size.height = split.frame.size.height;
    frame.size.width = size;
    firstFrame.size.width -= size;
    frame.size.height = firstFrame.size.height;
  } else { 
    frame.size.height = size;
    frame.size.width = firstFrame.size.width;
    firstFrame.size.height -= size;
  }
  content_.frame = frame;
  [[split.subviews objectAtIndex:0] setFrame:firstFrame];
  [split addSubview:content_];
}

- (void)log:(NSString *)something {
  DEBUG(@"%@", something);
}

- (void)hideTrackTable {

}
@end
