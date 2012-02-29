#include <stdio.h>
#include <string>
#include <sys/stat.h>
#include "av.h"
#include "track.pb.h"
#include "track.h"

int ReadTag(Track *t) {
  AVInit();
  std::string path = t->path();
  if (path.length() <= 0) 
    return -1;
  struct stat st;
  memset(&st, 0, sizeof(st));
  if (stat(path.c_str(), &st) < 0)
   return -1;
  AVFormatContext *c = NULL;
  int err = avformat_open_input(&c, path.c_str(), NULL, NULL);
  if (err != 0) {
    if (c != NULL) 
    avformat_free_context(c);
    return err;
  }
  if (avformat_find_stream_info(c, NULL) != 0) {
    avformat_close_input(&c);
    if (c != NULL)
      avformat_free_context(c);
    return -3;
  }
  AVDictionary *d = c->metadata;
  AVDictionaryEntry *tag = NULL;
  while((tag = av_dict_get(c->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
    if (strcmp(tag->key, "artist") == 0)
      t->set_artist(tag->value);
    else if (strcmp(tag->key, "album") == 0)
      t->set_album(tag->value);
    else if (strcmp(tag->key, "year") == 0)
      t->set_year(tag->value);
    else if (strcmp(tag->key, "title") == 0)
      t->set_title(tag->value);
    else if (strcmp(tag->key, "genre") == 0)
      t->set_genre(tag->value);
    else if (strcmp(tag->key, "date") == 0)
      t->set_year(tag->value);
    else if (strcmp(tag->key, "artist") == 0)
      t->set_artist(tag->value);
    else if (strcmp(tag->key, "track") == 0)
      t->set_track_number(tag->value);
  }
  avformat_close_input(&c);
  if (c != NULL)
    avformat_free_context(c);
  return 0;
}


