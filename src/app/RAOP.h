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
#include "app/Util.h"

typedef enum { 
  kRAOPV1, 
  kRAOPV2
} RAOPVersion;

typedef enum {
  kInitialRAOPState,
  kConnectedRAOPState
} RAOPState;

/* RTP header bits */
// RTP_HEADER_A_EXTENSION = 0x10;
// RTP_HEADER_A_SOURCE = 0x0f;

// RTP_HEADER_B_PAYLOAD_TYPE = 0x7f;
// RTP_HEADER_B_MARKER = 0x80;

typedef int64_t RTPTimestamp;

typedef struct {
  uint8_t extension : 1;
  uint8_t source : 7;
  uint8_t marker : 1;
  uint8_t payloadType : 7;
  uint16_t sequence;
  /* extension = bool(a & RTP_HEADER_A_EXTENSION) */
  /* source = a & RTP_HEADER_A_SOURCE */

  /* payload_type = b & RTP_HEADER_B_PAYLOAD_TYPE */
  /* marker = bool(b & RTP_HEADER_B_MARKER) */
} RTPHeader;

typedef struct { 
  RTPHeader header;
  uint32_t zero;
  NTPTime referenceTime;
  NTPTime receivedTime;
  NTPTime sendTime;
} RAOPTimingPacket;

typedef struct { 
  RTPHeader header;
  uint16_t missedSeqNum;
  uint16_t count;
} RAOPResendPacket;

typedef struct { 
  RTPHeader header;
  RTPTimestamp nowMinusLatency;
  NTPTime timeLastSync;
  RTPTimestamp now;
} RAOPSyncPacket;

@interface RAOPSink : NSObject <AudioSink> {
  Loop *loop_;
  RTSPClient *rtsp_;
  int fd_;
  int controlFd_;
  int timingFd_;
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
  int64_t lastWriteAt_;
  int64_t seekTo_;
  RAOPTimingPacket lastTimingPacket_;
  bool isReadingTimeSocket_;
}

- (id)initWithAddress:(NSString *)address port:(uint16_t)port;

@property RAOPVersion raopVersion;
@property (retain) Loop *loop;
@property (retain) RTSPClient *rtsp;
@property (retain) NSString *address;
@property uint16_t port;
@property int packetNumber;
@property uint16_t rtpSeq;
@property uint32_t rtpTimestamp;
@property bool isConnected;
@property RAOPState state;
@end

// vim: filetype=objcpp
