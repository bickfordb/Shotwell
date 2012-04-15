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

#include "md0/AES.h"
#include "md0/AudioSink.h"
#include "md0/AudioSource.h"
#include "md0/RTSPClient.h"

@interface RAOPSink : NSObject <AudioSink> {
  Loop *loop_;
  RTSPClient *rtsp_;
  int fd_;
  double volume_;
  NSString *address_;
  uint16_t port_;
  id <AudioSource> audioSource_;
  int packetNum_;
  aes_context aesContext_;
}

- (id)initWithAddress:(NSString *)address port:(uint16_t)port source:(id <AudioSource>)source;
- (void)read;
- (bool)connectRTP;
- (void)write;
- (void)encodePacket:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)encrypt:(uint8_t *)data size:(size_t)size;
- (void)encodePCM:(struct evbuffer *)in out:(struct evbuffer *)out;

@property (retain) id <AudioSource> audioSource;
@property (retain) Loop *loop;
@property (retain) RTSPClient *rtsp;
@property (retain) NSString *address;
@property uint16_t port;

@end

// vim: filetype=objcpp
