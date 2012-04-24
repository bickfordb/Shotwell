#include <sys/time.h>

#import "md0/AV.h"
#import "md0/CoreAudioSink.h"
#import "md0/LibAVSource.h"
#import "md0/Log.h"
#import "md0/Movie.h"
#import "md0/RAOP.h"
#import "md0/Signals.h"


@implementation Movie
@synthesize url = url_;
@synthesize sink = sink_;
@synthesize source = source_;

- (id)initWithURL:(NSString *)url address:(NSString *)address port:(uint16_t)port {
  self = [super init];

  if (self) { 
    self.url = url;
    self.source = [[((LibAVSource *)[LibAVSource alloc]) initWithURL:url_] autorelease];
    self.sink = address ? 
      [[[RAOPSink alloc] initWithAddress:address port:port source:self.source] autorelease]
      : [[((CoreAudioSink *)[CoreAudioSink alloc]) initWithSource:self.source] autorelease];
  }
  return self;
}

- (void)dealloc { 
  self.url = nil;
  self.source = nil;
  self.sink = nil;
  [super dealloc];
}

- (void)setVolume:(double)pct {
  if (pct < 0) 
    pct = 0;
  if (pct > 1.0)
    pct = 1.0;
  volume_ = pct;
  [sink_ setVolume:pct];
}

- (double)volume { 
  return volume_;
}

- (AudioSourceState)state { 
  return source_.state;
}

- (void)seek:(int64_t)usecs { 
  DEBUG(@"seek: %lld", usecs);
  [source_ seek:usecs];
  [sink_ flush];
}

- (bool)isSeeking { 
  return source_ && source_.isSeeking;
}

- (int64_t)duration { 
  return source_ ? source_.duration : 0; 
}

- (int64_t)elapsed { 
  return source_ ? source_.elapsed : 0;
}

- (void)stop { 
  IgnoreSigPIPE();
  [sink_ stop];
  [source_ stop];
}

- (void)start { 
  IgnoreSigPIPE();
  [sink_ start];
  [source_ start];
}
@end

