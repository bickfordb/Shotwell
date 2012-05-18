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
#include "app/Loop.h"
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

typedef enum {
  kInitialRTSPState = 0,
  kSendingAnnounceRTSPState = 1,
  kAnnouncedRTSPState = 2,
  kSendingSetupRTSPState = 3,
  kSetupRTSPState = 4,
  kSendingRecordRTSPState = 5,
  kRecordRTSPState = 6,
  kSendingVolumeRTSPState = 7,
  kSendingTeardownRTSPState = 8,
  kConnectedRTSPState = 9,
  kSendingFlushRTSPState = 10,
  kErrorRTSPState = 11,
} RTSPState;

@interface RAOPSink : NSObject <AudioSink> {
  Loop *loop_;
  NSData *iv_;
  NSData *key_;
  NSString *address_;
  NSString *challenge_;
  NSString *cid_;
  NSString *pathID_;
  NSString *sessionID_;
  RAOPState raopState_;
  RAOPTimingPacket lastTimingPacket_;
  RAOPVersion version_;
  RTSPState rtspState_;
  aes_context aesContext_;
  bool isPaused_;
  bool isReadingTimeSocket_;
  bool isReading_;
  bool isRequestFlush_;
  bool isRequestVolume_;
  bool isWriting_;
  double volume_;
  id <AudioSource> audioSource_;
  int controlFd_;
  int cseq_; 
  int dataFd_;
  int packetNum_;
  int rtspFd_;
  int timingFd_;
  int64_t lastWriteAt_;
  int64_t seekTo_;
  uint16_t rtpSequence_;
  uint32_t rtpTimestamp_;
  uint32_t ssrc_;
}

- (id)initWithAddress:(NSString *)address port:(uint16_t)port;

@property (retain) Loop *loop;
@property (retain) NSString *address;
@property bool isPaused;
@property (readonly) bool isUDP;
@property double volume;
@property RAOPVersion version;
@property (retain) NSString *challenge;
@property (retain) NSString *cid;
@property (retain) NSString *sessionID;
@property (retain) NSString *pathID;
@property (retain) NSData *iv;
@property (retain) NSData *key;
@property uint16_t rtpSequence;
@property uint32_t rtpTimestamp;
@property uint32_t ssrc;
@property int packetNumber;
@property int64_t lastWriteAt;

- (int64_t)writeAudioDataInterval;
- (int)framesPerPacket;
- (void)flush;
@end

// vim: filetype=objcpp
