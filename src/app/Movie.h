#import <Cocoa/Cocoa.h>
#import "AudioSink.h"
#import "AudioSource.h"

@interface Movie : NSObject {
  NSString *url_;
  id <AudioSource> source_;
  id <AudioSink> sink_;
  double volume_;
}

@property (retain) NSString *url;
@property (retain) id <AudioSink> sink;
@property (retain) id <AudioSource> source;
@property double volume;
- (void)seek:(int64_t)usecs;
- (void)start;
- (void)stop;
- (bool)isSeeking;
- (AudioSourceState)state;
- (int64_t)elapsed;
- (int64_t)duration;
- (id)initWithURL:(NSString *)url address:(NSString *)address port:(uint16_t)port;
@end  
// vim: filetype=objcpp
