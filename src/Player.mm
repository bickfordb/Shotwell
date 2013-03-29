#import "CAMovie.h"
#import "AVFile.h"
#import "Library.h"
#import "Log.h"
#import "Player.h"
#import "Track.h"
#import "Util.h"

static Player *sharedPlayer = nil;
static NSArray *listenerKeys = @[@"volume", @"duration", @"elapsed", @"isSeeking", @"isDone", @"isPaused", @"outputDevice"];

@implementation Player {
  CAMovie *movie_;
  NSMutableDictionary *track_;
  NSObject *lock_;
  NSObject *playLock_;
}

@synthesize track = track_;

- (int64_t)elapsed {
  return movie_ ? movie_.elapsed : 0;
}

- (int64_t)duration {
  return movie_ ? movie_.duration : 0;
}

- (double)volume {
  if (movie_) {
    return movie_.volume;
  }
  NSNumber *volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"volume"];
  if (volume) {
    return volume.doubleValue;
  } else {
    return 0.5;
  }
}

- (void)setVolume:(double)v {
  [self willChangeValueForKey:@"volume"];
  [[NSUserDefaults standardUserDefaults] setObject:@(v) forKey:@"volume"];
  [self didChangeValueForKey:@"volume"];
}

- (id)init {
  self = [super init];
  if (self) {
    lock_ = [[NSObject alloc] init];
  }
  return self;
}

- (void)dealloc {
  [track_ release];
  track_ = nil;
  [movie_ release];
  movie_ = nil;
  [lock_ release];
  [super dealloc];
}

- (BOOL)isDone {
  return movie_ ? movie_.isDone : YES;
}

- (BOOL)isPaused {
  return movie_ ? movie_.isPaused : YES;
}

- (void)setIsPaused:(BOOL)isPaused {
  movie_.isPaused = isPaused;
}

- (void)playTrack:(NSMutableDictionary *)track {
  @synchronized(playLock_) {
    NSError *error = nil;
    [self willChangeValueForKey:@"track"];
    @synchronized (lock_) {
      [track_ release];
      track_ = [track retain];
    }
    [self didChangeValueForKey:@"track"];
    @synchronized(lock_) {
      if (movie_) {
        for (id key in listenerKeys) {
          [movie_ removeObserver:self forKeyPath:key context:listenerKeys];
        }
        [movie_ release];
        movie_ = nil;
      }
    }
    NSURL *url = track_[kTrackURL];
    if (!url)
      return;
    AVFile *file = [[[AVFile alloc] initWithURL:url error:&error] autorelease];
    if (error) {
      ERROR(@"unexpected error creating an av file: %@", error);
      return;
    }
    movie_ = [[CAMovie alloc] initWithAVFile:file error:&error];
    if (error) {
      ERROR(@"unexpected error creating CAMovie: %@", error);
      return;
    }
    NSNumber *volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"volume"];
    if (volume) {
      movie_.volume = volume.doubleValue;
    }

    for (id key in listenerKeys) {
      [self willChangeValueForKey:key];
      [self didChangeValueForKey:key];
    }
    for (id key in listenerKeys) {
      [movie_ addObserver:self forKeyPath:key options:NSKeyValueObservingOptionPrior context:listenerKeys];
    }
    movie_.isPaused = NO;
    self.track[kTrackLastPlayedAt] = [NSDate date];
    id trackID = self.track[kTrackID];
    Library *library = self.track[kTrackLibrary];
    library[trackID] = self.track;
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (context == listenerKeys) {
    NSNumber *isPrior = change[NSKeyValueChangeNotificationIsPriorKey];
    if (isPrior && isPrior.boolValue) {
      [self willChangeValueForKey:keyPath];
    } else {
      [self didChangeValueForKey:keyPath];
    }
  }
}

+ (Player *)shared {
  if (!sharedPlayer) {
    sharedPlayer = [[Player alloc] init];
  }
  return sharedPlayer;
}

- (void)seek:(int64_t)amt {
  [movie_ seek:amt];
}

- (NSDictionary *)outputDevices {
  return @{};
}

@end
