#ifndef _DAEMON_H_
#define _DAEMON_H_

#include "library.h"
#include <event2/event.h>
#include <event2/http.h>
#include <pthread.h>
#include <string>
#include <tr1/memory>
#include <tr1/tuple>
#include <vector>
#include <pcrecpp.h>
#include <event2/buffer.h>

using namespace std;
using namespace std::tr1;

typedef string Address;
typedef int Port;
typedef tuple<Address, Port> Host;

const int kDefaultPort = 6226;

class Request { 
  private:
  struct evhttp_uri *uri_;
  struct evhttp_request *req_;

  public: 
  Request(struct evhttp_request *req) :
    req_(req),
    uri_(evhttp_uri_parse(evhttp_request_get_uri(req))) { };
  ~Request() { 
    evhttp_uri_free(uri_); 
  };
  const string Path() { 
    const char *p0 = evhttp_uri_get_path(uri_);
    size_t sz = 0;
    char *p = evhttp_uridecode(p0, 1, &sz);
    string s(p, sz);
    free(p);
    return s;
  };

  void Respond(int status, const string &msg, const string&body) {
    struct evbuffer *buffer = evbuffer_new();
    evbuffer_add_printf(buffer, "%s", body.c_str());  
    evhttp_send_reply(req_, status, msg.c_str(), buffer);
    evbuffer_free(buffer);
  };
  void Respond(int status, const string &msg, struct evbuffer *buffer) {
    evhttp_send_reply(req_, status, msg.c_str(), buffer);
  };
  void RespondNotFound() { 
    Respond(404, "Not Found", ""); 
  }

  void AddResponseHeader(const string &k, const string &v) { 
    struct evkeyvalq *headers = evhttp_request_get_output_headers(req_);  
    evhttp_add_header(headers, k.c_str(), v.c_str());
  };
};

class Daemon {
private:
  shared_ptr<Library> library_;
  vector<tuple<string, int> > listen_to_;
  pthread_t main_thread_;
  bool running_;
  struct evhttp *event_http_;
  struct event_base *event_base_;
  pcrecpp::RE root_pat_;
  pcrecpp::RE track_pat_;
  pcrecpp::RE library_pat_;

public: 
  bool HandleHomeRequest(Request *r);
  bool HandleLibraryRequest(Request *r);
  bool HandleTrackRequest(Request *r);
  void HandleRequest(Request *r);
  void RespondNotFound(Request *r);
  Daemon(const vector<Host> &listen_to, shared_ptr<Library> library);
  ~Daemon();
  void Start();
  void Stop();
  void RunMainThread(); 
};

#endif
