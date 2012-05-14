#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <xlocale.h>
#pragma GCC diagnostic ignored "-Wdeprecated-declarations" 

#import "app/AES.h"
#import "app/Base64.h"
#import "app/Log.h"
#import "app/RAOP.h"
#import "app/Random.h"
#import "app/Util.h"

const int kHdrDefaultLength = 1024;
const double kMaxRemoteBufferTime = 4.0;
//const int kSdpDefaultLength = 2048;
const int kSamplesPerFrameV1 = 4096; 
const int kSamplesPerFrameV2 = 352;
const int kBytesPerChannel = 2;
const int kNumChannels = 2;
const int kControlPort = 6001;
const int kTimingPort = 6002;

const int kRTPHeaderSize = 4;
const int kTimingPacketSize = 4 + 28;

const static int kALACHeaderSize = 3;
const static int kV1FrameHeaderSize = 16;  // Used by gen. 1
const static int kAESKeySize = 16;  // Used by gen. 1
const static int kV2FrameHeaderSize = 12;   // Used by gen. 2
static inline void BitsWrite(uint8_t **p, uint8_t d, int blen, int *bpos);
const static int kLoopTimeoutInterval = 10000;

static NSString const *kObserveState = @"ObserveState";
static bool ReadRTPHeader(struct evbuffer *buf, RTPHeader *header);
static bool ReadTimingPacket(struct evbuffer *buffer, RAOPTimingPacket *packet);

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
- (bool)connectRTP;
- (bool)iterate;
- (void)encodePCM:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)encodePacketV1:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)encodePacketV2:(struct evbuffer *)in out:(struct evbuffer *)out;
- (void)encrypt:(uint8_t *)data size:(size_t)size;
- (void)readDataSocket;
- (void)readControlSocket;
- (void)readTimingSocket;
- (void)reset;
- (void)write;

@end

@implementation RAOPSink
@synthesize address = address_;
@synthesize isConnected = isConnected_;
@synthesize isPaused = isPaused_;
@synthesize loop = loop_;
@synthesize packetNumber = packetNumber_;
@synthesize port = port_;
@synthesize raopVersion = raopVersion_;
@synthesize rtpSeq = rtpSeq_;
@synthesize rtpTimestamp = rtpTimestamp_;
@synthesize rtsp = rtsp_;
@synthesize state = state_;

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

- (void)flush {
  INFO(@"flush");
  // FIXME: Determine timestamp from audio source.
  self.rtpTimestamp = 0;
  self.rtsp.rtpTimestamp = self.rtpTimestamp;
  self.rtsp.rtpSequence = self.rtpSeq;
  [self.rtsp flush];
}

- (void)encodePCM:(struct evbuffer *)in out:(struct evbuffer *)out {
  // FIXME use evbuffer_pullup here.
  size_t pcm_len = evbuffer_get_length(in);
  uint8_t pcm[pcm_len];

  evbuffer_remove(in, pcm, pcm_len);
  int bsize = pcm_len / 4;
  uint8_t alac[pcm_len];

  int count = 0;
  int bpos = 0;
  uint8_t *bp = alac;
  BitsWrite(&bp, 1, 3, &bpos); // channel=1, stereo
  BitsWrite(&bp, 0, 4, &bpos); // unknown
  BitsWrite(&bp, 0, 8, &bpos); // unknown
  BitsWrite(&bp, 0, 4, &bpos); // unknown
  if(bsize != kSamplesPerFrameV1)
    BitsWrite(&bp, 1, 1, &bpos); // hassize
  else
    BitsWrite(&bp, 0, 1, &bpos); // hassize
  BitsWrite(&bp, 0, 2, &bpos); // unused
  BitsWrite(&bp, 1, 1, &bpos); // is-not-compressed
  if(bsize!=kSamplesPerFrameV1){
    BitsWrite(&bp, (bsize >> 24) & 0xff, 8, &bpos); // size of data, integer, big endian
    BitsWrite(&bp, (bsize >> 16) & 0xff, 8, &bpos);
    BitsWrite(&bp, (bsize >> 8) & 0xff, 8, &bpos);
    BitsWrite(&bp, bsize & 0xff, 8, &bpos);
  }
  for (int i = 0; i < pcm_len; i += 2) {
    BitsWrite(&bp, pcm[i + 1], 8, &bpos);
    BitsWrite(&bp, pcm[i], 8, &bpos);
  }
  count += pcm_len / 4;
  /* when readable size is less than bsize, fill 0 at the bottom */
  for(int i = 0; i < (bsize - count) * 4; i++){
    BitsWrite(&bp, 0, 8, &bpos);
  }
  if ((bsize - count) > 0) {
    ERROR(@"added %d bytes of silence", (bsize - count) * 4);
  } 
  int out_len = (bpos ? 1 : 0 ) + bp - alac;
  evbuffer_add(out, (void *)alac, out_len);
}

