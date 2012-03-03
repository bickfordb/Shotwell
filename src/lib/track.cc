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

int ReadTag(const string &path, Track *t) {
  int ret = 0;
  AVFormatContext *c = NULL;
  struct stat st;
  AVDictionary *d = NULL;
  AVDictionaryEntry *tag = NULL;
  int err;


  if (path.length() <= 0) {
    return -1;
  }
  t->set_path(ToUTF8(path.c_str()));

  memset(&st, 0, sizeof(st));
  if (stat(path.c_str(), &st) < 0) {
    ret = -1;
    goto done;
  }
  AVInit();
  if (avformat_open_input(&c, path.c_str(), NULL, NULL) != 0) {
    ret = -1;
    goto done;
  }
  if (avformat_find_stream_info(c, NULL) != 0) {
    ret = -1;
    goto done;
  }
  while((tag = av_dict_get(c->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
    string value(ToUTF8(tag->value));
    string key(tag->key);
    if (key == "artist")
      t->set_artist(value);
    else if (key == "album")
      t->set_album(value);
    else if (key == "year")
      t->set_year(value);
    else if (key == "title")
      t->set_title(value);
    else if (key == "genre")
      t->set_genre(value);
    else if (key == "date")
      t->set_year(value);
    else if (key == "track")
      t->set_track_number(value);
  }
done:
  if (c)
    avformat_close_input(&c);
  if (c)
    avformat_free_context(c);
  return ret;
}


