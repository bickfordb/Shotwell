#import <Cocoa/Cocoa.h>
#import "AudioSink.h"
#import "AudioSource.h"

@interface Movie : NSObject {
  NSString *url_;
  double volume_;
}

@property (retain, atomic) NSString *url;
@property (retain, atomic) id <AudioSink> sink;
@property (retain, atomic) id <AudioSource> source;
@property double volume;
- (void)seek:(int64_t)usecs;
- (void)start;
- (void)stop;
- (bool)isSeeking;
- (AudioSourceState)state;
- (int64_t)elapsed;
- (int64_t)duration;
- (id)initWithURL:(NSString *)url;
@end  
// vim: filetype=objcpp
