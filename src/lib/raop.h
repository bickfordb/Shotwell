#ifndef _RAOP_H_
#define _RAOP_H_

#include <arpa/inet.h>
#include <netdb.h>
#include <netinet/in.h>
#include <openssl/aes.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <stdlib.h>
#include <string>
#include <unistd.h>
#include "aes.h"
#include "buffer.h"
#include "frame.h"
#include <event2/event.h>
#include <event2/buffer.h>


using namespace std;

namespace md1 {
  namespace raop {
    struct Request;
    struct Response;

    class Client {
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
      //int32_t remote_buffer_size_;
      uint16_t rtp_seq_;
      struct event *rtpwrite_event_;
      struct event *rtpread_event_;
      struct event *datasrc_event_;
      bool eof_;
      int datasrc_fd_;
      AES_KEY aes_;
      bool EncodePCM(struct evbuffer *in, struct evbuffer *out);
      void Encrypt(uint8_t *in, size_t in_len);
      bool EncodePacket(struct evbuffer *in, struct evbuffer *out);
      bool Flush(); 
      bool SetVolume(double pct);
      bool ConnectControlSocket();
      bool ConnectRTP();
      bool Announce();
      bool Record();
      bool Setup(); 
      bool RunRequest(const Request &request, Response *response);
      static void OnRTPReadyCallback(evutil_socket_t s, short evt, void *ctx) { 
        ((Client *)ctx)->OnRTPReady(s, evt);
      }
      void OnRTPReady(evutil_socket_t s, short evt);

      void OnDataSourceReady(evutil_socket_t s, short evt);
      static void OnDataSourceReadyCallback(evutil_socket_t s, short evt, void *ctx) {
        ((Client *)ctx)->OnDataSourceReady(s, evt);
      }
    public:
      void Play(const string &filename);
      Client(const string &addr, int port);
      ~Client();
      bool Connect();
    };
  }
}
#endif 
