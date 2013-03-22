#import "AudioSink.h"
#import "CoreAudioSink.h"
#import "LibAVSource.h"
#import "Library.h"
#import "Log.h"
#import "Player.h"
#import "Track.h"
#import "Util.h"

static Player *sharedPlayer = nil;
@implementation Player {
  id<AudioSink> audioSink_;
  id<AudioSource> audioSource_;
  NSMutableDictionary *track_;
}

@synthesize track = track_;

- (id)init {
  self = [super init];
  if (self) {
    audioSink_ = [[CoreAudioSink alloc] init];
  }
  return self;
}

- (void)playTrack:(NSMutableDictionary *)track {
  DEBUG(@"play track: %@", track);
  audioSink_.isPaused = NO;
  audioSink_.audioSource = [[[LibAVSource alloc] initWithURL:self.track[kTrackURL]] autorelease];
  self.track = track;
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

- (int64_t)elapsed {
  return [audioSink_ elapsed];
}

- (int64_t)duration {
  return [audioSink_ duration];
}

- (BOOL)isSeeking {
  return [audioSink_ isSeeking];
}

- (BOOL)isPlaying {
  return NO;
}

- (BOOL)isDone {
  return YES;
}

- (BOOL)isPaused {
  return audioSink_.isPaused;
}

- (void)setIsPaused:(BOOL)paused {
  audioSink_.isPaused = paused;
}

- (void)seek:(int64_t)amt {
  [audioSink_ seek:amt];
}

- (double)volume {
  return [audioSink_ volume];
}

- (void)setVolume:(double)volume {
  return [audioSink_ setVolume:volume];
}

- (void)setOutputDevice:(NSString *)deviceID {

}

- (NSString *)outputDevice {
  return @"";
}

- (NSDictionary *)outputDevices {
  return @{};
}

@end
