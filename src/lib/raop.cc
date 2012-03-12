#include <algorithm>
#include <assert.h>
#include <cstring>
#include <errno.h>
#include <fcntl.h>
#include <map>
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <pcrecpp.h>
#include <stdlib.h>
#include <sys/time.h>
#include <vector>
#include <xlocale.h>

#include "aes.h"
#include "base64.h"
#include "buffer.h"
#include "frame.h"
#include "log.h"
#include "raop.h"
#include "util.h"
using namespace pcrecpp;
using namespace std;

// Types

namespace md1 {
  namespace raop {
    typedef map<string,string> Headers;

    // Prototypes

    bool SendRequest(int fd, const Request &req);
    void LogBytes(uint8_t *b, size_t len);
    bool ReceiveResponse(int fd, Response *r);
    long double Now();
    static void RSAEncrypt(uint8_t *text, size_t text_len, uint8_t **out, size_t *out_len);
    int SendAll(int fd, const uint8_t *bytes, int len);
    static inline void bits_write(uint8_t **p, uint8_t d, int blen, int *bpos);

    // Globals

    static const int kHdrDefaultLength = 1024;
    static const int kSdpDefaultLength = 2048;
    static const int kSamplesPerFrame = 4096; // not 1152?
    static const int kBytesPerChannel = 2;
    static const int kNumChannels = 2;
    static const int kFrameSizeBytes = 16384;
    static const int kBitRate = 44100;
    static const int kAESKeySize = 16; // bytes
    static const char *kPublicExponent64 = "AQAB";
    static const char *kPublicMod64 =
      "59dE8qLieItsH1WgjrcFRKj6eUWqi+bGLOX1HL3U3GhC/j0Qg90u3sG/1CUtwC"
      "5vOYvfDmFI6oSFXi5ELabWJmT2dKHzBJKa3k9ok+8t9ucRqMd6DZHJ2YCCLlDR"
      "KSKv6kDqnw4UwPdpOMXziC/AMj3Z/lUVX1G7WSHCAWKf1zNS1eLvqr+boEjXuB"
      "OitnZ/bDzPHrTOZz0Dew0uowxf/+sG+NCK3eQJVxqcaJ/vEHKIVd2M+5qL71yJ"
      "Q+87X6oV3eaYvt3zWZYD6z5vYTcrtij2VZ9Zmni/UAaHqn9JdsBWLUEpVviYnh"
      "imNVvYFZeCXg/IdTQ+x4IRdiXNv5hEew==";

    struct Request { 
      string method;
      string uri;
      string protocol;
      Headers headers;
      string body;
      Request() : protocol("RTSP/1.0") {
      }
      ~Request() { }
    };

    struct Response { 
      int status;
      Headers headers;
      string body;
      Response() : status(0) { }
      ~Response() {} 
      static bool Parse(const string &s, Response *);
    };

    bool SendRequest(int fd, const Request &req) { 
      string data;
      data.append(req.method);
      data.append(" ");
      data.append(req.uri);
      data.append(" ");
      data.append(req.protocol);
      data.append("\r\n");
      Headers::const_iterator i;
      for (i = req.headers.begin(); i != req.headers.end(); i++) {
        data.append(i->first);
        data.append(": ");
        data.append(i->second);
        data.append("\r\n");
      }
      data.append("\r\n");
      if (req.body.length() > 0) {
        data.append(req.body);
      }
      INFO("request: \n%s", data.c_str());
      int amt = SendAll(fd, (uint8_t *)data.c_str(), data.length());
      return (amt == data.length());
    }

    int GetLine(
        const string &s, 
        int offset,
        string *to_string) { 
      int l = s.length();
      int i = 0;
      for (i = offset; i < l; i++) {
        if (s[i] == '\r'
            && ((i + 1) < l)
            && s[i + 1] == '\n') {
          to_string->append(s.c_str() + offset, i - offset);
          return 2 + i - offset;
        }
      }
      to_string->append(s.c_str() + offset, s.length() - offset);
      int sz = s.length() - offset;
      return sz < 0 ? 0 : sz;
    }

    bool ReceiveResponse(int fd, Response *response) {
      if (!fd)
        return false;
      uint8_t bytes[1024];
      string s; 
      int amt = recv(fd, bytes, 1024, 0);
      if (amt == 0)
        return false; // no more connection
      if (amt == -1)
        return false;
      if (amt > 0) {
        s.append((const char *)bytes, amt);
      }
      return Response::Parse(s, response);
    }

