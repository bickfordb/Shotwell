#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#include <Security/SecKey.h>
#include <arpa/inet.h>
#include <assert.h>
#include <errno.h>
#include <event2/buffer.h>
#include <fcntl.h>
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xlocale.h>

#import "app/AES.h"
#import "app/Base64.h"
#import "app/BitBuffer.h"
#import "app/Log.h"
#import "app/NSScannerHTTP.h"
#import "app/RAOP.h"
#import "app/Random.h"
#import "app/RSA.h"
#import "app/RTSPRequest.h"
#import "app/RTSPResponse.h"
#import "app/Util.h"

typedef void (^OnResponse)(RTSPResponse *response);

static NSString * const kPublicExponent = @"AQAB";
static NSString * const kPublicKey = @"59dE8qLieItsH1WgjrcFRKj6eUWqi+bGLOX1HL3U3GhC/j0Qg90u3sG/1CUtwC5vOYvfDmFI6oSFXi5ELabWJmT2dKHzBJKa3k9ok+8t9ucRqMd6DZHJ2YCCLlDRKSKv6kDqnw4UwPdpOMXziC/AMj3Z/lUVX1G7WSHCAWKf1zNS1eLvqr+boEjXuBOitnZ/bDzPHrTOZz0Dew0uowxf/+sG+NCK3eQJVxqcaJ/vEHKIVd2M+5qL71yJQ+87X6oV3eaYvt3zWZYD6z5vYTcrtij2VZ9Zmni/UAaHqn9JdsBWLUEpVviYnhimNVvYFZeCXg/IdTQ+x4IRdiXNv5hEew==";
static NSString * const kUserAgent1061 = @"iTunes/10.6.1 (Macintosh; Intel Mac OS X 10.7.3) AppleWebKit/534.53.11";
static NSString * const kUserAgent46 = @"iTunes/4.6 (Macintosh; U; PPC Mac OS X 10.3)";
static NSString const *kObserveState = @"ObserveState";
static bool ReadRTPHeader(struct evbuffer *buf, RTPHeader *header);
static bool ReadTimingPacket(struct evbuffer *buffer, RAOPTimingPacket *packet);
static const double kMaxRemoteBufferTime = 4.0;
static const int kAESKeySize = 16;  // Used by gen. 1
static const int kALACHeaderSize = 3;
static const int kBitRate = 44100;
static const int kBytesPerChannel = 2;
static const int kControlPort = 6001;
static const int kDataPort = 6000;
static const int kHdrDefaultLength = 1024;
static const int kNumChannels = 2;
static const int kOK = 200;
static const int kRTPHeaderSize = 4;
static const int kRTSPPort = 5000;
static const int kSampleRate = 44100;
static const int kSamplesPerFrameV1 = 4096;
static const int kSamplesPerFrameV2 = 352;
static const int kTimingPacketSize = 4 + 28;
static const int kTimingPort = 6002;
static const int kV1FrameHeaderSize = 16;  // Used by gen. 1
static const int kV2FrameHeaderSize = 12;   // Used by gen. 2
static const int64_t kLoopTimeoutInterval = 10000;

static bool ReadTimingPacket(struct evbuffer *buffer, RAOPTimingPacket *packet) {
  if (evbuffer_get_length(buffer) == kTimingPacketSize)
    return false;
  memset(packet, 0, sizeof(RAOPTimingPacket));
  ReadRTPHeader(buffer, &packet->header);
  Pull32(buffer, &packet->zero);
  Pull32(buffer, &packet->referenceTime.sec);
  Pull32(buffer, &packet->referenceTime.frac);
  Pull32(buffer, &packet->receivedTime.sec);
  Pull32(buffer, &packet->receivedTime.frac);
  Pull32(buffer, &packet->sendTime.sec);
  Pull32(buffer, &packet->sendTime.frac);
  return true;
}

static bool ReadRTPHeader(struct evbuffer *buf, RTPHeader *header) {
  bool ret = true;
  memset(header, 0, sizeof(RTPHeader));
  uint8_t a = 0;
  uint8_t b = 0;
  ret = ret && Pull8(buf, &a);
  ret = ret && Pull8(buf, &b);
  header->extension = (a & 0x10) > 0 ? 1 : 0;
  header->source = a & 0x0f;
  header->payloadType = b & 0x7f;
  header->marker = (b & 0x80) > 0 ? 1 : 0;
  ret = ret && Pull16(buf, &header->sequence);
  return ret;
}