- (void)encrypt:(uint8_t *)data size:(size_t)size {
  uint8_t *buf;
  int i = 0;
  uint8_t nv[kAESKeySize];
  uint8_t *iv = (uint8_t *)(rtsp_.iv.bytes);

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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (context == &kObserveState)  {
    //INFO(@"rtsp state: %d, raop state: %d", (int)rtsp_.state, (int)self.state);
  } else { 
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context]; 
  }
}

- (void)dealloc { 
  [rtsp_ removeObserver:self forKeyPath:@"state" context:&kObserveState];
  [self removeObserver:self forKeyPath:@"state" context:&kObserveState];
  close(fd_);
  close(controlFd_);
  close(timingFd_);
  [loop_ release];
  [rtsp_ release];
  [audioSource_ release];
  [address_ release];
  [super dealloc];
}

- (id)initWithAddress:(NSString *)address port:(uint16_t)port { 
  self = [super init];
  if (self) { 
    seekTo_ = -1;
    self.loop = [Loop loop];
    self.address = address;
    self.port = port;
    self.state = kInitialRAOPState;
    self.raopVersion = kRAOPV1;
    self.raopVersion = kRAOPV2;
    self.rtsp = [[[RTSPClient alloc] initWithLoop:[Loop loop] address:address_ port:port_] autorelease];
    self.rtsp.framesPerPacket = self.raopVersion == kRAOPV1 ? kSamplesPerFrameV1 : kSamplesPerFrameV2;

    [self.rtsp addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:&kObserveState];
    [self addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:&kObserveState];
    isReading_ = false;
    isWriting_ = false;
    aes_set_key(&aesContext_, (uint8_t *)[rtsp_.key bytes], 128); 
    fd_ = -1;
    lastWriteAt_ = 0;
    controlFd_ = -1;
    timingFd_ = -1;
    self.rtpTimestamp = 0;
    self.rtpSeq = 0;
    __block RAOPSink *weakSelf = self;
    [self.loop every:kLoopTimeoutInterval with:^{ [weakSelf iterate]; }];
  }
  return self;
}

- (void)close { 
  if (fd_ >= 0) {
    close(fd_);
    fd_ = -1;
  }
  if (controlFd_ >= 0) {
    close(controlFd_);
    controlFd_ = -1;
  }
  if (timingFd_ >= 0) {
    close(timingFd_);
    timingFd_ = -1;
  }
}

- (void)iterate { 
  if (!self.isPaused) { 
    if (self.rtsp.isPaused) {
      self.rtsp.isPaused = false;
    } else if (self.rtsp.isConnected) { 
      if (self.state == kInitialRAOPState) {
        if ([self connectRTP]) {
          self.state = kConnectedRAOPState;
        } else { 
          ERROR(@"failed to connect to rtp"); 
        }
      } else if (self.state == kConnectedRAOPState 
          && self.rtsp.state != kSendingFlushRTSPState) {
        if (seekTo_ >= 0) {
          if (!isWriting_) { 
            [self.audioSource seek:seekTo_];
            [self flush];
            //[self.rtsp flush];
            seekTo_ = -1;
          }
        } else { 
          [self readDataSocket];
          [self readTimingSocket];
          [self write];
        }
      }
    } 
  } else { 
    if (!self.rtsp.isPaused) {
      self.rtsp.isPaused = true;
    }
    [self close];
  }
}

- (double)volume {
  return self.rtsp.volume;
}

- (void)setVolume:(double)pct { 
  self.rtsp.volume = pct;
}

