#import "Tag.h"
#import "Track.h"
#import "Util.h"

#include <unicode/utypes.h>   /* Basic ICU data types */
#include <unicode/ucnv.h>     /* C   Converter API    */
#include <unicode/ustring.h>  /* some more string fcns*/
#include <unicode/uchar.h>    /* char names           */
#include <unicode/uloc.h>
#include <unicode/unistr.h>
#include <unicode/bytestream.h>
#include <sys/time.h>

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
}

static NSDictionary *tagKeyToTrackKey = @{
    @"artist": kTrackArtist,
    @"album": kTrackAlbum,
    @"year": kTrackYear,
    @"title": kTrackTitle,
    @"date": kTrackYear,
    @"track": kTrackNumber,
    @"genre": kTrackGenre};

static NSString *ToUTF8(const char *src) {
  UErrorCode err = U_ZERO_ERROR;
  int32_t sig_len = 0;
  const char *src_encoding = ucnv_detectUnicodeSignature(src, strlen(src), &sig_len, &err);
  if (err) {
    return @"?";
  }
  UnicodeString us(src, strlen(src), src_encoding);
  std::string dst;
  StringByteSink<std::string> sbs(&dst);
  us.toUTF8(sbs);
  return [NSString stringWithUTF8String:dst.c_str()];
}

/*
ignoreExtensions: Skip indexing the following extensions to save time since they never have useful info/can be large
*/

static NSArray *ignoreExtensions = @[@".jpg", @".nfo", @".sfv", @".torrent",
               @".m3u", @".diz", @".rtf", @".ds_store", @".txt", @".m3u8", @".htm", @".url",
               @".html", @".atom", @".rss", @".crdownload", @".dmg", @".zip", @".rar",
               @".jpeg", @".part", @".ini", @".", @".log", @".db", @".cue", @".gif", @".png"];

@interface TagPrivates
@end
@implementation TagPrivates
+ (void)initialize {

}
@end

static bool tagInited = false;
static NSString *initLock = @"";

static void TagInit() {
  @synchronized(initLock) {
    if (tagInited)
      return;
    //av_log_set_level(AV_LOG_QUIET);
    avcodec_register_all();
    avfilter_register_all();
    av_register_all();
    avformat_network_init();
    tagInited = true;
  }
}

NSMutableDictionary *TagRead(NSString *path, NSError **error) {
  TagInit();
  NSMutableDictionary *track = [NSMutableDictionary dictionary];
  *error = nil;
  track[kTrackPath] = path;
  AVFormatContext *c = NULL;
  AVDictionaryEntry *tag = NULL;
  int audioStreamIndex = -1;

  if (!path || !path.length) {
    *error = [NSError errorWithDomain:@"tag" code:-1 userInfo:nil];
    goto done;
  }

  for (NSString *ext in ignoreExtensions) {
    if ([path hasSuffix:ext]) {
      *error = [NSError errorWithDomain:@"tag" code:-10 userInfo:nil];
      goto done;
    }
  }

  if (!path || !Exists(path)) {
    *error = [NSError errorWithDomain:@"tag" code:-2 userInfo:nil];
    goto done;
  }
  if (avformat_open_input(&c, path.UTF8String, NULL, NULL) < 0) {
    *error = [NSError errorWithDomain:@"tag" code:-3 userInfo:nil];
    goto done;
  }
  if (avformat_find_stream_info(c, NULL) < 0) {
    *error = [NSError errorWithDomain:@"tag" code:-4 userInfo:nil];
    goto done;
  }

  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      audioStreamIndex = i;
      break;
    }
  }

  if (audioStreamIndex >= 0) {
    UInt64 d = ((c->streams[audioStreamIndex]->duration * c->streams[audioStreamIndex]->time_base.num) / c->streams[audioStreamIndex]->time_base.den) * 1000000;
    track[kTrackDuration] = @(d);
  }
  track[kTrackIsVideo] = @NO;
  track[kTrackIsAudio] = @NO;
  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
      track[kTrackIsVideo] = @YES;
      continue;
    }
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      track[kTrackIsAudio] = @YES;
      continue;
    }
  }

  while((tag = av_dict_get(c->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
    NSString *tagKey = [NSString stringWithUTF8String:tag->key];
    NSString *trackKey = [tagKeyToTrackKey objectForKey:tagKey];
    if (trackKey) {
      NSString *value = ToUTF8(tag->value);
      if (value && value.length > 0) {
        track[trackKey] = value;
      }
    }
  }
done:
  if (c) avformat_close_input(&c);
  if (c) avformat_free_context(c);
  if (*error) {
    return nil;
  } else {
    return track;
  }
}

