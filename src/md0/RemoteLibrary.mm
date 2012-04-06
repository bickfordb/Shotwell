#include <event2/event.h>
#include <event2/buffer.h>
#include <event2/http.h>

#import "RemoteLibrary.h"
#import "Log.h"
#import "Util.h"

@implementation RemoteLibrary

@synthesize netService = netService_;

- (id)initWithNetService:(NSNetService *)netService {
  self = [super init];
  if (self) { 
    netService_ = [netService retain];
    loop_ = [[Loop alloc] init]; 
  }
  return self;
}

- (void)dealloc { 
  [netService_ release];
  [loop_ release];
  [super dealloc];
}

- (void)refresh {

}
/*void RemoteLibrary::GetAll(vector <Track> *to_tracks) { 
  Lock();
  for (vector<Track>::const_iterator i = tracks_.begin();
       i < tracks_.end(); 
       i++) {
    to_tracks->push_back(*i);
  }
  Unlock();
}

void RemoteLibrary::Lock() {
  pthread_mutex_lock(&lock_);

}

void RemoteLibrary::Unlock() { 
  pthread_mutex_unlock(&lock_); 
}

void RemoteLibrary::Fetch() {
  INFO("Fetching");
  //struct *evhttp_ = evhttp_new(event_base_);
  struct evhttp_connection *conn = evhttp_connection_base_new(event_base_, NULL, host_.c_str(), port_);
  struct evhttp_request *req = evhttp_request_new(RemoteLibrary::OnFetchResponseCallback, this);
  evhttp_add_header(
      evhttp_request_get_output_headers(req), 
      "Host", host_.c_str());
  evhttp_add_header(
      evhttp_request_get_output_headers(req), 
      "Connection", "close");
  int st = evhttp_make_request(conn, req, EVHTTP_REQ_GET, "/library");
  if (st == -1) {
    INFO("Failed to create request");
    evhttp_connection_free(conn);
    evhttp_request_free(req);
  }
}

void RemoteLibrary::OnFetchResponse(struct evhttp_request *req) {
  INFO("got response");
  const char *buf = (const char *)evbuffer_pullup(evhttp_request_get_input_buffer(req), -1);
  ssize_t buf_len = evbuffer_get_length(evhttp_request_get_input_buffer(req));
  json_error_t js_err;
  json_t *response_json = json_loadb(buf, buf_len, 0, &js_err);
  json_t *tracks_json = json_object_get(response_json, "tracks");
  size_t tracks_len = tracks_json ? json_array_size(tracks_json) : 0;
  Lock();
  tracks_.clear();
  for (size_t i = 0; i < tracks_len; i++) {
    json_t *t = json_array_get(tracks_json, i);
    if (!t) 
      continue;
    Track a_track;
    a_track.set_id((uint32_t)json_integer_value(json_object_get(t, "id")));
    a_track.set_artist(json_string_value(json_object_get(t, "artist")));
    a_track.set_album(json_string_value(json_object_get(t, "album")));
    a_track.set_genre(json_string_value(json_object_get(t, "genre")));
    a_track.set_year(json_string_value(json_object_get(t, "year")));
    a_track.set_duration(json_integer_value(json_object_get(t, "duration")));
    a_track.set_album(json_string_value(json_object_get(t, "album")));
    a_track.set_title(json_string_value(json_object_get(t, "title")));
    a_track.set_track_number(json_string_value(json_object_get(t, "track_number")));
    a_track.set_url(Format("http://%s:%d/tracks/%u",
      host_.c_str(),
      port_,
      a_track.id()));
    tracks_.push_back(a_track);
  }
  Unlock();
  INFO("found %d tracks", tracks_.size());
  struct timeval now;
  gettimeofday(&now, NULL);
  long double t = now.tv_sec;
  t += now.tv_usec / ((long double)1000000.0);
  last_updated_at_ = t;
  json_decref(response_json);
  INFO("done fetching");
}

void RemoteLibrary::Loop() { 
  running_ = true;
  INFO("loop");
  while (started_) { 
    if (request_refresh_) {
      Fetch();
      request_refresh_ = false;
    }
    struct timeval timeout;
    timeout.tv_sec = 0;
    timeout.tv_usec = 10000;
    event_base_loopexit(event_base_, &timeout);
    event_base_dispatch(event_base_);
  }
  INFO("remote library %p done", this);
  running_ = false;
}

int RemoteLibrary::Count() { 
  return 0;
}*/

@end