- (bool)connectRTP { 
  [self close];
  // Data address
  fd_ = socket(AF_INET, (self.raopVersion == kRAOPV1) ? SOCK_STREAM : SOCK_DGRAM, 0);
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(6000);
  if (!inet_aton(address_.UTF8String, &addr.sin_addr)) {
    DEBUG(@"failed to parse address: %@", address_);
  }
  int ret = connect(fd_, (struct sockaddr *)&addr, sizeof(addr));
  if (ret < 0) {
    ERROR(@"unable to connect to data port");
    return false;
  }
  fcntl(fd_, F_SETFL, fcntl(fd_, F_GETFL, 0) | O_NONBLOCK);
  
  if (self.raopVersion == kRAOPV2) {
    {
      // Control socket
      controlFd_ = socket(AF_INET, SOCK_DGRAM, 0);
      struct sockaddr_in controlAddr;
      controlAddr.sin_family = AF_INET;
      controlAddr.sin_port = htons(kControlPort);
      if (!inet_aton(address_.UTF8String, &controlAddr.sin_addr)) {
        DEBUG(@"failed to parse address: %@", address_);
      }
      int ret = connect(controlFd_, (struct sockaddr *)&controlAddr, sizeof(controlAddr));
      if (ret < 0) {
        ERROR(@"unable to connect to control port");
        return false;
      }
      fcntl(controlFd_, F_SETFL, fcntl(fd_, F_GETFL, 0) | O_NONBLOCK); 
    }
    { 
      // Timing socket 
      timingFd_ = socket(AF_INET, SOCK_DGRAM, 0);
      struct sockaddr_in timingAddr;
      timingAddr.sin_family = AF_INET;
      timingAddr.sin_port = htons(kTimingPort);
      if (!inet_aton(address_.UTF8String, &timingAddr.sin_addr)) {
        DEBUG(@"failed to parse address: %@", address_);
      }
      int ret = connect(timingFd_, (struct sockaddr *)&timingAddr, sizeof(timingAddr));
      if (ret < 0) {
        ERROR(@"unable to connect to timing port");
        return false;
      }
      fcntl(timingFd_, F_SETFL, fcntl(fd_, F_GETFL, 0) | O_NONBLOCK); 
    }

  }
  return true;
}

- (void)write {
  if (isWriting_) {
    return;
  }
  if (!audioSource_)
    return;
  if (fd_ < 0) 
    return;
  isWriting_ = true;

  int numFrames = self.rtsp.framesPerPacket;
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

  if (self.raopVersion == kRAOPV1)
    [self encodePacketV1:alac out:rtp];
  else
    [self encodePacketV2:alac out:rtp];
  evbuffer_free(alac);

  __block RAOPSink *weakSelf = self;
  //int64_t sleepInterval = (numFrames * 1000000) / 44100;
  lastWriteAt_ = Now();

  [loop_ writeBuffer:rtp fd:fd_ with:^(int succ) { 
    weakSelf->isWriting_ = false;
    if (succ != 0) {
      DEBUG(@"failed to write: %d", succ);
      [weakSelf reset];
    }
  }];
  self.rtpSeq += 1;
  self.rtpTimestamp += self.raopVersion == kRAOPV1 ? kSamplesPerFrameV1 : kSamplesPerFrameV2;
}

- (void)reset { 
  [self close];
  seekTo_ = -1;
}

- (void)encodePacketV2:(struct evbuffer *)in out:(struct evbuffer *)out {
  uint16_t seq = htons(self.rtpSeq);
  uint16_t ts = htonl(self.rtpTimestamp);
  
  uint32_t ssrc = self.rtsp.ssrc;
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
  int fd = fd_;
  __block RAOPSink *weakSelf = self;
  [loop_ monitorFd:fd_ flags:EV_READ timeout:-1 with:^(Event *e, short flags) {
    if (weakSelf->fd_ < 0) {
      weakSelf->isReading_ = false;
      return;
    }
    char c;
    while (read(fd, &c, 1) > 0);
    [e add:-1];
  }];
}

- (void)readTimingSocket { 
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
  return self.audioSource.isSeeking || self.rtsp.state == kSendingFlushRTSPState || seekTo_ >= 0;
}

- (void)seek:(int64_t)usec { 
  seekTo_ = usec;
}
@end

/* write bits filed data, *bpos=0 for msb, *bpos=7 for lsb
   d=data, blen=length of bits field
   */
static inline void BitsWrite(uint8_t **p, uint8_t d, int blen, int *bpos) {
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
