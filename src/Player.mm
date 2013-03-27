#import "CAMovie.h"
#import "AVFile.h"
#import "Library.h"
#import "Log.h"
#import "Player.h"
#import "Track.h"
#import "Util.h"

static Player *sharedPlayer = nil;
static NSArray *movieKeys = @[@"isPaused", @"isDone", @"volume", @"duration", @"elapsed", @"isSeeking", @"outputDevice"];

@implementation Player {
  CAMovie *movie_;
  NSMutableDictionary *track_;
  BOOL isPaused_;
  BOOL isDone_;
  BOOL isSeeking_;
  double volume_;
  int64_t duration;
  int64_t elapsed;
  NSObject *lock_;
}

@synthesize track = track_;
@synthesize isPaused = isPaused_;
@synthesize isDone = isDone_;
@synthesize volume = volume_;
@synthesize duration = duration_;
@synthesize elapsed = elapsed_;
@synthesize isSeeking = isSeeking_;

- (double)volume {
  return volume_;
}

- (void)setVolume:(double)v {
  if (v == volume_) return;
  [self willChangeValueForKey:@"volume"];
  [[NSUserDefaults standardUserDefaults] setObject:@(v) forKey:@"volume"];
  volume_ = v;
  movie_.volume = v;
  [self didChangeValueForKey:@"volume"];
}

- (id)init {
  self = [super init];
  if (self) {
    lock_ = [[NSObject alloc] init];
    volume_ = 0.5;
    NSNumber *volume = [[NSUserDefaults standardUserDefaults] objectForKey:@"volume"];
    if (volume) {
      volume_ = volume.doubleValue;
    }
  }
  return self;
}

- (void)dealloc {
  for (id key in movieKeys) {
    [self unbind:key];
  }
  [track_ release];
  track_ = nil;
  [movie_ release];
  movie_ = nil;
  [lock_ release];
  [super dealloc];
}

- (void)playTrack:(NSMutableDictionary *)track {
    NSError *error = nil;
    self.track = track;
    if (movie_) {
     for (id key in movieKeys) {
       [self unbind:key];
     }
     [movie_ release];
     movie_ = nil;
    }
    self.duration = 0;
    self.elapsed = 0;

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
    movie_.volume = self.volume;

    for (id key in movieKeys) {
      id val = [movie_ valueForKey:key];
      [self setValue:val forKey:key];
      [self bind:key toObject:movie_ withKeyPath:key options:nil];
    }
    DEBUG(@"unpausing");
    movie_.isPaused = NO;
    DEBUG(@"updating track play date");
    self.track[kTrackLastPlayedAt] = [NSDate date];
    id trackID = self.track[kTrackID];
    Library *library = self.track[kTrackLibrary];
    library[trackID] = self.track;
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
