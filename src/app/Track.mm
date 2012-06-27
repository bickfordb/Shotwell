#include <stdio.h>
#include <string>
#include <sys/stat.h>

#include <unicode/utypes.h>   /* Basic ICU data types */
#include <unicode/ucnv.h>     /* C   Converter API    */
#include <unicode/ustring.h>  /* some more string fcns*/
#include <unicode/uchar.h>    /* char names           */
#include <unicode/uloc.h>
#include <unicode/unistr.h>
#include <unicode/bytestream.h>

#import "app/JSON.h"
#include <objc/runtime.h>

#import "app/Library.h"
#import "app/Track.h"
#import "app/Log.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
}

typedef enum {
  IsVideoTrackFlag = 1 << 0,
  IsAudioTrackFlag = 1 << 1,
  CoverArtChecked = 1 << 2
  } TrackFlags;

using namespace std;

static Class trackClass;

static NSString *ToUTF8(const char *src) {
  UErrorCode err = U_ZERO_ERROR;
  int32_t sig_len = 0;
  const char *src_encoding = ucnv_detectUnicodeSignature(src, strlen(src), &sig_len, &err);
  if (err) {
    return @"?";
  }
  UnicodeString us(src, strlen(src), src_encoding);
  string dst;
  StringByteSink<string> sbs(&dst);
  us.toUTF8(sbs);
  return [NSString stringWithUTF8String:dst.c_str()];
}

NSString * const kAlbum = @"album";
NSString * const kArtist = @"artist";
NSString * const kCreatedAt = @"createdAt";
NSString * const kCoverArtID = @"coverArtID";
NSString * const kDuration = @"duration";
NSString * const kIsCoverArtChecked = @"isCoverArtChecked";
NSString * const kGenre = @"genre";
NSString * const kID = @"id";
NSString * const kIsAudio = @"isAudio";
NSString * const kIsVideo = @"isVideo";
NSString * const kLastPlayedAt = @"lastPlayedAt";
NSString * const kPath = @"path";
NSString * const kPublisher = @"publisher";
NSString * const kTitle = @"title";
NSString * const kTrackNumber = @"trackNumber";
NSString * const kURL = @"url";
NSString * const kUpdatedAt = @"updatedAt";
NSString * const kYear = @"year";

NSArray *allTrackKeys = nil;
static NSDictionary *tagKeyToTrackKey;
static NSArray *mediaExtensions = nil;
static NSArray *ignoreExtensions = nil;

@implementation Track
@synthesize album = album_;
@synthesize artist = artist_;
@synthesize coverArtID = coverArtID_;
@synthesize createdAt = createdAt_;
@synthesize duration = duration_;
@synthesize library = library_;
@synthesize isCoverArtChecked = isCoverArtChecked_;
@synthesize genre = genre_;
@synthesize isAudio = isAudio_;
@synthesize isVideo = isVideo_;
@synthesize lastPlayedAt = lastPlayedAt_;
@synthesize path = path_;
@synthesize title = title_;
@synthesize publisher = publisher_;
@synthesize trackNumber = trackNumber_;
@synthesize updatedAt = updatedAt_;
@synthesize year = year_;

- (NSURL *)url {
  return [library_ urlForTrack:self];
}

- (NSURL *)coverArtURL {
  return [library_ coverArtURLForTrack:self];
}

- (void)dealloc {
  [album_ release];
  [artist_ release];
  [coverArtID_ release];
  [createdAt_ release];
  [duration_ release];
  [genre_ release];
  [isCoverArtChecked_ release];
  [id_ release];
  [isAudio_ release];
  [isVideo_ release];
  [lastPlayedAt_ release];
  [library_ release];
  [path_ release];
  [publisher_ release];
  [title_ release];
  [trackNumber_ release];
  [updatedAt_ release];
  [year_ release];
  [super dealloc];
}


+ (void)initialize {
  trackClass = [Track class];
  av_log_set_level(AV_LOG_QUIET);
  avcodec_register_all();
  avfilter_register_all();
  av_register_all();
  avformat_network_init();
  mediaExtensions = [[NSArray arrayWithObjects:@".mp3", @".ogg", @".m4a", @".aac", @".avi", @".mp4", @".fla", @".flc", @".mov", @".m4a", @".mkv", @".mpg", nil] retain];
  ignoreExtensions = [[NSArray arrayWithObjects:@".jpg", @".nfo", @".sfv",
                   @".torrent", @".m3u", @".diz", @".rtf", @".ds_store", @".txt", @".m3u8",
                   @".htm", @".url", @".html", @".atom", @".rss", @".crdownload", @".dmg",
                   @".zip", @".rar", @".jpeg", @".part", @".ini", @".", @".log", @".db",
                   @".cue", @".gif", @".png", nil] retain];

  allTrackKeys = [[NSArray arrayWithObjects:
    kAlbum,
    kArtist,
    kCoverArtID,
    kCreatedAt,
    kDuration,
    kGenre,
    kID,
    kIsAudio,
    kIsCoverArtChecked,
    kIsVideo,
    kLastPlayedAt,
    kPath,
    kPublisher,
    kTitle,
    kTrackNumber,
    kUpdatedAt,
    kYear,
    nil] retain];
  tagKeyToTrackKey = [[NSDictionary dictionaryWithObjectsAndKeys:
    kArtist, @"artist",
    kAlbum, @"album",
    kYear, @"year",
    kTitle, @"title",
    kYear, @"date",
    kGenre, @"genre",
    kTrackNumber, @"track", nil] retain];
}

