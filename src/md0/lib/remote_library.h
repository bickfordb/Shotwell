#ifndef _REMOTE_LIBRARY_H_
#define _REMOTE_LIBRARY_H_
#include <stdint.h>
#include <string>
#include <event2/event.h>

#include "md0/lib/library.h"

using namespace std;

namespace md0 {
class RemoteLibrary : public md0::Library { 
  string host_;
  pthread_mutex_t lock_;
  uint16_t port_;
  struct event_base *event_base_;
  long double last_updated_at_;
  bool started_;
  bool running_;
  vector<Track> tracks_;
  bool request_refresh_;
  static void *LoopCallback(void *rl) { 
    ((RemoteLibrary *)rl)->Loop();
    return NULL;
  };
  static void OnFetchResponseCallback(struct evhttp_request *req, void *context) {
    ((RemoteLibrary *)context)->OnFetchResponse(req);
  };
  void OnFetchResponse(struct evhttp_request *req);
  void Loop();
  void Lock();
  void Unlock();
  void Fetch();
 public:
  void GetAll(vector<Track> *tracks);
  int Count();
  RemoteLibrary(const string &host, uint16_t port);
  ~RemoteLibrary();
  long double last_update() { return last_updated_at_; };

};
}
#endif
