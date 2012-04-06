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
NSString * const kCreatedAt = @"created_at";
NSString * const kDuration = @"duration";
NSString * const kGenre = @"genre";
NSString * const kID = @"id";
NSString * const kIsVideo = @"is_video";
NSString * const kLastPlayedAt = @"last_played_at";
NSString * const kTitle = @"title";
NSString * const kTrackNumber = @"track_number";
NSString * const kURL = @"url";
NSString * const kUpdatedAt = @"updated_at"; 
NSString * const kYear = @"year";

void Init() {
  AVInit(); 
}

int ReadTag(NSString *url, NSMutableDictionary *aTrack) {
  int ret = 0;
  AVFormatContext *c = NULL;
  struct stat st;
  AVDictionary *d = NULL;
  AVDictionaryEntry *tag = NULL;
  int audioStreamIndex = -1;

  NSDictionary *tagKeyToTrackKey = [NSDictionary dictionaryWithObjectsAndKeys:
    @"artist", kArtist,
    @"album", kAlbum,
    @"year", kYear,
    @"title", kTitle,
    @"date", kYear,
    @"track", kTrackNumber,
    nil];
  memset(&st, 0, sizeof(st));
  if (stat(url.UTF8String, &st) < 0) {
    ret = -2;
    goto done;
  }
  AVInit();
  if (avformat_open_input(&c, url.UTF8String, NULL, NULL) < 0) {
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
    [aTrack setObject:[NSNumber numberWithLong:d] forKey:kDuration];
  }
  [aTrack setObject:[NSNumber numberWithBool:NO] forKey:kIsVideo];
  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
      [aTrack setObject:[NSNumber numberWithBool:YES] forKey:kIsVideo];
      break;
    }
  } 


  while((tag = av_dict_get(c->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
    NSString *tagKey = [NSString stringWithUTF8String:tag->key];
    NSString *trackKey = [tagKeyToTrackKey objectForKey:tagKey];
    if (trackKey) 
      [aTrack setObject:ToUTF8(tag->value) forKey:trackKey];
  }
done:
  if (c)
    avformat_close_input(&c);
  if (c)
    avformat_free_context(c);
  return ret;
}

