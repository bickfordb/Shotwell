#pragma GCC diagnostic ignored "-Wdeprecated-declarations" 
#include <Security/SecKey.h>
#include <arpa/inet.h>
#include <errno.h>
#include <event2/buffer.h>
#include <openssl/aes.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <stdlib.h>

#import "app/Base64.h"
#import "app/Log.h"
#import "app/Random.h"
#import "app/RTSPClient.h"

static const int kOK = 200;
static const int64_t kLoopTimeoutInterval = 10000;

typedef void (^OnResponse)(RTSPResponse *response);

void RSAEncrypt(uint8_t *text, size_t text_len, uint8_t **out, size_t *out_len);

static NSString * const kUserAgent = @"iTunes/4.6 (Macintosh; U; PPC Mac OS X 10.3)";
static const char * kPublicExponent = "AQAB";
static const char * kPublicKey = "59dE8qLieItsH1WgjrcFRKj6eUWqi+bGLOX1HL3U3GhC/j0Qg90u3sG/1CUtwC5vOYvfDmFI6oSFXi5ELabWJmT2dKHzBJKa3k9ok+8t9ucRqMd6DZHJ2YCCLlDRKSKv6kDqnw4UwPdpOMXziC/AMj3Z/lUVX1G7WSHCAWKf1zNS1eLvqr+boEjXuBOitnZ/bDzPHrTOZz0Dew0uowxf/+sG+NCK3eQJVxqcaJ/vEHKIVd2M+5qL71yJQ+87X6oV3eaYvt3zWZYD6z5vYTcrtij2VZ9Zmni/UAaHqn9JdsBWLUEpVviYnhimNVvYFZeCXg/IdTQ+x4IRdiXNv5hEew==";
static const int kBitRate = 44100;
static const int kBytesPerChannel = 2;
static const int kNumChannels = 2;

void RSAEncrypt(
    uint8_t *text, 
    size_t text_len, 
    uint8_t **out,
    size_t *out_len) { 
  RSA *rsa;
  uint8_t modules[256];
  uint8_t exponent[8];
  int size;
  rsa = RSA_new();
  size = base64_decode(kPublicKey, modules);
  rsa->n = BN_bin2bn(modules, size, NULL);
  size = base64_decode(kPublicExponent, exponent);
  rsa->e = BN_bin2bn(exponent, size, NULL);
  *out_len = RSA_size(rsa);
  *out = (uint8_t *)malloc(*out_len);
  size = RSA_public_encrypt(text_len, text, *out, rsa, RSA_PKCS1_OAEP_PADDING);
  RSA_free(rsa);
}

@interface NSScanner (Headers) 
- (BOOL)scanHeader:(NSString **)key value:(NSString **)value;
@end