- (NSString *)description {
  NSMutableString *ret = [NSMutableString string];
  [ret appendString:@"{"];
  int i = 0;
  for (NSString *key in allTrackKeys) {
    if (i != 0) {
      [ret appendString:@", "];
    }
    [ret appendFormat:@"%@: %@", key, [self valueForKeyPath:key]];
    i += 1;
  }
  [ret appendString:@"}"];
  return ret;
}

- (void)setId:(NSNumber *)anID {
  @synchronized(self) {
    NSNumber *t = id_;
    id_ = [anID retain];
    [t release];
  }
  idCache_ = [anID longLongValue];
}

- (NSNumber *)id {
  return id_;
}


- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  } else if (!other) {
    return NO;
  } else if ((object_getClass(other) == trackClass) || [other isKindOfClass:trackClass]) {
    Track *other0 = (Track *)other;
    return idCache_ == other0->idCache_;
  } else {
    return NO;
  }
}

- (NSUInteger)hash {
  return (NSUInteger)[id_ longLongValue];
}

- (int)readTag {
  int ret = 0;
  AVFormatContext *c = NULL;
  struct stat st;
  AVDictionaryEntry *tag = NULL;
  int audioStreamIndex = -1;
  NSString *s;

  if (!path_ || !path_.length)
    return -1;

  for (NSString *ext in ignoreExtensions) {
    if ([path_ hasSuffix:ext]) {
      return -1;
    }
  }

  memset(&st, 0, sizeof(st));
  if (stat(self.url.path.UTF8String, &st) < 0) {
    ret = -2;
    goto done;
  }
  s = self.url.isFileURL ? self.path : self.url.absoluteString;
  if (avformat_open_input(&c, s.UTF8String, NULL, NULL) < 0) {
    ret = -3;
    goto done;
  }
  if (avformat_find_stream_info(c, NULL) < 0) {
    ret = -4;
    goto done;
  }

  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      audioStreamIndex = i;
      break;
    }
  }

  if (audioStreamIndex >= 0) {
    int64_t d = ((c->streams[audioStreamIndex]->duration * c->streams[audioStreamIndex]->time_base.num) / c->streams[audioStreamIndex]->time_base.den) * 1000000;
    self.duration = [NSNumber numberWithLongLong:d];
  }
  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
      self.isVideo = [NSNumber numberWithBool:YES];
      continue;
    }
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      self.isAudio = [NSNumber numberWithBool:YES];
      continue;
    }
  }

  while((tag = av_dict_get(c->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
    NSString *tagKey = [NSString stringWithUTF8String:tag->key];
    NSString *trackKey = [tagKeyToTrackKey objectForKey:tagKey];
    if (trackKey) {
      NSString *value = ToUTF8(tag->value);
      if (value && value.length > 0) {
        [self setValue:value forKey:trackKey];
      }
    }
  }
done:
  if (c)
    avformat_close_input(&c);
  if (c)
    avformat_free_context(c);
  return ret;
}

- (bool)isAudioOrVideo {
  if (self.isVideo) {
    return (bool)(self.isVideo.boolValue ? true : false);
  } else if (self.isAudio) {
    return (bool)(self.isAudio.boolValue ? true : false);
  }
  return false;
}

- (json_t *)getJSON {
  NSMutableDictionary *data = [NSMutableDictionary dictionary];
  for (NSString *key in allTrackKeys) {
    if (key == kURL)
      continue;
    id val = [self valueForKey:key];
    if (!val)
      continue;
    [data setValue:val forKey:key];
  }
  return [data getJSON];
}
+ (Track *)fromJSON:(NSDictionary *)json {
  Track *t = [[[Track alloc] init] autorelease];
  t.album = [json valueForKey:kAlbum];
  t.artist = [json valueForKey:kArtist];
  t.coverArtID = [json valueForKey:kCoverArtID];
  t.duration = [json valueForKey:kDuration];
  t.genre = [json valueForKey:kGenre];
  t.id = [json valueForKey:kID];
  t.isAudio = [json valueForKey:kIsAudio];
  t.isCoverArtChecked = [json valueForKey:kIsCoverArtChecked];
  t.isVideo = [json valueForKey:kIsVideo];
  t.lastPlayedAt = [json valueForKey:kLastPlayedAt];
  t.path = [json valueForKey:kPath];
  t.publisher = [json valueForKey:kPublisher];
  t.title = [json valueForKey:kTitle];
  t.trackNumber = [json valueForKey:kTrackNumber];
  t.updatedAt = [json valueForKey:kUpdatedAt];
  t.year = [json valueForKey:kYear];
  return t;
}

+ (NSString *)webScriptNameForKey:(const char *)name {
  return [NSString stringWithUTF8String:name];
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
  return YES;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector {
  return NO;
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector {
  NSString *s = NSStringFromSelector(aSelector);
  return [s stringByReplacingOccurrencesOfString:@":" withString:@"_"];
}

- (void)finalizeForWebScript {
}

@end
