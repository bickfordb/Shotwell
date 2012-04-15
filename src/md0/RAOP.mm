#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <openssl/bio.h>
#include <openssl/evp.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <xlocale.h>

#import "md0/AES.h"
#import "md0/Base64.h"
#import "md0/Log.h"
#import "md0/RAOP.h"
#import "md0/Random.h"
#import "md0/Util.h"

const int kHdrDefaultLength = 1024;
const double kMaxRemoteBufferTime = 4.0;
//const int kSdpDefaultLength = 2048;
const int kSamplesPerFrame = 4096; // not 1152?
//const int kBytesPerChannel = 2;
//const int kNumChannels = 2;
const int kFrameSizeBytes = 16384;
const static int kALACHeaderSize = 3;
const static int kV1FrameHeaderSize = 16;  // Used by gen. 1
const static int kAESKeySize = 16;  // Used by gen. 1
const static int kV2FrameHeaderSize = 12;   // Used by gen. 2
const static int kRAOPV1 = 1;
const static int kV2RAOPVersion = 2;
const static unsigned char kFrameHeader[] = {    // Used by gen. 1
  0x24, 0x00, 0x00, 0x00,
  0xF0, 0xFF, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00
};
static inline void BitsWrite(uint8_t **p, uint8_t d, int blen, int *bpos);



@implementation RAOPSink
@synthesize audioSource = audioSource_;
@synthesize rtsp = rtsp_;
@synthesize address = address_;
@synthesize port = port_;
@synthesize loop = loop_;

- (void)flush {
  [rtsp_ flush:^(int st) { }];
}

- (void)encodePCM:(struct evbuffer *)in out:(struct evbuffer *)out {
  // FIXME use evbuffer_pullup here.
  uint8_t pcm[kFrameSizeBytes];
  size_t pcm_len = evbuffer_remove(in, pcm, kFrameSizeBytes);
  int bsize = pcm_len / 4;
  size_t max_len = pcm_len + 64;
  uint8_t alac[kFrameSizeBytes + 64];

  uint8_t one[4];
  int count = 0;
  int bpos = 0;
  uint8_t *bp = alac;
  int nodata = 0;
  BitsWrite(&bp,1,3,&bpos); // channel=1, stereo
  BitsWrite(&bp,0,4,&bpos); // unknown
  BitsWrite(&bp,0,8,&bpos); // unknown
  BitsWrite(&bp,0,4,&bpos); // unknown
  if(bsize!=kSamplesPerFrame)
    BitsWrite(&bp,1,1,&bpos); // hassize
  else
    BitsWrite(&bp,0,1,&bpos); // hassize
  BitsWrite(&bp,0,2,&bpos); // unused
  BitsWrite(&bp,1,1,&bpos); // is-not-compressed
  if(bsize!=kSamplesPerFrame){
    BitsWrite(&bp,(bsize>>24)&0xff,8,&bpos); // size of data, integer, big endian
    BitsWrite(&bp,(bsize>>16)&0xff,8,&bpos);
    BitsWrite(&bp,(bsize>>8)&0xff,8,&bpos);
    BitsWrite(&bp,bsize&0xff,8,&bpos);
  }
  for (int i = 0; i < pcm_len; i += 2) {
    BitsWrite(&bp, pcm[i + 1], 8, &bpos);
    BitsWrite(&bp, pcm[i], 8, &bpos);
  }
  count += pcm_len / 4;
  /* when readable size is less than bsize, fill 0 at the bottom */
  for(int i = 0; i < (bsize - count) * 4; i++){
    BitsWrite(&bp,0,8,&bpos);
  }
  if ((bsize - count) > 0) {
    ERROR("added %d bytes of silence", (bsize - count) * 4);
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

- (void)dealloc { 
  NSLog(@"dealloc RAOP");
  close(fd_);
  [loop_ release];
  [rtsp_ release];
  [audioSource_ release];
  [super dealloc];
}

- (id)initWithAddress:(NSString *)address port:(uint16_t)port source:(id <AudioSource>)source { 
  self = [super init];
  if (self) { 
    self.loop = [Loop loop];
    self.address = address;
    self.port = port;
    self.audioSource = source;
    self.rtsp = [[[RTSPClient alloc] initWithLoop:loop_ address:address_ port:port_] autorelease];
    aes_set_key(&aesContext_, (uint8_t *)[rtsp_.key bytes], 128); 
    fd_ = -1;
  }
  return self;
}

- (void)stop { 
  [rtsp_ tearDown:^(int succ) { }];
  close(fd_);
} 

- (void)start { 
  NSLog(@"start RAOP");
  [rtsp_ connect:^(int status) {
    if (status != 200) {
      NSLog(@"failed to connect to RTSP: %d", status);
      return;
    }
    if ([self connectRTP]) {
      [self write];
      [self read];
    }
  }];
}

- (double)volume {
  return 0.0;
}

- (void)setVolume:(double)pct { 
  [rtsp_ sendVolume:pct with:^(int st) { }];
}

- (bool)connectRTP { 
  if (fd_ > 0) {
    close(fd_);
  }
  fd_ = socket(AF_INET, SOCK_STREAM, 0);
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(self.rtsp.dataPort);
  if (!inet_aton(address_.UTF8String, &addr.sin_addr)) {
    NSLog(@"failed to parse address: %@", address_);
  }
  int ret = connect(fd_, (struct sockaddr *)&addr, sizeof(addr));
  if (ret < 0) {
    ERROR("unable to connect to data port");
    return false;
  }
  fcntl(fd_, F_SETFL, fcntl(fd_, F_GETFL, 0) | O_NONBLOCK);
  packetNum_ = 0;
  return true;
}

- (void)write {
  void *rawdata = malloc(kFrameSizeBytes);
  memset(rawdata, 0, kFrameSizeBytes);
  assert(audioSource_);
  [audioSource_ getAudio:(uint8_t *)rawdata length:kFrameSizeBytes];
  struct evbuffer *pcm = evbuffer_new();
  evbuffer_add(pcm, rawdata, kFrameSizeBytes);
  free(rawdata);
  struct evbuffer *alac = evbuffer_new();
  [self encodePCM:pcm out:alac];
  evbuffer_free(pcm);
  struct evbuffer *rtp = evbuffer_new();
  [self encodePacket:alac out:rtp];
  evbuffer_free(alac);
  //NSLog(@"writing %d", (int)evbuffer_get_length(rtp)); 
  void *weakSelf = (void *)self;
  [loop_ writeBuffer:rtp fd:fd_ with:^(bool succ) { 
    if (succ) {
      [((RAOPSink *)weakSelf) write];
    } else {
      ERROR("failed to write packet");
    }
  }];

}

- (void)encodePacket:(struct evbuffer *)in out:(struct evbuffer *)out {
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
  [self encrypt:packet + header_size size:alac_len];
  evbuffer_add(out, packet, packet_len);
}

- (void)read {
  int fd = fd_;
  [loop_ monitorFd:fd_ flags:EV_READ timeout:-1 with:^(Event *e, short flags) {
    char c;
    while (read(fd, &c, 1) > 0);
    [e add:-1];
  }];
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
