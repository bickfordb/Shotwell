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
NSString * const kCoverArtURL = @"coverArtURL";
NSString * const kDuration = @"duration";
NSString * const kIsCoverArtChecked = @"isCoverArtChecked";
NSString * const kGenre = @"genre";
NSString * const kID = @"id";
NSString * const kIsAudio = @"isAudio";
NSString * const kIsVideo = @"isVideo";
NSString * const kLastPlayedAt = @"lastPlayedAt";
NSString * const kPublisher = @"publisher";
NSString * const kTitle = @"title";
NSString * const kTrackNumber = @"trackNumber";
NSString * const kURL = @"url";
NSString * const kUpdatedAt = @"updatedAt"; 
NSString * const kYear = @"year";

NSArray *allTrackKeys = nil;
static NSDictionary *tagKeyToTrackKey; 
static NSArray *mediaExtensions = nil;

@implementation Track
@synthesize album = album_;
@synthesize artist = artist_;
@synthesize coverArtURL = coverArtURL_;
@synthesize createdAt = createdAt_;
@synthesize duration = duration_;
@synthesize isCoverArtChecked = isCoverArtChecked_;
@synthesize genre = genre_;
@synthesize id = id_;
@synthesize isAudio = isAudio_;
@synthesize isVideo = isVideo_;
@synthesize lastPlayedAt = lastPlayedAt_;
@synthesize title = title_;
@synthesize publisher = publisher_;
@synthesize trackNumber = trackNumber_;
@synthesize updatedAt = updatedAt_;
@synthesize url = url_;
@synthesize year = year_;

- (void)dealloc { 
  [album_ release];
  [artist_ release];
  [coverArtURL_ release];
  [duration_ release];
  [genre_ release];
  [isCoverArtChecked_ release];
  [id_ release];
  [isAudio_ release];
  [isVideo_ release];
  [lastPlayedAt_ release];
  [publisher_ release];
  [title_ release];
  [trackNumber_ release];
  [updatedAt_ release];
  [url_ release];
  [year_ release];
  [super dealloc];
}


+ (void)initialize {
  av_log_set_level(AV_LOG_QUIET);
  avcodec_register_all();
  avfilter_register_all();
  av_register_all();
  avformat_network_init();
  mediaExtensions = [[NSArray arrayWithObjects:@".mp3", @".ogg", @".m4a", @".aac", @".avi", @".mp4", @".fla", @".flc", @".mov", @".m4a", @".mkv", @".mpg", nil] retain];

  allTrackKeys = [[NSArray arrayWithObjects:
    kAlbum,
    kArtist,
    kCoverArtURL,
    kCreatedAt,
    kDuration,
    kIsCoverArtChecked,
    kGenre,
    kID, 
    kIsAudio,
    kIsVideo,
    kLastPlayedAt,
    kPublisher,
    kTitle,
    kTrackNumber,
    kURL,
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

- (BOOL)isEqual:(id)other {
  if ([other isKindOfClass:[Track class]]) {
    Track *other0 = (Track *)other;
    return [id_ longLongValue] == [other0->id_ longLongValue];
  } else { 
    return NO;
  }
}

- (NSUInteger)hash {
  return [id_ hash];
}

- (bool)isLocalMediaURL {
  NSString *s = self.url;
  s = s.lowercaseString;
  if (!s || !s.length)
    return false;
  for (NSString *ext in mediaExtensions) {
    if ([s hasSuffix:ext]) 
      return true;
  }
  return false;
}

- (int)readTag {
  int ret = 0;
  AVFormatContext *c = NULL;
  struct stat st;
  AVDictionary *d = NULL;
  AVDictionaryEntry *tag = NULL;
  int audioStreamIndex = -1;
  int format_ret = -1;

  if (!url_ || !url_.length) 
    return -1;

  memset(&st, 0, sizeof(st));
  if (stat(url_.UTF8String, &st) < 0) {
    ret = -2;
    goto done;
  }
  if (avformat_open_input(&c, url_.UTF8String, NULL, NULL) < 0) {
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
  NSDictionary *data = [self dictionaryWithValuesForKeys:allTrackKeys];
  return [data getJSON];
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
