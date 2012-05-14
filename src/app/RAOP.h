/* RAOP/Airtunes AudioSink */

#include <arpa/inet.h>
#include <event2/buffer.h>
#include <event2/event.h>
#include <netdb.h>
#include <netinet/in.h>
#include <openssl/aes.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <stdlib.h>
#include <string>
#include <unistd.h>

#include "app/AES.h"
#include "app/AudioSink.h"
#include "app/AudioSource.h"
#include "app/RTSPClient.h"

typedef enum { 
  kRAOPV1, 
  kRAOPV2
} RAOPVersion;

typedef enum {
  kInitialRAOPState,
  kConnectedRAOPState
} RAOPState;

@interface RAOPSink : NSObject <AudioSink> {
  Loop *loop_;
  RTSPClient *rtsp_;
  int fd_;
  int controlFd_;
  NSString *address_;
  uint16_t port_;
  id <AudioSource> audioSource_;
  int packetNum_;
  uint16_t rtpSeq_;
  uint32_t rtpTimestamp_;
  aes_context aesContext_;
  RAOPVersion raopVersion_;
  struct timeval lastSync_;
  bool isPaused_;
  bool isConnected_;
  bool isReading_;
  bool isWriting_;
  RAOPState state_;
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
@property bool isPaused;
@property bool isConnected;
@property RAOPState state;

- (id)initWithAddress:(NSString *)address port:(uint16_t)port;

@end

// vim: filetype=objcpp
