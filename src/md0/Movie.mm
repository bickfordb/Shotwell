#include <sys/time.h>

#import "md0/AV.h"
#import "md0/CoreAudioSink.h"
#import "md0/LibAVSource.h"
#import "md0/Log.h"
#import "md0/Movie.h"
#import "md0/NSObjectPThread.h"
#import "md0/RAOP.h"


@implementation Movie
@synthesize url = url_;
@synthesize sink = sink_;
@synthesize source = source_;

- (id)initWithURL:(NSString *)url {
  self = [super init];
  if (self) { 
    self.url = url;
    self.source = [[((LibAVSource *)[LibAVSource alloc]) initWithURL:url_] autorelease];
    self.sink = [[((CoreAudioSink *)[CoreAudioSink alloc]) initWithSource:source_] autorelease]; 
  }
  return self;
}

- (void)dealloc { 
  self.url = nil;
  [source_ stop];
  [sink_ stop];
  [sink_ release];
  [source_ release];
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
  [source_ stop];
  [sink_ stop];
}

- (void)start { 
  [source_ start];
  [sink_ start];
}
@end