static NSString *FormatRTPHeader(RTPHeader *header) {
  return [NSString stringWithFormat:@"{extension: %d, source: %d, marker: %d, payloadType: %d, sequence: %d",
    (int)header->extension,
    (int)header->source,
    (int)header->marker,
    (int)header->payloadType,
    (int)header->sequence];
}

static NSString *FormatNTPTime(NTPTime *t) {
  return [NSString stringWithFormat:@"{sec: %u, frac: %u}", t->sec, t->frac];
}

static NSString *FormatRAOPTimingPacket(RAOPTimingPacket *packet) {
  return [NSString stringWithFormat:
    @"{header: %@, referenceTime: %@, receivedTime: %@, sendTime: %@}",
    FormatRTPHeader(&packet->header),
    FormatNTPTime(&packet->referenceTime),
    FormatNTPTime(&packet->receivedTime),
    FormatNTPTime(&packet->sendTime)];
}

@interface RAOPSink (Private)
- (bool)isRTSPConnected;
- (RTSPRequest *)createRequest;
- (bool)openControl;
- (bool)openData;
- (bool)openRTSP;
- (bool)openTiming;
- (bool)open;
- (void)encodePCM:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)encodePacketV1:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)encodePacketV2:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)iterate;
- (void)iterateRTSP;
- (void)iterateRAOP;
- (void)readControlSocket;
- (void)readDataSocket;
- (void)readHeader:(RTSPResponse *)response with:(OnResponse)block;
- (void)readResponseWithBlock:(OnResponse)block;
- (void)readTimingSocket;
- (void)reset;
- (void)sendAnnounce;
- (void)sendFlush;
- (void)sendRecord;
- (void)sendRequest:(RTSPRequest *)request with:(OnResponse)block;
- (void)sendSetup;
- (void)sendTeardown;
- (void)sendVolume;
- (void)writeAudio;
@end

@implementation RAOPSink
@synthesize address = address_;
@synthesize challenge = challenge_;
@synthesize cid = cid_;
@synthesize isPaused = isPaused_;
@synthesize iv = iv_;
@synthesize key = key_;
@synthesize lastWriteAt = lastWriteAt_;
@synthesize loop = loop_;
@synthesize packetNumber = packetNumber_;
@synthesize pathID = pathID_;
@synthesize rtpSequence = rtpSequence_;
@synthesize rtpTimestamp = rtpTimestamp_;
@synthesize sessionID = sessionID_;
@synthesize ssrc = ssrc_;
@synthesize version = version_;

- (void)encrypt:(uint8_t *)data size:(size_t)size {
  uint8_t *buf;
  int i = 0;
  uint8_t nv[kAESKeySize];
  uint8_t *iv = (uint8_t *)(iv_.bytes);

  memcpy(nv, iv, kAESKeySize);
  while ((i + kAESKeySize) <= size) {
    buf = data + i;
    for (int j = 0; j < kAESKeySize; j++)
      buf[j] ^= nv[j];
    aes_encrypt(&aesContext_, buf, buf);
    memcpy(nv, buf, kAESKeySize);
    i += kAESKeySize;
  }
}

- (int64_t)writeAudioDataInterval {
  return (kUSPerS * self.framesPerPacket) / kSampleRate;
}

- (bool)isUDP {
  return version_ == kRAOPV2;
}

- (int)framesPerPacket {
  return version_ == kRAOPV1 ? kSamplesPerFrameV1 : kSamplesPerFrameV2;

}
- (id <AudioSource>)audioSource {
  return audioSource_;
}

- (void)setAudioSource:(id <AudioSource>)t {
  [self willChangeValueForKey:@"audioSource"];
  @synchronized(self) {
    id <AudioSource> x = audioSource_;
    audioSource_ = [t retain];
    [x release];
    seekTo_ = 0;
  }
  [self didChangeValueForKey:@"audioSource"];
}


