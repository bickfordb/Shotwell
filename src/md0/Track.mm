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

#import "md0/AV.h"
#import "md0/JSON.h"
#import "md0/Track.h"
#import "md0/Log.h"

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
NSString * const kGenre = @"genre";
NSString * const kID = @"id";
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

@implementation Track
@synthesize album = album_;
@synthesize artist = artist_;
@synthesize coverArtURL = coverArtURL_;
@synthesize createdAt = createdAt_;
@synthesize duration = duration_;
@synthesize genre = genre_;
@synthesize id = id_;
@synthesize isVideo = isVideo_;
@synthesize lastPlayedAt = lastPlayedAt_;
@synthesize title = title_;
@synthesize publisher = publisher_;
@synthesize trackNumber = trackNumber_;
@synthesize updatedAt = updatedAt_;
@synthesize url = url_;
@synthesize year = year_;

- (void)dealloc { 
  self.album = nil;
  self.artist = nil;
  self.coverArtURL = nil;
  self.duration = nil;
  self.genre = nil;
  self.id = nil;
  self.isVideo = nil;
  self.lastPlayedAt = nil;
  self.publisher = nil;
  self.title = nil;
  self.trackNumber = nil;
  self.updatedAt = nil;
  self.url = nil;
  self.year = nil;
  [super dealloc];
}

+ (void)initialize {
  AVInit(); 
  allTrackKeys = [[NSArray arrayWithObjects:
    kAlbum,
    kArtist,
    kCoverArtURL,
    kCreatedAt,
    kDuration,
    kGenre,
    kID, 
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

- (int)readTag {
  int ret = 0;
  AVFormatContext *c = NULL;
  struct stat st;
  AVDictionary *d = NULL;
  AVDictionaryEntry *tag = NULL;
  int audioStreamIndex = -1;

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
      break;
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