    bool Response::Parse(const string &s, Response *response) {
      INFO("parse: %s", s.c_str());
      RE header_pat("^(.+?)\\s*[:]\\s*(.+)$");
      RE status_pat("^RTSP/1.0\\s+(\\d+)\\s+.*$");
      string status;
      string status_line;
      int offset = GetLine(s, 0, &status_line);
      if (!status_pat.FullMatch(status_line, &status)) {
        ERROR("Failed to parse status: '%s'", status.c_str());
        return false;
      }
      response->status = atoi(status.c_str());
      for (;;) {
        string h;
        int amt = GetLine(s, offset, &h);
        if (amt == 0) { 
          break;
        } else {
          string key;
          string value;
          string line = s.substr(offset, amt - 2);
          if (header_pat.FullMatch(line, &key, &value)) {
            std::transform(key.begin(), key.end(), key.begin(), ::tolower);
            response->headers[key] = value;
            //response->headers.insert(key, value);
          }
          offset += amt;
        }
      }
      response->body = s.substr(offset, s.length() - offset);
      return true;
    }

    long double Now() {
      timeval t;
      gettimeofday(&t, NULL);
      return (1.0 * t.tv_sec) + (t.tv_usec / 1000000.0);
    }


    bool Client::EncodePCM(
        struct evbuffer *in, 
        struct evbuffer *out) {
      //LogBytes(pcm, pcm_len);
      uint8_t pcm[kFrameSizeBytes];
      size_t pcm_len = evbuffer_remove(in, pcm, kFrameSizeBytes);
      int bsize = pcm_len / 4;
      //INFO("bsize: %d, len: %d", bsize, pcm_len);
      size_t max_len = pcm_len + 64;
      uint8_t alac[kFrameSizeBytes + 64];

      uint8_t one[4];
      int count = 0;
      int bpos = 0;
      uint8_t *bp = alac;
      int nodata = 0;
      bits_write(&bp,1,3,&bpos); // channel=1, stereo
      bits_write(&bp,0,4,&bpos); // unknown
      bits_write(&bp,0,8,&bpos); // unknown
      bits_write(&bp,0,4,&bpos); // unknown
      if(bsize!=kSamplesPerFrame)
        bits_write(&bp,1,1,&bpos); // hassize
      else
        bits_write(&bp,0,1,&bpos); // hassize
      bits_write(&bp,0,2,&bpos); // unused
      bits_write(&bp,1,1,&bpos); // is-not-compressed
      if(bsize!=kSamplesPerFrame){
        bits_write(&bp,(bsize>>24)&0xff,8,&bpos); // size of data, integer, big endian
        bits_write(&bp,(bsize>>16)&0xff,8,&bpos);
        bits_write(&bp,(bsize>>8)&0xff,8,&bpos);
        bits_write(&bp,bsize&0xff,8,&bpos);
      }
      for (int i = 0; i < pcm_len; i += 2) {
        bits_write(&bp, pcm[i + 1], 8, &bpos);
        bits_write(&bp, pcm[i], 8, &bpos);
      }
      count += pcm_len / 4;
      if (!count) {
        ERROR("no data");
        return false; // when no data at all, it should stop playing
      }
      /* when readable size is less than bsize, fill 0 at the bottom */
      for(int i = 0; i < (bsize - count) * 4; i++){
        bits_write(&bp,0,8,&bpos);
      }
      if ((bsize - count) > 0) {
        ERROR("added %d bytes of silence", (bsize - count) * 4);
      } 
      int out_len = (bpos ? 1 : 0 ) + bp - alac;
      evbuffer_add(out, (void *)alac, out_len);
      return true;
    }

    bool Client::EncodePacket(struct evbuffer *in, struct evbuffer *out) {
      uint8_t header[] = {
        0x24, 0x00, 0x00, 0x00,
        0xF0, 0xFF, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
      };
      const int header_size = 16;      
      int alac_len = evbuffer_get_length(in);
      uint8_t alac[16384 + 16];
      evbuffer_remove(in, alac, alac_len);
      size_t packet_len = alac_len + 16;
      uint8_t packet[packet_len];
      uint16_t len = alac_len + header_size - 4;
      header[2] = len >> 8;
      header[3] = len & 0xff;

      memcpy(packet, header, header_size);
      memcpy(packet + header_size, alac, alac_len);
      Encrypt(packet + header_size, alac_len);
      evbuffer_add(out, packet, packet_len);
      return true;
    }

