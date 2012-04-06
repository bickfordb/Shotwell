/*
#include "md0/lib/cover_art.h"
#include "md0/lib/log.h"

using namespace std;

namespace md0 { 
CoverArt::CoverArt(const string &path) 
  leveldb::Options opts;
  opts.create_if_missing = true;
  opts.error_if_exists = false;
  leveldb::Status st = leveldb::DB::Open(opts, path.c_str(), &db_);
  struct timeval timeout_interval;
  poll_event_ = evtimer_new(event_base(), OnTimeOutCallback, this);
  timeout_interval.tv_sec = 0;
  timeout_interval.tv_usec = 10000;
  evtimer_add(poll_event_, timeout_interval);
  Start();
}

CoverArt::~CoverArt() {
  Stop();
  evtimer_del(poll_event_);
  if (db_) {
    delete db_;
  }
}

void CoverArt::Get(const string &artist, const string &album) {
  Lock();
  queries_.push_back(make_tuple(artist, album));
  Unlock();
}
   
void CoverArt::OnTimeOutCallback(int fd, short x, void *ctx) {
  INFO("on cover art");
}
}
*/
