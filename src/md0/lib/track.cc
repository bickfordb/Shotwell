#include <stdio.h>
#include <string>
#include <sys/stat.h>
#include "av.h"
#include "track.pb.h"
#include "track.h"
#include "log.h"

#include <unicode/utypes.h>   /* Basic ICU data types */
#include <unicode/ucnv.h>     /* C   Converter API    */
#include <unicode/ustring.h>  /* some more string fcns*/
#include <unicode/uchar.h>    /* char names           */
#include <unicode/uloc.h>
#include <unicode/unistr.h>
#include <unicode/bytestream.h>

using namespace std;

namespace {
string ToUTF8(const char *src);
string ToUTF8(const char *src) {
  UErrorCode err = U_ZERO_ERROR;
  int32_t sig_len = 0;
  const char *src_encoding = ucnv_detectUnicodeSignature(src, strlen(src), &sig_len, &err);
  if (err) { 
    return "?";
  }
  UnicodeString us(src, strlen(src), src_encoding);
  string dst;
  StringByteSink<string> sbs(&dst);
  us.toUTF8(sbs);
  return dst;
}
}

namespace md0 {

void Track::Init() {
  AVInit(); 
}

int Track::ReadTag(const string &url) {
  int ret = 0;
  AVFormatContext *c = NULL;
  struct stat st;
  AVDictionary *d = NULL;
  AVDictionaryEntry *tag = NULL;
  int err;
  int audio_stream_idx = -1;

  if (url.length() <= 0) {
    return -1;
  }
  set_url(ToUTF8(url.c_str()));

  memset(&st, 0, sizeof(st));
  if (stat(url.c_str(), &st) < 0) {
    ret = -2;
    goto done;
  }
  AVInit();
  if (avformat_open_input(&c, url.c_str(), NULL, NULL) < 0) {
    ret = -3;
    goto done;
  }
  if (avformat_find_stream_info(c, NULL) < 0) {
    ret = -4;
    goto done;
  }

  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      audio_stream_idx = i;
      break;
    }
  }

  if (audio_stream_idx >= 0) {
    int64_t d = ((c->streams[audio_stream_idx]->duration * c->streams[audio_stream_idx]->time_base.num) / c->streams[audio_stream_idx]->time_base.den) * 1000000;

    set_duration(d);
  }

  set_is_video(false);
  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
      set_is_video(true);
      break;
    }
  } 

  while((tag = av_dict_get(c->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
    string value(ToUTF8(tag->value));
    string key(tag->key);
    if (key == "artist")
      set_artist(value);
    else if (key == "album")
      set_album(value);
    else if (key == "year")
      set_year(value);
    else if (key == "title")
      set_title(value);
    else if (key == "genre")
      set_genre(value);
    else if (key == "date")
      set_year(value);
    else if (key == "track")
      set_track_number(value);
  }


done:
  if (c)
    avformat_close_input(&c);
  if (c)
    avformat_free_context(c);
  return ret;
}
}