    int SendAll(int fd, const uint8_t *bytes, int len) { 
      if (fd < 0) {
        return -1;
      }
      int offset = 0;
      int remaining = len;
      while (remaining > 0) {
        int amt = send(fd, bytes + offset, remaining, 0);
        if (amt == -1)
          return -1;
        if (amt > 0) {
          remaining -= amt;
          offset += amt;
        }
      }
      return offset;
    }

    size_t SocketRecv(int fd, string &buf, size_t len) {
      if (fd < 0) 
        return -1;
      char data[len];
      memset(data, 0, len);
      int ret = recv(fd, data, len, 0);
      if (ret == 0)
        return -1;
      if (ret >= 0) 
        buf.append(data, ret);
      return ret;
    }

    static void RSAEncrypt(
        uint8_t *text, 
        size_t text_len, 
        uint8_t **out,
        size_t *out_len) { 
      RSA *rsa;
      uint8_t modules[256];
      uint8_t exponent[8];
      int size;
      char n[] = "59dE8qLieItsH1WgjrcFRKj6eUWqi+bGLOX1HL3U3GhC/j0Qg90u3sG/1CUtwC"
        "5vOYvfDmFI6oSFXi5ELabWJmT2dKHzBJKa3k9ok+8t9ucRqMd6DZHJ2YCCLlDR"
        "KSKv6kDqnw4UwPdpOMXziC/AMj3Z/lUVX1G7WSHCAWKf1zNS1eLvqr+boEjXuB"
        "OitnZ/bDzPHrTOZz0Dew0uowxf/+sG+NCK3eQJVxqcaJ/vEHKIVd2M+5qL71yJ"
        "Q+87X6oV3eaYvt3zWZYD6z5vYTcrtij2VZ9Zmni/UAaHqn9JdsBWLUEpVviYnh"
        "imNVvYFZeCXg/IdTQ+x4IRdiXNv5hEew==";
      char e[] = "AQAB";
      rsa = RSA_new();
      size = base64_decode(n, modules);
      rsa->n = BN_bin2bn(modules, size, NULL);
      size = base64_decode(e, exponent);
      rsa->e = BN_bin2bn(exponent, size, NULL);
      unsigned char res[RSA_size(rsa)];
      *out_len = RSA_size(rsa);
      *out = (uint8_t *)malloc(*out_len);
      size = RSA_public_encrypt(text_len, text, *out, rsa, RSA_PKCS1_OAEP_PADDING);
      RSA_free(rsa);
    }

    void Client::Play(const string &filename) {
      datasrc_fd_ = open(filename.c_str(), O_RDONLY);
      if (datasrc_fd_ < 0) {
        ERROR("unable to open filename: %s", filename.c_str());
        return;
      }
      int flags = fcntl(datasrc_fd_, F_GETFL, 0);
      flags |= O_NONBLOCK;
      fcntl(datasrc_fd_, F_SETFL, flags);

      flags = fcntl(rtp_sd_, F_GETFL, 0);
      flags |= O_NONBLOCK;
      fcntl(rtp_sd_, F_SETFL, flags);

      rtpwrite_event_ = event_new(event_base_, rtp_sd_, EV_WRITE, Client::OnRTPReadyCallback, this);
      rtpread_event_ = event_new(event_base_, rtp_sd_, EV_READ | EV_PERSIST, Client::OnRTPReadyCallback, this);
      datasrc_event_ =  event_new(event_base_, datasrc_fd_, EV_READ, Client::OnDataSourceReadyCallback, this);
      event_add(datasrc_event_, NULL);
      event_add(rtpread_event_, NULL);
      event_base_dispatch(event_base_);
    }

    Client::~Client() {
      close(rtp_sd_);
      close(rtsp_sd_);
      close(datasrc_fd_);
      if (rtpwrite_event_)
        event_free(rtpwrite_event_);
      if (rtpread_event_)
        event_free(rtpread_event_);
      if (datasrc_event_) 
        event_free(datasrc_event_);
      event_base_free(event_base_);
    }

