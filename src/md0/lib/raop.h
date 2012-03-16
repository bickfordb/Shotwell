#ifndef _RAOP_H_
#define _RAOP_H_

#include <arpa/inet.h>
#include <event2/buffer.h>
#include <event2/event.h>
#include <netdb.h>
#include <netinet/in.h>
#include <openssl/aes.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <stdlib.h>
#include <string>
#include <unistd.h>

#include "md0/lib/audio_sink.h"
#include "md0/lib/aes.h"
#include "md0/lib/buffer.h"
#include "md0/lib/frame.h"

using namespace std;

namespace md0 {
namespace raop {
struct Request;
struct Response;

class Client : public AudioSink {
  string addr_;
  struct event_base *event_base_;
  int port_;
  int rtsp_sd_; 
  int rtp_sd_; 
  int data_port_;

  struct evbuffer *rtp_in_buf_;
  struct evbuffer *datasrc_buf_;
  struct evbuffer *alac_buf_;
  struct evbuffer *rtp_out_buf_;
  

  uint32_t rtp_time_;
  uint32_t ssrc_;
  aes_context aes_ctx_;
  struct sockaddr_in rtsp_sd_in_;
  struct sockaddr_in rtp_sd_in_;
  uint8_t key_[16];
  uint8_t iv_[16];
  uint8_t nv_[16];
  string url_abspath_;
  string cid_;
  string challenge_;
  int cseq_; 
  string user_agent_;
  string session_id_;
  double last_sent_;
  double last_remote_buffer_update_at_;
  double remote_buffer_len_;
  uint16_t rtp_seq_;
  struct event *rtpwrite_event_;
  struct event *rtpread_event_;
  struct event *rtpwrite_deadline_event_;
  bool running_;
  bool started_;
  double volume_;
  bool needs_flush_;
  //AES_KEY aes_;
  bool EncodePCM(struct evbuffer *in, struct evbuffer *out);
  void Encrypt(uint8_t *in, size_t in_len);
  bool EncodePacket(struct evbuffer *in, struct evbuffer *out);
  bool Flush(); 
  bool ConnectControlSocket();
  bool ConnectRTP();
  bool Announce();
  bool Record();
  bool Setup(); 
  bool RunRequest(const Request &request, Response *response);
  static void OnRTPReadyCallback(evutil_socket_t s, short evt, void *ctx) { 
    ((Client *)ctx)->OnRTPReady(s, evt);
  }
  static void OnWriteDeadline(evutil_socket_t s, short evt, void *ctx);
  void ScheduleWrite();
  void OnRTPReady(evutil_socket_t s, short evt);
  bool Connect();
  bool SendVolume(double);
  void MainLoop();
  static void* MainLoopCallback(void *ctx) { 
    ((Client *)ctx)->MainLoop();
    return NULL;
  }
  AudioSource *src_;
  void Lock();
  void Unlock();
  pthread_mutex_t lock_;
  bool Teardown();
 public:
  void SetVolume(double pct) { volume_ = pct; SendVolume(pct); }

  AudioSource *Source() { return src_; }
  void SetSource(AudioSource *src) { 
    Lock();
    src_ = src;
    Unlock();
  }

  void FlushStream() { 
    needs_flush_ = true;
  }

  double Volume() { return volume_; }
  Client(const string &addr, int port);
  virtual ~Client();

  void Start();
  void Stop();
};
}
}
#endif 
