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

using namespace std;

namespace md1 {
  namespace raop {
    struct Request;
    struct Response;

    class Client {
      string addr_;
      int port_;
      int ctrl_sd_; 
      int data_sd_; 
      int data_port_;
      uint32_t rtp_time_;
      uint32_t ssrc_;
      aes_context aes_ctx_;
      struct sockaddr_in ctrl_sd_in_;
      struct sockaddr_in data_sd_in_;
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
      uint16_t rtp_seq_;
      uint8_t *sample_buf_; 
      size_t sample_len_;
      AES_KEY aes_;
      void Write(uint8_t *sample, size_t sample_len);
      bool EncodePCM(uint8_t *in, size_t in_len, uint8_t **encoded, size_t *encoded_len);
      void Encrypt(uint8_t *in, size_t in_len);
      bool EncodePacket(uint8_t *in, size_t in_len, uint8_t **encoded, size_t *encoded_len);
      bool Flush(); 
      bool SetVolume(double pct);
      bool ConnectControlSocket();
      bool ConnectDataSocket();
      bool Announce();
      bool Record();
      bool Setup(); 
      bool RunRequest(const Request &request, Response *response);
      static void *ReaderThreadCallback(void *ctx) {
        ((Client *)ctx)->OnReaderThread(); 
      }
      void OnReaderThread();
    public:
      void WritePCM(uint8_t *sample, size_t sample_len, bool is_eof);
      Client(const string &addr, int port);
      ~Client() {};
      bool Connect();
    };
  }
}
#endif 