    Client::Client(const string &addr, int port) : addr_(addr), port_(port) {
      RAND_bytes(key_, kAESKeySize);
      RAND_bytes(iv_, kAESKeySize);
      eof_ = false;

      datasrc_fd_ = -1;
      datasrc_buf_ = evbuffer_new();
      alac_buf_ = evbuffer_new();
      rtp_out_buf_ = evbuffer_new();
      rtp_in_buf_ = evbuffer_new();

      memset(&aes_, 0, sizeof(aes_));
      AES_set_encrypt_key(key_, kAESKeySize * 8, &aes_);
      memset((void *)&aes_ctx_, 0, sizeof(aes_ctx_));
      aes_set_key(&aes_ctx_, key_, kAESKeySize * 8); 
      event_base_ = event_base_new();
      datasrc_event_ = NULL;
      rtpwrite_event_ = NULL;
      rtpread_event_ = NULL;
      data_port_ = 6000;
      last_sent_ = 0.0;
      rtp_seq_ = 0;
      rtp_time_ = 0;
      //remote_buffer_size_ = 0;
      last_remote_buffer_update_at_ = 0;
      RAND_bytes((unsigned char *)&ssrc_, sizeof(ssrc_));
      unsigned long url_key_bytes; 
      RAND_bytes((unsigned char *)&url_key_bytes, sizeof(url_key_bytes));
      url_abspath_ = Format("%lu", url_key_bytes);

      int64_t cid_num;
      RAND_bytes((unsigned char *)&cid_num, sizeof(cid_num));
      cid_ = Format("%08X%08X", cid_num >> 32, cid_num);
      cseq_ = 0;
      challenge_ = StringReplace(Base64Encode(RandBytes(16)), "=", "");
      user_agent_ = "iTunes/4.6 (Macintosh; U; PPC Mac OS X 10.3)";
      rtp_sd_ = -1;
      rtsp_sd_ = -1;
    }


    bool Client::Flush() { 
      return false;
    }

