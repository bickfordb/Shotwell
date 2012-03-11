#include "daemon.h"
#include "log.h"
#include <pcrecpp.h>
#include <jansson.h>
#include <sys/utsname.h>
#include <sys/stat.h>
#include <fcntl.h>

static void *MainThread(void *ctx); 
static void OnRequest(evhttp_request *r, void *ctx); 
static void json_object_set_integer(json_t *o, const string &key, int val);
static void json_object_set_string(json_t *o, const string &key, const string &val);


static void OnRequest(evhttp_request *r, void *ctx) {
  Request r0(r); 
  ((Daemon *)ctx)->HandleRequest(&r0);
}

static void *MainThread(void *ctx) { 
  Daemon *d = (Daemon *)ctx;
  d->RunMainThread();
  return NULL;
}

bool Daemon::HandleHomeRequest(Request *r) { 
  if (!root_pat_.FullMatch(r->Path()))
    return false;
  r->AddResponseHeader("Content-Type", "application/json");
  json_t *obj = json_object();

  struct utsname uname_data;
  uname(&uname_data);
  json_object_set_string(obj, "name", uname_data.nodename);
  json_object_set_integer(obj, "total", library_->Count());
  char *body0 = json_dumps(obj, 0);
  json_decref(obj);
  string body(body0);
  free(body0);
  r->Respond(200, "OK", body);
  return true;
}

static void json_object_set_integer(json_t *o, const string &key, int val) {
  json_t *s = json_integer(val);
  json_object_set(o, key.c_str(), s); 
  json_decref(s);
}

static void json_object_set_string(json_t *o, const string &key, const string &val) {
  json_t *s = json_string(val.c_str());
  json_object_set(o, key.c_str(), s); 
  json_decref(s);
}

bool Daemon::HandleLibraryRequest(Request *r) {
  if (!library_pat_.FullMatch(r->Path()))
    return false;
  r->AddResponseHeader("Content-Type", "application/json");
  json_t *obj = json_object();
  json_t *tracks = json_array();
  shared_ptr<vector<shared_ptr<Track> > > all_tracks = library_->GetAll();
  for (vector<shared_ptr<Track > >::iterator i = all_tracks->begin(); i < all_tracks->end(); i++) {
    shared_ptr<Track> t = *i;
    json_t *tobj = json_object();
    json_object_set_string(tobj, "artist", t->artist());
    json_object_set_string(tobj, "album", t->album());
    json_object_set_string(tobj, "genre", t->genre());
    json_object_set_string(tobj, "title", t->title());
    json_object_set_string(tobj, "year", t->year());
    json_object_set_string(tobj, "track_number", t->track_number());
    json_object_set_string(tobj, "path", t->path());
    json_array_append(tracks, tobj);
    json_decref(tobj);
  }
  json_object_set(obj, "tracks", tracks);
  json_decref(tracks);
  char *body0 = json_dumps(obj, 0);
  json_decref(obj);
  string body(body0);
  free(body0);
  r->Respond(200, "OK", body);
  return true;
}

bool Daemon::HandleTrackRequest(Request *r) { 
  string track_path;
  if (!track_pat_.FullMatch(r->Path(), &track_path)) {
    return false;
  }
  INFO("load: %s", track_path.c_str());
  // make sure it's a real track
  Track t;
  if (library_->Get(track_path, &t) != 0) {
    DEBUG("no track");
    r->RespondNotFound();
    return true;
  }
  
  int fd = open(track_path.c_str(), O_RDONLY);
  if (fd < 0) {
    DEBUG("missing fd");
    r->RespondNotFound();
    return true;
  }

  struct stat the_stat;
  if (fstat(fd, &the_stat) < 0) {
    DEBUG("stat failed");
    r->RespondNotFound();
    return true;
  }
  string guess_content_type("application/octet-stream");
  if (strcasestr(track_path.c_str(), ".mp3")) 
    guess_content_type = "audio/mpeg";
  // fill me in
  r->AddResponseHeader("Content-Type", guess_content_type);
  int offset = 0;
  int length = the_stat.st_size;
  struct evbuffer *buf = evbuffer_new();
  evbuffer_add_file(buf, fd, offset, length);

  r->Respond(200, "OK", buf);
  evbuffer_free(buf);
  return true;
}

void Daemon::HandleRequest(Request *r) { 
    r->AddResponseHeader("Server", "md1/0.0");
    if (this->HandleHomeRequest(r))
      return;
    else if (this->HandleLibraryRequest(r))
      return;
    else if (this->HandleTrackRequest(r))
      return;
    else
      r->RespondNotFound();
}

Daemon::Daemon(const vector<Host> &listen_to, shared_ptr<Library> library) : 
  library_(library),
  listen_to_(listen_to),
  root_pat_("^/$"),
  track_pat_("^/tracks(/.+)$"),
  library_pat_("^/library$")
{
  main_thread_ = NULL;
  running_ = false;
  event_base_ = event_base_new();
  event_http_ = evhttp_new(event_base_);
  for (vector<Host>::const_iterator i = listen_to.begin(); i < listen_to.end(); i++){ 
    string addr = get<0>(*i);
    int port = get<1>(*i);
    evhttp_bind_socket(event_http_, addr.c_str(), port);
  }
  evhttp_set_gencb(event_http_, OnRequest, this);
  library_ = library;
  root_pat_ = pcrecpp::RE("^/");
}

void Daemon::Stop() { 
  running_ = false;
}

void Daemon::Start() { 
  running_ = true;
  pthread_create(&main_thread_, NULL, MainThread, this);
}

void Daemon::RunMainThread() {
   struct timeval awake_interval;
   awake_interval.tv_sec = 0;
   awake_interval.tv_usec = 10000;
  while (running_) {
    event_base_loopexit(event_base_, &awake_interval);
    event_base_loop(event_base_, 0);
  }
}

Daemon::~Daemon() { 
  event_base_free(event_base_);
}