@implementation NSScanner (Headers)
- (BOOL)scanHeader:(NSString **)key value:(NSString **)value {
  NSString *k = nil;  
  BOOL ret = NO;
  if ([self scanUpToString:@":" intoString:&k]) { 
    *key = [k stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    int n = MIN(self.string.length, self.scanLocation + 2);
    NSString *v = [self.string substringFromIndex:n];
    *value = [v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    ret = YES;
  } else { 
    *key = nil;
    *value = nil;
  }
  return ret;
}
@end

@interface RTSPClient (Private)
- (RTSPRequest *)createRequest;
- (bool)connectSocket;
- (void)iterate;
- (void)readHeader:(RTSPResponse *)response with:(OnResponse)block;
- (void)readResponseWithBlock:(OnResponse)block;
- (void)sendAnnounce;
- (void)sendFlush;
- (void)sendRecord;
- (void)sendRequest:(RTSPRequest *)request with:(OnResponse)block;
- (void)sendSetup;
- (void)sendTeardown;
- (void)sendVolume;
- (void)reset;
@end

@implementation RTSPClient 
@synthesize address = address_;
@synthesize challenge = challenge_;
@synthesize cid = cid_;
@synthesize dataPort = dataPort_;
@synthesize framesPerPacket = framesPerPacket_;
@synthesize isPaused;
@synthesize iv = iv_;
@synthesize key = key_;
@synthesize loop = loop_;
@synthesize port = port_;
@synthesize rtpSequence = rtpSequence_;
@synthesize rtpTimestamp = rtpTimestamp_;
@synthesize sessionID = sessionID_;
@synthesize ssrc = ssrc_;
@synthesize state = state_;
@synthesize urlAbsPath = urlAbsPath_;

- (void)flush { 
  isRequestFlush_ = true;
}

- (void)dealloc { 
  [address_ release];
  [iv_ release];
  [key_ release];
  [sessionID_ release];
  [loop_ release];
  [challenge_ release];
  [urlAbsPath_ release];
  [cid_ release];
  [super dealloc];
}

- (id)initWithLoop:(Loop *)loop address:(NSString *)address port:(uint16_t)port {
  self = [super init];
  if (self) { 
    fd_ = -1;
    self.isPaused = true;
    volume_ = 0.5;
    self.state = kInitialRTSPState;
    self.loop = loop;
    self.rtpSequence = 0;
    self.rtpTimestamp = 0; 
    self.address = address;
    self.port = port;
    self.dataPort = 6000;
    [self reset];
    __block RTSPClient *weakSelf = self;
    [self.loop every:kLoopTimeoutInterval with:^{ [weakSelf iterate]; }];
  }
  return self;
}

- (void)reset { 
  if (fd_ >= 0) {
    close(fd_);
    fd_ = -1;
  }
  isRequestFlush_ = false;
  isRequestVolume_ = true;
  self.state = kInitialRTSPState;
  self.key = [NSData randomDataWithLength:AES_BLOCK_SIZE];
  self.iv = [NSData randomDataWithLength:AES_BLOCK_SIZE];
  self.framesPerPacket = 0;
  assert(iv_);
  assert(key_);
  self.sessionID = nil;
  RAND_bytes((unsigned char *)&ssrc_, sizeof(ssrc_));
  uint32_t urlKeyBytes;
  RAND_bytes((unsigned char *)&urlKeyBytes, sizeof(urlKeyBytes));
  self.urlAbsPath = [NSString stringWithFormat:@"%u", urlKeyBytes];
  int64_t cidNum;
  RAND_bytes((unsigned char *)&cidNum, sizeof(cidNum));
  self.cid = [NSString stringWithFormat:@"%08X%08X", cidNum >> 32, cidNum];
  cseq_ = 0;
  self.challenge = [[NSData randomDataWithLength:AES_BLOCK_SIZE] encodeBase64];
}

- (void)iterate {
  if (!isPaused_) {
    if (self.state == kInitialRTSPState) {
      if (![self connectSocket]) {
        ERROR(@"failed to setup control socket");
        return;
      }
      [self sendAnnounce];
    } else if (self.state == kAnnouncedRTSPState) {
      [self sendSetup];
    } else if (self.state == kSendingSetupRTSPState) {
    } else if (self.state == kSetupRTSPState) {
      [self sendRecord];
    } else if (self.state == kSendingRecordRTSPState) {
    } else if (self.state == kRecordRTSPState) {
      self.state = kConnectedRTSPState;
    } else if (self.state == kErrorRTSPState) {
      [self reset];
    } else if (self.state == kSendingTeardownRTSPState) {
    } else if (self.state == kSendingVolumeRTSPState) {
    } else if (self.state == kConnectedRTSPState) {
      if (isRequestVolume_) {
        [self sendVolume];
      } else if (isRequestFlush_) {
        [self sendFlush];
      }
    }    
  } else { 
  }
}

- (void)sendRequest:(RTSPRequest *)request with:(void (^)(RTSPResponse *response))block {
  block = Block_copy(block);
  //INFO(@"request: %@", request);
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
   
  [loop_ writeBuffer:buf fd:fd_ with:^(int succ) {
      if (succ == 0) {
        [self readResponseWithBlock:block];
      }
    }];
}

- (void)readResponseWithBlock:(OnResponse)block {
  block = Block_copy(block);
  RTSPResponse *response = [[[RTSPResponse alloc] init] autorelease];
  __block RTSPClient *weakSelf = self;
  [loop_ readLine:fd_ with:^(NSString *line){
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
      //DEBUG(@"response: %@", response);
    }
    block(response);
  };
  x = [x copy];
  __block RTSPClient *weakSelf = self;
  __block Loop *weakLoop = self.loop;
  int fd = fd_;
  [loop_ readLine:fd_ with:^(NSString *line) {
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
        [weakLoop readData:fd length:contentLength with:^(NSData *data) {
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
  request.uri = [NSString stringWithFormat:@"rtsp://%@/%@", address_, urlAbsPath_];
  [request.headers setValue:[NSString stringWithFormat:@"%d", ++cseq_] forKey:@"CSeq"];
  if (sessionID_) 
    [request.headers setValue:sessionID_ forKey:@"Session"];
  if (cid_)
    [request.headers setValue:cid_ forKey:@"Client-Instance"];
  [request.headers setValue:kUserAgent forKey:@"User-Agent"];
  return request;
}

- (void)sendTeardown {
  self.state = kSendingTeardownRTSPState;
  RTSPRequest *request = [self createRequest];
  request.method = @"TEARDOWN";
  __block RTSPClient *weakSelf = self;
  [self sendRequest:request with:^(RTSPResponse *response){
    if (response && response.status == kOK) {
      weakSelf.state = kInitialRTSPState;
    } else { 
      ERROR(@"failed to teardown: %@", response);
      weakSelf.state = kErrorRTSPState;
    }
  }];
}

- (void)sendFlush { 
  self.state = kSendingFlushRTSPState;
  isRequestFlush_ = false;
  RTSPRequest *request = [self createRequest];
  request.method = @"FLUSH";
  [request.headers setValue:@"ntp=0-" forKey:@"Range"];
  [request.headers setValue:[NSString stringWithFormat:@"seq=%d;rtptime=%d",
   (int)self.rtpSequence, (int)self.rtpTimestamp] forKey:@"RTP-Info"];
  __block RTSPClient *weakSelf = self;
  INFO(@"request: %@", request);
  [self sendRequest:request with:^(RTSPResponse *response) {
    INFO(@"response: %@", response);
    weakSelf.state = response.status == kOK ? kConnectedRTSPState : kErrorRTSPState;
  }];
}

- (bool)connectSocket { 
  if (fd_ >= 0) 
    close(fd_);
  fd_ = socket(AF_INET, SOCK_STREAM, 0);
  if (fd_ < 0) {
    ERROR(@"error creating socket");
    return false;
  }
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port_);
  inet_aton(address_.UTF8String, &addr.sin_addr);
  if (connect(fd_, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    ERROR(@"Failed to connect: %d", errno);
    return false;
  }
  fcntl(fd_, F_SETFL, fcntl(fd_, F_GETFL, 0) | O_NONBLOCK);
  return true;
}

- (void)sendAnnounce {
  self.state = kSendingAnnounceRTSPState;
  assert(key_.length == AES_BLOCK_SIZE);
  uint8_t *rsa;
  size_t rsaLen;
  RSAEncrypt((uint8_t *)key_.bytes, key_.length, &rsa, &rsaLen); 
  char *rsa64 = NULL;
  base64_encode(rsa, rsaLen, &rsa64);
  char *iv64 = NULL;
  base64_encode(iv_.bytes, iv_.length, &iv64);

  RTSPRequest *req = [self createRequest];

  char localAddress[INET_ADDRSTRLEN];
  struct sockaddr_in ioaddr;
  socklen_t iolen = sizeof(struct sockaddr);
  getsockname(fd_, (struct sockaddr *)&ioaddr, &iolen);
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
      "a=rsaaeskey:%s\r\n"
      "a=aesiv:%s\r\n",
      self.urlAbsPath.UTF8String,
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
  free(iv64);
  free(rsa64);
  __block RTSPClient *weakSelf = self;
  [self sendRequest:req with:^(RTSPResponse *response) {
    weakSelf.state = response.status == kOK ? kAnnouncedRTSPState : kErrorRTSPState;
  }];
}

- (void)sendSetup { 
  self.state = kSendingSetupRTSPState;
  RTSPRequest *req = [self createRequest];
  req.method = @"SETUP";
  [req.headers setValue:@"RTP/AVP/TCP;unicast;interleaved=0-1;mode=record" forKey:@"Transport"];
  __block RTSPClient *weakSelf = self;
  [self sendRequest:req with:Block_copy(^(RTSPResponse *response) {
    [response.headers enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
      NSString *key0 = (NSString *)key;
      if ([key0 caseInsensitiveCompare:@"session"] == 0) {
        weakSelf.sessionID = val;
      }
    }];
    weakSelf.state = response.status == kOK ? kSetupRTSPState : kErrorRTSPState;
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
  self.state = kSendingRecordRTSPState;
  RTSPRequest *request = [self createRequest];
  request.method = @"RECORD";
  [request.headers setValue:@"ntp=0-" forKey:@"Range"];
  [request.headers setValue:@"seq=0;rtptime=0" forKey:@"RTP-Info"];
  __block RTSPClient *weakSelf = self;
  [self sendRequest:request with:^(RTSPResponse *response) { 
    weakSelf.state = response.status == kOK ? kRecordRTSPState : kErrorRTSPState;
  }];
}

- (bool)isConnected {
  return self.state == kSendingVolumeRTSPState
    || self.state == kSendingFlushRTSPState 
    || self.state == kConnectedRTSPState;
}

- (void)sendVolume {
  self.state = kSendingVolumeRTSPState;
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
  __block RTSPClient *weakSelf = self;
  [self sendRequest:req with:^(RTSPResponse *r) { 
    weakSelf.state = r.status == kOK ? kConnectedRTSPState : kErrorRTSPState;
  }];
}

@end