- (void)encodePCM:(struct evbuffer *)pcmData out:(struct evbuffer *)out {
  // FIXME use evbuffer_pullup here.
  size_t pcmLen = evbuffer_get_length(pcmData);
  uint8_t *pcm = evbuffer_pullup(pcmData, pcmLen);
  int bsize = pcmLen / 4;
  int count = 0;
  // Encode the PCM data into ALAC.
  // See the libav sources for documentation/further examples about encoding ALAC
  BitBuffer *b = [[[BitBuffer alloc] initWithBuffer:out] autorelease];
  [b write:1 length:3]; // 1: stereo 0: mono
  [b write:0 length:4];
  [b write:0 length:8];
  [b write:0 length:4];
  bool hasSize = bsize != self.framesPerPacket;
  [b write:hasSize ? 1 : 0 length:1];
  [b write:0 length:2];
  [b write:1 length:1];
  // write the size
  if (hasSize) {
    [b write:(bsize >> 24) & 0xff length:8];
    [b write:(bsize >> 16) & 0xff length:8];
    [b write:(bsize >> 8) & 0xff length:8];
    [b write:bsize & 0xff length:8];
  }
  for (int i = 0; i < pcmLen; i += 2) {
    [b write:pcm[i + 1] length:8];
    [b write:pcm[i] length:8];
  }
  count += pcmLen / 4;
  /* when readable size is less than bsize, fill 0 at the bottom */
  for(int i = 0; i < (bsize - count) * 4; i++){
    [b write:0 length:8];
  }
  if ((bsize - count) > 0) {
    ERROR(@"added %d bytes of silence", (bsize - count) * 4);
  }
  evbuffer_drain(pcmData, pcmLen);
  [b flush];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (context == &kObserveState)  {
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (void)dealloc {
  close(dataFd_);
  close(rtspFd_);
  close(controlFd_);
  close(timingFd_);
  [address_ release];
  [audioSource_ release];
  [challenge_ release];
  [cid_ release];
  [iv_ release];
  [key_ release];
  [loop_ release];
  [pathID_ release];
  [sessionID_ release];
  [super dealloc];
}

- (id)initWithAddress:(NSString *)address port:(uint16_t)port {
  self = [super init];
  if (self) {
    controlFd_ = -1;
    dataFd_ = -1;
    rtspFd_ = - 1;
    timingFd_ = -1;
    volume_ = 0.5;
    // v2 doesn't work for now =(
    version_ = kRAOPV1;
    self.loop = [Loop loop];
    self.address = address;
    [self reset];
    __block RAOPSink *weakSelf = self;
    [self.loop every:kLoopTimeoutInterval with:^{ [weakSelf iterate]; }];
  }
  return self;
}

- (void)closeData {
  if (dataFd_ >= 0) {
    INFO(@"closing data fd: %d", dataFd_);
    close(dataFd_);
    dataFd_ = -1;
  }
}

- (void)closeControl {
  if (controlFd_ >= 0) {
    close(controlFd_);
    controlFd_ = -1;
  }
}
- (void)closeTiming {
  if (timingFd_ >= 0) {
    close(timingFd_);
    timingFd_ = -1;
  }
}
- (void)closeRTSP {
  if (rtspFd_ >= 0) {
    close(rtspFd_);
    rtspFd_ = -1;
  }
}

- (void)iterateRAOP {
  if (!isPaused_) {
    if (controlFd_ < 0) {
      [self openControl];
    }
    if (timingFd_ < 0) {
      [self openTiming];
    }

    if (rtspState_ == kConnectedRTSPState) {
      if (raopState_ == kInitialRAOPState) {
        [self openData];
        raopState_ = kConnectedRAOPState;
      } else {
        if (seekTo_ >= 0) {
          if (!isWriting_) {
            [self.audioSource seek:seekTo_];
            self.rtpTimestamp = 0;
            [self flush];
            seekTo_ = -1;
          }
        } else {
          [self readDataSocket];
          [self readTimingSocket];
          [self writeAudio];
        }
      }
    }
  } else {
    [self closeData];
    [self closeControl];
    [self closeTiming];
    raopState_ = kInitialRAOPState;
  }
}

- (void)iterate {
  [self iterateRTSP];
  [self iterateRAOP];
}

- (bool)openData {
  DEBUG(@"connecting RTP");
  [self closeData];
  // Data address
  dataFd_ = socket(AF_INET, self.isUDP ? SOCK_DGRAM : SOCK_STREAM, 0);
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(kDataPort);
  if (!inet_aton(address_.UTF8String, &addr.sin_addr)) {
    DEBUG(@"failed to parse address: %@", address_);
  }
  int ret = connect(dataFd_, (struct sockaddr *)&addr, sizeof(addr));
  if (ret < 0) {
    ERROR(@"unable to connect to data port");
    return false;
  }
  fcntl(dataFd_, F_SETFL, fcntl(dataFd_, F_GETFL, 0) | O_NONBLOCK);
  DEBUG(@"connected");
  return true;
}

- (bool)openTiming {
  INFO(@"binding timing");
  if (self.version == kRAOPV1) {
    return true;
  }
  // Timing socket
  timingFd_ = socket(AF_INET, SOCK_DGRAM, 0);
  fcntl(timingFd_, F_SETFL, fcntl(timingFd_, F_GETFL, 0) | O_NONBLOCK);
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(kTimingPort);
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  int opt = 1;
  if (setsockopt(timingFd_, SOL_SOCKET, SO_REUSEADDR, (const void *)&opt, sizeof(opt))) {
    INFO(@"failed to set sockopt");
  }
  int ret = bind(timingFd_, (struct sockaddr *)&addr, sizeof(addr));
  if (ret < 0) {
    ERROR(@"failed to bind: %d", ret);
    return false;
  }
  INFO(@"done binding timing");
  return true;
}

- (bool)openControl {
  INFO(@"binding control");
  if (self.version == kRAOPV1) {
    return true;
  }
  // Control socket
  controlFd_ = socket(AF_INET, SOCK_DGRAM, 0);
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(kControlPort);
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  fcntl(controlFd_, F_SETFL, fcntl(controlFd_, F_GETFL, 0) | O_NONBLOCK);
  int opt = 1;
  if (setsockopt(timingFd_, SOL_SOCKET, SO_REUSEADDR, (const void *)&opt, sizeof(opt))) {
    INFO(@"failed to set sockopt");
  }
  int ret = bind(controlFd_, (struct sockaddr *)&addr, sizeof(addr));
  if (ret < 0) {
    ERROR(@"failed to bind: %d", ret);
    return false;
  }
  INFO(@"done binding control");
  return true;
}



- (void)writeAudio {
  if (isWriting_) {
    return;
  }
  if (!audioSource_)
    return;
  if (dataFd_ < 0)
    return;
  if (self.version == kRAOPV2 &&
     (self.lastWriteAt + self.writeAudioDataInterval) > Now()) {
    return;
  }
  isWriting_ = true;

  int numFrames = self.framesPerPacket;
  int frameLen = numFrames * kNumChannels * kBytesPerChannel;
  void *rawdata = malloc(frameLen);
  memset(rawdata, 0, frameLen);
  assert(audioSource_);
  [audioSource_ getAudio:(uint8_t *)rawdata length:frameLen];
  struct evbuffer *pcm = evbuffer_new();
  evbuffer_add(pcm, rawdata, frameLen);
  free(rawdata);
  struct evbuffer *alac = evbuffer_new();
  [self encodePCM:pcm out:alac];
  evbuffer_free(pcm);
  struct evbuffer *rtp = evbuffer_new();

  if (self.version == kRAOPV1)
    [self encodePacketV1:alac out:rtp];
  else
    [self encodePacketV2:alac out:rtp];
  evbuffer_free(alac);

  __block RAOPSink *weakSelf = self;
  self.lastWriteAt = Now();
  rtpSequence_ += 1;
  rtpTimestamp_ += self.framesPerPacket;
  [loop_ writeBuffer:rtp fd:dataFd_ with:^(int succ) {
    weakSelf->isWriting_ = false;
    if (succ != 0) {
      DEBUG(@"failed to write: %d", succ);
      [weakSelf reset];
    }
  }];
}


- (void)encodePacketV2:(struct evbuffer *)in out:(struct evbuffer *)out {
  uint16_t seq = htons(self.rtpSequence);
  uint16_t ts = htonl(self.rtpTimestamp);

  uint32_t ssrc = self.ssrc;
  // 12 byte header
  uint8_t header[] = {
    0x80,
    packetNumber_ ? 0x60 : 0xe0,
    // bytes 2-3 are the rtp sequence
    (seq >> 8) & 0xff,
    seq & 0xff,
    // bytes 4-7 are the rtp timestamp
    (ts >> 24) & 0xff,
    (ts >> 16) & 0xff,
    (ts >> 8) & 0xff,
    ts & 0xff,
    // 8-11 are are the ssrc
    (ssrc >> 24) & 0xff,
    (ssrc >> 16) & 0xff,
    (ssrc >> 8) & 0xff,
    ssrc & 0xff};
  const int header_size = kV2FrameHeaderSize;
  int alac_len = evbuffer_get_length(in);
  uint8_t alac[alac_len];
  evbuffer_remove(in, alac, alac_len);
  size_t packet_len = alac_len + header_size;
  uint8_t packet[packet_len];
  //uint16_t len = alac_len + header_size - 4;
  //header[2] = len >> 8;
  //header[3] = len & 0xff;
  memcpy(packet, header, header_size);
  memcpy(packet + header_size, alac, alac_len);
  [self encrypt:packet + header_size size:alac_len];
  evbuffer_add(out, packet, packet_len);
}

- (void)encodePacketV1:(struct evbuffer *)in out:(struct evbuffer *)out {
  uint8_t header[] = {
    0x24, 0x00, 0x00, 0x00,
    0xF0, 0xFF, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
  };
  const int header_size = 16;
  int alac_len = evbuffer_get_length(in);
  uint8_t alac[alac_len];
  evbuffer_remove(in, alac, alac_len);
  size_t packet_len = alac_len + 16;
  uint8_t packet[packet_len];
  uint16_t len = alac_len + header_size - 4;
  header[2] = len >> 8;
  header[3] = len & 0xff;
  memcpy(packet, header, header_size);
  memcpy(packet + header_size, alac, alac_len);
  [self encrypt:packet + header_size size:alac_len];
  evbuffer_add(out, packet, packet_len);
}

- (void)readDataSocket {
  if (isReading_)
    return;
  isReading_ = true;
  int fd = dataFd_;
  __block RAOPSink *weakSelf = self;
  [loop_ monitorFd:dataFd_ flags:EV_READ timeout:-1 with:^(Event *e, short flags) {
    if (weakSelf->dataFd_ < 0) {
      weakSelf->isReading_ = false;
      return;
    }
    char c;
    while (read(fd, &c, 1) > 0);
    [e add:-1];
  }];
}

- (void)readTimingSocket {
  if (self.version != kRAOPV2) {
    return;
  }

  if (isReadingTimeSocket_) {
    return;
  }
  isReadingTimeSocket_ = true;
  __block RAOPSink *weakSelf = self;
  EventBuffer *b = [EventBuffer eventBuffer];
  [loop_ monitorFd:timingFd_ flags:EV_READ timeout:1000 with:^(Event *e, short flags) {
    if (weakSelf->timingFd_ < 0) {
      return;
    }
    int n = kTimingPacketSize - evbuffer_get_length(b.buffer);
    if (n > 0) {
      int amt = evbuffer_read(b.buffer, weakSelf->timingFd_, n);
      (void)amt;
    }
    if (evbuffer_get_length(b.buffer) == kTimingPacketSize) {
      ReadTimingPacket(b.buffer, &weakSelf->lastTimingPacket_);
      INFO(@"got timing packet: %@", FormatRAOPTimingPacket(&weakSelf->lastTimingPacket_));
    }
    [e add:-1];
  }];
}

- (int64_t)elapsed {
  return self.audioSource.elapsed;
}

- (int64_t)duration {
  return self.audioSource.duration;
}

- (bool)isSeeking {
  return self.audioSource.isSeeking || rtspState_ == kSendingFlushRTSPState || seekTo_ >= 0;
}

- (void)seek:(int64_t)usec {
  seekTo_ = usec;
}

- (void)flush {
  isRequestFlush_ = true;
}


- (void)reset {

  [self closeData];
  [self closeControl];
  [self closeTiming];
  [self closeRTSP];
  seekTo_ = -1;
  isReading_ = false;
  isWriting_ = false;
  isRequestFlush_ = false;
  isRequestVolume_ = true;
  rtspState_ = kInitialRTSPState;
  raopState_ = kInitialRAOPState;
  self.key = [NSData randomDataWithLength:AES_BLOCK_SIZE];
  self.iv = [NSData randomDataWithLength:AES_BLOCK_SIZE];
  aes_set_key(&aesContext_, (uint8_t *)[key_ bytes], 128);
  RAND_bytes((uint8_t *)&rtpSequence_, sizeof(rtpSequence_));
  RAND_bytes((uint8_t *)&rtpTimestamp_, sizeof(rtpTimestamp_));
  rtpSequence_ = 0;
  rtpTimestamp_ = 0;
  assert(iv_);
  assert(key_);
  self.sessionID = nil;
  RAND_bytes((unsigned char *)&ssrc_, sizeof(ssrc_));
  uint32_t path;
  RAND_bytes((unsigned char *)&path, sizeof(path));
  self.pathID = [NSString stringWithFormat:@"%lu", path];
  int64_t cidNum;
  RAND_bytes((unsigned char *)&cidNum, sizeof(cidNum));
  self.cid = [NSString stringWithFormat:@"%08X%08X", cidNum >> 32, cidNum];
  cseq_ = 0;
  self.challenge = [[NSData randomDataWithLength:AES_BLOCK_SIZE] encodeBase64];
}

- (void)iterateRTSP {
  if (!isPaused_) {
    if (rtspState_ == kInitialRTSPState) {
      if (![self openRTSP]) {
        ERROR(@"failed to setup control socket");
        return;
      }
      [self sendAnnounce];
    } else if (rtspState_ == kAnnouncedRTSPState) {
      [self sendSetup];
    } else if (rtspState_ == kSendingSetupRTSPState) {
    } else if (rtspState_ == kSetupRTSPState) {
      [self sendRecord];
    } else if (rtspState_ == kSendingRecordRTSPState) {
    } else if (rtspState_ == kRecordRTSPState) {
      rtspState_ = kConnectedRTSPState;
    } else if (rtspState_ == kErrorRTSPState) {
      [self reset];
    } else if (rtspState_ == kSendingTeardownRTSPState) {
    } else if (rtspState_ == kSendingVolumeRTSPState) {
    } else if (rtspState_ == kConnectedRTSPState) {
      if (isRequestVolume_) {
        [self sendVolume];
      } else if (isRequestFlush_) {
        [self sendFlush];
      }
    }
  } else {
    if (rtspState_ == kConnectedRTSPState) {
      [self sendTeardown];
    }
  }
}

- (void)sendRequest:(RTSPRequest *)request with:(void (^)(RTSPResponse *response))block {
  block = Block_copy(block);
  INFO(@"request: %@", request);
  struct evbuffer *buf = evbuffer_new();
  evbuffer_add_printf(buf, "%s %s RTSP/1.0\r\n", request.method.UTF8String,
      request.uri.UTF8String);
  int len = request.body ? request.body.length : 0;
  [request.headers
    setValue:[NSString stringWithFormat:@"%d", len]
    forKey:@"Content-Length"];
  [request.headers enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
    evbuffer_add_printf(buf,
        "%s: %s\r\n",
        ((NSString *)key).UTF8String,
        ((NSString *)val).UTF8String);
  }];
  evbuffer_add_printf(buf, "\r\n");
  evbuffer_add(buf, request.body.bytes, request.body.length);

  [loop_ writeBuffer:buf fd:rtspFd_ with:^(int succ) {
      if (succ == 0) {
        [self readResponseWithBlock:block];
      }
    }];
}

- (void)readResponseWithBlock:(OnResponse)block {
  block = Block_copy(block);
  RTSPResponse *response = [[[RTSPResponse alloc] init] autorelease];
  __block RAOPSink *weakSelf = self;
  [loop_ readLine:rtspFd_ with:^(NSString *line){
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSScanner *scanner = [NSScanner scannerWithString:line];
    NSString *protocol = nil;
    [scanner scanUpToString:@" " intoString:&protocol];
    int status = 0;
    [scanner scanInt:&status];
    response.status = status;
    [weakSelf readHeader:response with:block];
  }];
}

- (void)readHeader:(RTSPResponse *)response with:(OnResponse)block {
  block = [block copy];
  OnResponse x = ^(RTSPResponse *r) {
    if (response.status != kOK) {
      ERROR(@"error response: %@", response);
    } else {
      DEBUG(@"response: %@", response);
    }
    block(response);
  };
  x = [x copy];
  __block RAOPSink *weakSelf = self;
  int fd = rtspFd_;
  [loop_ readLine:rtspFd_ with:^(NSString *line) {
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSScanner *scanner = [NSScanner scannerWithString:line];
    if (line.length) {
      NSString *key = nil;
      NSString *value = nil;
      [scanner scanHeader:&key value:&value];
      if (key)
        [response.headers setValue:value forKey:key];
      [weakSelf readHeader:response with:block];
    } else {
      NSString *c = [response.headers objectForKey:@"Content-Length"];
      int contentLength = c ? c.intValue : 0;
      if (contentLength) {
        [weakSelf.loop readData:fd length:contentLength with:^(NSData *data) {
          response.body = data;
          x(response);
        }];
      } else {
        x(response);
      }
    }
  }];
}

- (RTSPRequest *)createRequest {
  RTSPRequest *request = [[[RTSPRequest alloc] init] autorelease];
  request.uri = [NSString stringWithFormat:@"rtsp://%@/%@", address_, pathID_];
  [request.headers setValue:[NSString stringWithFormat:@"%d", ++cseq_] forKey:@"CSeq"];
  if (sessionID_)
    [request.headers setValue:sessionID_ forKey:@"Session"];
  if (cid_)
    [request.headers setValue:cid_ forKey:@"Client-Instance"];
  [request.headers setValue:kUserAgent1061 forKey:@"User-Agent"];
  return request;
}

- (void)sendTeardown {
  rtspState_ = kSendingTeardownRTSPState;
  RTSPRequest *request = [self createRequest];
  request.method = @"TEARDOWN";
  __block RAOPSink *weakSelf = self;
  [self sendRequest:request with:^(RTSPResponse *response){
    if (response && response.status == kOK) {
      [weakSelf closeRTSP];
      weakSelf->rtspState_ = kInitialRTSPState;
    } else {
      ERROR(@"failed to teardown: %@", response);
      weakSelf->rtspState_ = kErrorRTSPState;
    }
  }];
}

- (void)sendFlush {
  rtspState_ = kSendingFlushRTSPState;
  isRequestFlush_ = false;
  RTSPRequest *request = [self createRequest];
  request.method = @"FLUSH";
  [request.headers setValue:@"ntp=0-" forKey:@"Range"];
  NSString *rtpInfo = [NSString stringWithFormat:@"seq=%hu;rtptime=%lu",
   rtpSequence_, rtpTimestamp_];
  [request.headers setValue:rtpInfo forKey:@"RTP-Info"];
  __block RAOPSink *weakSelf = self;
  [self sendRequest:request with:^(RTSPResponse *response) {
    weakSelf->rtspState_ = response.status == kOK ? kConnectedRTSPState : kErrorRTSPState;
  }];
}

- (bool)openRTSP {
  INFO(@"open rtsp");
  if (rtspFd_ >= 0) {
    WARN(@"rtsp already open");
    close(rtspFd_);
  }
  rtspFd_ = socket(AF_INET, SOCK_STREAM, 0);
  if (rtspFd_ < 0) {
    ERROR(@"error creating socket");
    return false;
  }
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(kRTSPPort);
  inet_aton(address_.UTF8String, &addr.sin_addr);
  if (connect(rtspFd_, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    ERROR(@"Failed to connect: %d", errno);
    return false;
  }
  fcntl(rtspFd_, F_SETFL, fcntl(rtspFd_, F_GETFL, 0) | O_NONBLOCK);
  return true;
}

- (void)sendAnnounce {
  rtspState_ = kSendingAnnounceRTSPState;
  assert(key_.length == AES_BLOCK_SIZE);
  NSData *rsa = RSAEncrypt(key_, kPublicKey, kPublicExponent);
  NSString *rsa64 = rsa.encodeBase64;
  NSString *iv64 = iv_.encodeBase64;
  RTSPRequest *req = [self createRequest];
  char localAddress[INET_ADDRSTRLEN];
  struct sockaddr_in ioaddr;
  socklen_t iolen = sizeof(struct sockaddr);
  getsockname(rtspFd_, (struct sockaddr *)&ioaddr, &iolen);
  inet_ntop(AF_INET, &(ioaddr.sin_addr), localAddress, INET_ADDRSTRLEN);

  req.method = @"ANNOUNCE";
  req.body = [[NSString stringWithFormat:
      @"v=0\r\n"
      "o=iTunes %s 0 IN IP4 %s\r\n"
      "s=iTunes\r\n"
      "c=IN IP4 %s\r\n"
      "t=0 0\r\n"
      "m=audio 0 RTP/AVP 96\r\n"
      "a=rtpmap:96 AppleLossless\r\n"
      "a=fmtp:96 %d 0 %d 40 10 14 %d 255 0 0 %d\r\n"
      "a=rsaaeskey:%@\r\n"
      "a=aesiv:%@\r\n",
      self.pathID.UTF8String,
      localAddress,
      self.address.UTF8String,
      self.framesPerPacket,
      kBytesPerChannel * 8,
      kNumChannels,
      kBitRate,
      rsa64,
      iv64] dataUsingEncoding:NSUTF8StringEncoding];

  [req.headers setValue:@"application/sdp" forKey:@"Content-Type"];
  [req.headers setValue:challenge_ forKey:@"Apple-Challenge"];
  __block RAOPSink *weakSelf = self;
  [self sendRequest:req with:^(RTSPResponse *response) {
    weakSelf->rtspState_ = response.status == kOK ? kAnnouncedRTSPState : kErrorRTSPState;
  }];
}

- (void)sendSetup {
  rtspState_ = kSendingSetupRTSPState;
  RTSPRequest *req = [self createRequest];
  req.method = @"SETUP";
  if (!self.isUDP) {
    [req.headers setValue:@"RTP/AVP/TCP;unicast;interleaved=0-1;mode=record" forKey:@"Transport"];
  } else {
    [req.headers setValue:@"RTP/AVP/UDP;unicast;interleaved=0-1;mode=record;control_port=6001;timing_port=6002" forKey:@"Transport"];
  }
  __block RAOPSink *weakSelf = self;
  [self sendRequest:req with:Block_copy(^(RTSPResponse *response) {
    [response.headers enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
      NSString *key0 = (NSString *)key;
      if ([key0 caseInsensitiveCompare:@"session"] == 0) {
        weakSelf.sessionID = val;
      }
    }];
    weakSelf->rtspState_ = response.status == kOK ? kSetupRTSPState : kErrorRTSPState;
  })];
}

- (void)setVolume:(double)volume {
  volume_ = volume;
  isRequestVolume_ = true;
}

- (double)volume {
  return volume_;
}

- (void)sendRecord {
  rtspState_ = kSendingRecordRTSPState;
  RTSPRequest *request = [self createRequest];
  request.method = @"RECORD";
  [request.headers setValue:@"ntp=0-" forKey:@"Range"];
  [request.headers setValue:
    [NSString stringWithFormat:@"seq=%hu;rtptime=%lu", rtpSequence_, rtpTimestamp_]
    forKey:@"RTP-Info"];
  __block RAOPSink *weakSelf = self;
  [self sendRequest:request with:^(RTSPResponse *response) {
    weakSelf->rtspState_ = response.status == kOK ? kRecordRTSPState : kErrorRTSPState;
  }];
}

- (bool)isRTSPConnected {
  return rtspState_ == kSendingVolumeRTSPState
    || rtspState_ == kSendingFlushRTSPState
    || rtspState_ == kConnectedRTSPState;
}

- (void)sendVolume {
  rtspState_ = kSendingVolumeRTSPState;
  isRequestVolume_ = false;
  // value appears to be in some sort of decibel value
  // 0 is max, -144 is min
  double volume = 0;
  if (volume_ < 0.01)
    volume = -144;
  else {
    double max = 0;
    double min = -30;
    volume = (volume_ * (max - min)) + min;
  }

  RTSPRequest *req = [self createRequest];
  req.method = @"SET_PARAMETER";

  [req.headers setValue:@"text/parameters" forKey:@"Content-Type"];
  req.body = [[NSString stringWithFormat:@"volume: %.6f\r\n", volume] dataUsingEncoding:NSUTF8StringEncoding];
  __block RAOPSink *weakSelf = self;
  [self sendRequest:req with:^(RTSPResponse *r) {
    weakSelf->rtspState_ = r.status == kOK ? kConnectedRTSPState : kErrorRTSPState;
  }];
}

@end

