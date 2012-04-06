/*
#ifndef _COVER_ART_H_
#define _COVER_ART_H_

#include <string>
#include <leveldb/db.h>
#include <vector>
#include <tr1/tuple>
#include "md0/lib/loop.h"
#include <event2/event.h>

using namespace std;
using namespace std::tr1;
namespace md0 { 

typedef void (*OnCoverArtData)(
    void *context, 
    const string &artist,
    const string &album,
    const string &path);

class CoverArt : public Loop { 
  vector<tuple<string, string, OnCoverArtData, void *> > queries_;
  string library_path_;
  struct event *poll_event_;

  public:
   CoverArt(const string &db_path);
   ~CoverArt();
   void OnTimeOutCallback(int fd, short x, void *ctx);
   void Get(const std::string &artist, const std::string &album, 
            OnCoverArtData callback, void *context);
};
}

#endif
*/
