/* RAOP/Airtunes AudioSink */

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

#include "app/AES.h"
#include "app/AudioSink.h"
#include "app/AudioSource.h"
#include "app/RTSPClient.h"

typedef enum { RAOPV1 = 0, RAOPV2 = 1} RAOPVersion;

@interface RAOPSink : NSObject <AudioSink> {
  Loop *loop_;
  RTSPClient *rtsp_;
  int fd_;
  int controlFd_;
  double volume_;
  NSString *address_;
  uint16_t port_;
  id <AudioSource> audioSource_;
  int packetNum_;
  uint16_t rtpSeq_;
  uint32_t rtpTimestamp_;
  uint32_t ssrc_;
  aes_context aesContext_;
  RAOPVersion raopVersion_;
  struct timeval lastSync_;

}

@property RAOPVersion raopVersion;
@property (retain) id <AudioSource> audioSource;
@property (retain) Loop *loop;
@property (retain) RTSPClient *rtsp;
@property (retain) NSString *address;
@property uint16_t port;
@property int packetNumber;
@property uint16_t rtpSeq;
@property uint32_t rtpTimestamp;
@property uint32_t ssrc;

- (id)initWithAddress:(NSString *)address port:(uint16_t)port source:(id <AudioSource>)source;
- (void)read;
- (bool)connectRTP;
- (void)write;
- (void)encrypt:(uint8_t *)data size:(size_t)size;
- (void)encodePCM:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)encodePacketV2:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)encodePacketV1:(struct evbuffer *)in out:(struct evbuffer *)out;

@end

// vim: filetype=objcpp