    bool Client::ConnectControlSocket() { 
      if ((rtsp_sd_ = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        ERROR("error creating socket");
        return false;
      }
      rtsp_sd_in_.sin_family = AF_INET;
      rtsp_sd_in_.sin_port = htons(port_);
      if (!inet_aton(addr_.c_str(), &rtsp_sd_in_.sin_addr)) {
        struct hostent *hp = (struct hostent *)gethostbyname(addr_.c_str());
        if (hp == NULL) {
          ERROR("Failed to get hostname");
          return false;
        }
        memcpy(&rtsp_sd_in_.sin_addr, hp->h_addr, hp->h_length);
      }
      if (connect(rtsp_sd_, (struct sockaddr *)&rtsp_sd_in_,
            sizeof(rtsp_sd_in_)) < 0) {
        ERROR("Failed to connect");
        return false;
      }
      return true;
    }


    bool Client::RunRequest(
        const Request & req, 
        Response *response) {
      if (!SendRequest(rtsp_sd_, req)) {
        ERROR("Failed to send request");
        return false;
      }
      if (!ReceiveResponse(rtsp_sd_, response)) {
        ERROR("Failed to receive response");
        return false;
      }
      return true;
    }

    bool Client::Connect() {
      if (!ConnectControlSocket()) {
        ERROR("failed to setup control socket");
        return false;
      }
      if (!Announce()) {
        ERROR("Failed to announce");
        return false;
      }
      if (!Setup()) {
        ERROR("Failed to setup");
        return false;
      }
      if (!Record()) {
        ERROR("failed to record");
        return false;
      }
      if (!SetVolume(0.2)) {
        ERROR("failed to set volume");
        return false;
      }
      if (!ConnectRTP()) {
        ERROR("failed to connect data socket");
        return false;
      }
      return true;
    } 

    bool Client::Announce() { 
      Request req;
      uint8_t *rsa_key = NULL;
      size_t rsa_key_len = 0;
      RSAEncrypt(key_, kAESKeySize, &rsa_key, &rsa_key_len);
      char *rsa64 = NULL;
      base64_encode(rsa_key, rsa_key_len, &rsa64);
      string iv64 = StringReplace(Base64Encode((const char *)iv_), "=", "");

      char local_addr[INET_ADDRSTRLEN];
      struct sockaddr_in ioaddr;
      socklen_t iolen = sizeof(struct sockaddr);
      getsockname(rtsp_sd_, (struct sockaddr *)&ioaddr, &iolen);
      inet_ntop(AF_INET, &(ioaddr.sin_addr), local_addr, INET_ADDRSTRLEN);

      req.method = "ANNOUNCE";
      req.uri = Format("rtsp://%s/%s", addr_.c_str(),
          url_abspath_.c_str());
      req.protocol = "RTSP/1.0";
      req.body = Format(
          "v=0\r\n"
          "o=iTunes %s 0 IN IP4 %s\r\n"
          "s=iTunes\r\n"
          "c=IN IP4 %s\r\n"
          "t=0 0\r\n"
          "m=audio 0 RTP/AVP 96\r\n"
          "a=rtpmap:96 AppleLossless\r\n"
          "a=fmtp:96 %d 0 %d 40 10 14 %d 255 0 0 %d\r\n"
          "a=rsaaeskey:%s\r\n"
          "a=aesiv:%s\r\n",
          url_abspath_.c_str(),
          local_addr,
          addr_.c_str(),
          kSamplesPerFrame,
          kBytesPerChannel * 8,
          kNumChannels,
          kBitRate,
          rsa64,
          iv64.c_str());
      req.headers["CSeq"] = Format("%d", ++cseq_);
      req.headers["Client-Instance"] = cid_;
      req.headers["Content-Type"] = "application/sdp";
      req.headers["Content-Length"] = Format("%d", req.body.length());
      req.headers["Apple-Challenge"] = challenge_;
      free(rsa64);

      Response resp;
      if (!RunRequest(req, &resp)) {
        return false;
      }

      if (resp.status != 200) {
        ERROR("unexpected announce status: %d", resp.status);
        return false;
      }
      return true;
    }

    bool Client::Setup() { 
      char *ac;
      char *ky;
      char *s;
      RSA *rsa;
      size_t size;
      int res;
      int ret;

      Request req;
      req.method = "SETUP";
      req.uri = Format("rtsp://%s/%s", addr_.c_str(), url_abspath_.c_str());
      req.headers["CSeq"] = Format("%d", ++cseq_);
      req.headers["Transport"] = "RTP/AVP/TCP;unicast;interleaved=0-1;mode=record";
      req.headers["User-Agent"] = user_agent_;
      req.headers["Client-Instance"] = cid_;
      Response resp;
      if (!RunRequest(req, &resp)) 
        return false;
      if (resp.headers.count("session") == 0) { 
        ERROR("unable to find session id");
        return false;
      }
      session_id_ = resp.headers["session"];
      INFO("got session id: %s", session_id_.c_str());
      return true;
    }

    bool Client::Record() {
      Request request;
      request.method = "RECORD";
      request.uri = Format("rtsp://%s/%s", addr_.c_str(), url_abspath_.c_str());
      request.headers["CSeq"] = Format("%d", ++cseq_);
      request.headers["User-Agent"] = user_agent_;
      request.headers["Client-Instance"] = cid_;
      request.headers["Range"] = "ntp=0-";
      rtp_seq_ = 0;
      int rtp_time = 0;
      request.headers["RTP-Info"] =
        Format("seq=%d;rtptime=%d", rtp_seq_, rtp_time);
      Response response;
      if (!RunRequest(request, &response))
        return false;
      return true;
    }

    bool Client::ConnectRTP() { 
      rtp_sd_ = socket(AF_INET, SOCK_STREAM, 0);
      rtp_sd_in_.sin_family = AF_INET;
      rtp_sd_in_.sin_port = htons(data_port_);
      //memcpy(&rtp_sd_in_.sin_addr, &rtsp_sd_in_.sin_addr,
      //   sizeof(rtsp_sd_in_.sin_addr));
      inet_aton(addr_.c_str(), &rtp_sd_in_.sin_addr);

      int ret = connect(rtp_sd_, (struct sockaddr *)&rtp_sd_in_, sizeof(rtp_sd_in_));
      if (ret < 0) {
        ERROR("unable to connect to control port");
        return false;
      }
      int flags = fcntl(rtp_sd_, F_GETFL, 0);
      flags |= O_NONBLOCK;
      fcntl(rtp_sd_, F_SETFL, flags);
      return true;
    }

    bool Client::SendVolume(double pct) { 
      Request req;
      Response resp;

      // 0 is max, -144 is min  
      double volume = 0;  
      if (pct < 0.01) 
        volume = -144;
      else {
        double max = 0;
        double min = -30;
        volume = (pct * (max - min)) + min;
      }

      req.method = "SET_PARAMETER";
      req.uri = Format("rtsp://%s/%s", 
          addr_.c_str(),
          url_abspath_.c_str());
      req.headers["CSeq"] = Format("%d", ++cseq_);
      req.headers["Session"] = session_id_;
      req.headers["User-Agent"] = user_agent_;
      req.headers["Content-Type"] = "text/parameters";
      req.headers["Client-Instance"] = cid_;
      req.body = Format("volume: %.6f\r\n", volume);
      req.headers["Content-Length"] = Format("%d", req.body.length());
      if (!RunRequest(req, &resp)) {
        return false;
      }
      return resp.status == 200;
    }

    /* write bits filed data, *bpos=0 for msb, *bpos=7 for lsb
       d=data, blen=length of bits field
       */

    static inline void bits_write(uint8_t **p, uint8_t d, int blen, int *bpos) {
      int lb,rb,bd;
      lb=7-*bpos;
      rb=lb-blen+1;
      if(rb>=0){
        bd=d<<rb;
        if(*bpos)
          **p|=bd;
        else
          **p=bd;
        *bpos+=blen;
      }else{
        bd=d>>-rb;
        **p|=bd;
        *p+=1;
        **p=d<<(8+rb);
        *bpos=-rb;
      }
    }

    void Client::Encrypt(uint8_t *data, size_t size) {
      uint8_t *buf;
      int i = 0;
      memcpy(nv_, iv_, kAESKeySize);
      while ((i + kAESKeySize) <= size) {
        buf = data + i;
        for (int j = 0; j < kAESKeySize; j++)
          buf[j] ^= nv_[j];
        aes_encrypt(&aes_ctx_, buf, buf);
        memcpy(nv_, buf, kAESKeySize);
        i += kAESKeySize;
      }
    }

    void LogBytes(uint8_t *b, size_t len) {
      static int fd = -1;
      if (fd == -1) {
        char *p = getenv("LOG_BYTES_PATH");
        if (p)
          fd = open(p, O_APPEND);
      }
      static int i = 0;
      if (fd > 0) {
        dprintf(fd, "%05d: ", i);
        for (int i = 0; i < len; i++) { 
          dprintf(fd, "%hhX", b[i]);
        }
        dprintf(fd, "\n");
        i++;
      }
    }

    void Client::OnDataSourceReady(evutil_socket_t socket, short evt) {
      int amt_read = evbuffer_read(datasrc_buf_, datasrc_fd_, kFrameSizeBytes);
      int len = evbuffer_get_length(datasrc_buf_);
      if (len >= kFrameSizeBytes)
        event_add(rtpwrite_event_, NULL);
      if (amt_read == 0) { 
        eof_ = true;
        event_add(rtpwrite_event_, NULL);
      } else if (amt_read > 0) {
        if (len < kFrameSizeBytes)
          event_add(datasrc_event_, NULL);
      } else if (errno == EAGAIN || errno == EINTR) {
        event_add(datasrc_event_, NULL);
      } else { 
        ERROR("error reading from data source: %s", strerror(errno));
        eof_ = true;
        if (len > 0)
          event_add(rtpwrite_event_, NULL);
      }
    }
    void Client::OnRTPReady(evutil_socket_t socket, short evt) { 
      if (evt & EV_READ) {
        int amt = evbuffer_read(rtp_in_buf_, rtp_sd_, -1);
        evbuffer_drain(rtp_in_buf_, evbuffer_get_length(rtp_in_buf_));
      } 
      if (evt & EV_WRITE) {
        size_t len = evbuffer_get_length(rtp_out_buf_);
        if (len == 0 && evbuffer_get_length(datasrc_buf_) > 0) {
          EncodePCM(datasrc_buf_, alac_buf_);
          EncodePacket(alac_buf_, rtp_out_buf_);
          event_add(datasrc_event_, NULL);
        }
        len = evbuffer_get_length(rtp_out_buf_);

        if (len > 0) {
          int amt = evbuffer_write(rtp_out_buf_, rtp_sd_);
          //static int z = 0;
          //fprintf(stderr, "%05d: rtp write: %d\r", z, amt);
          //z++;
          len = evbuffer_get_length(rtp_out_buf_);
          if (len == 0) {
            event_add(datasrc_event_, NULL);
          } else if (amt == 0) {
            // rtp eof 
            // dont' do anything?
            ERROR("rtp eof");
          } else if (amt > 0) { 
            event_add(rtpwrite_event_, NULL);
          } else {
            if (errno == EINTR || errno == EAGAIN) {
              event_add(rtpwrite_event_, NULL);
            } else {
              ERROR("got error: %s", strerror(errno));
              // end here since we cant send any more packets?
            }
          }
        } else { 
          // there was nothing in the out buffer... then
          event_add(datasrc_event_, NULL);
        } 
      }
    }
  }
}


