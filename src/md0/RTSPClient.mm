#include <arpa/inet.h>
#include <openssl/aes.h>
#include <openssl/rsa.h>
#include <event2/buffer.h>
#include <errno.h>
#include <openssl/rand.h>
#include <stdlib.h>

#import "md0/Base64.h"
#import "md0/Log.h"
#import "md0/RTSPClient.h"
#import "md0/RTSPClient.h"
#import "md0/Random.h"

static const int kBytesPerChannel = 2;
static const int kNumChannels = 2;
static const int kBitRate = 44100;

static NSString * const kUserAgent = @"iTunes/4.6 (Macintosh; U; PPC Mac OS X 10.3)";
static const char * kPublicExponent = "AQAB";
static const char * kPublicKey = "59dE8qLieItsH1WgjrcFRKj6eUWqi+bGLOX1HL3U3GhC/j0Qg90u3sG/1CUtwC5vOYvfDmFI6oSFXi5ELabWJmT2dKHzBJKa3k9ok+8t9ucRqMd6DZHJ2YCCLlDRKSKv6kDqnw4UwPdpOMXziC/AMj3Z/lUVX1G7WSHCAWKf1zNS1eLvqr+boEjXuBOitnZ/bDzPHrTOZz0Dew0uowxf/+sG+NCK3eQJVxqcaJ/vEHKIVd2M+5qL71yJQ+87X6oV3eaYvt3zWZYD6z5vYTcrtij2VZ9Zmni/UAaHqn9JdsBWLUEpVviYnhimNVvYFZeCXg/IdTQ+x4IRdiXNv5hEew==";

static OnResponse ToStatus(OnStatus block);
void RSAEncrypt(uint8_t *text, size_t text_len, uint8_t **out, size_t *out_len);

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
  unsigned char res[RSA_size(rsa)];
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

@implementation RTSPClient 
@synthesize address = address_;
@synthesize challenge = challenge_;
@synthesize cid = cid_;
@synthesize dataPort = dataPort_;
@synthesize framesPerPacket = framesPerPacket_;
@synthesize iv = iv_;
@synthesize key = key_;
@synthesize loop = loop_;
@synthesize port = port_;
@synthesize sessionID = sessionID_;
@synthesize urlAbsPath = urlAbsPath_;

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
    self.loop = loop;
    self.address = address;
    self.port = port;
    self.dataPort = 6000;
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
  return self;
}

- (void)sendRequest:(RTSPRequest *)request with:(void (^)(RTSPResponse *response))block {
  block = Block_copy(block);
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
   
  // write buffer
  //NSLog(@"sending request: %@", [[NSString alloc] initWithCString:(const char *)evbuffer_pullup(buf, evbuffer_get_length(buf)) length:evbuffer_get_length(buf)]);

  [loop_ writeBuffer:buf fd:fd_ with:^(int succ) {
      if (succ == 0) {
        [self readResponseWithBlock:block];
      }
    }];
}

- (void)readResponseWithBlock:(OnResponse)block {
  block = Block_copy(block);
  RTSPResponse *response = [[[RTSPResponse alloc] init] autorelease];
  void *weakSelf = (void *)self;
  [loop_ readLine:fd_ with:^(NSString *line){
    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSScanner *scanner = [NSScanner scannerWithString:line];
    NSString *protocol = nil;
    [scanner scanUpToString:@" " intoString:&protocol];
    int status = 0;
    [scanner scanInt:&status];
    response.status = status;
    [((RTSPClient *)weakSelf) readHeader:response with:block];
  }];
}

- (void)readHeader:(RTSPResponse *)response with:(OnResponse)block {
  void *weakLoop = (void *)loop_;
  void *weakSelf = (void *)self;
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
      [((RTSPClient *)weakSelf) readHeader:response with:block];
    } else {
      NSString *c = [response.headers objectForKey:@"Content-Length"];
      int contentLength = c ? c.intValue : 0;
      if (contentLength) { 
        [((Loop *)weakLoop) readData:fd length:contentLength with:^(NSData *data) {
          response.body = data;
          block(response);
        }];
      } else { 
        block(response);
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


- (void)tearDown:(OnStatus)block {
  block = [block copy];
  RTSPRequest *request = [self createRequest];
  request.method = @"TEARDOWN";
  [self sendRequest:request with:ToStatus(block)];
}

- (void)flush:(OnStatus)block {
  block = Block_copy(block);
  RTSPRequest *request = [self createRequest];
  request.method = @"FLUSH";
  [request.headers setValue:@"ntp=0-" forKey:@"Range"];
  [request.headers setValue:[NSString stringWithFormat:@"seq=%d;rtptime=%d", 0, 0] forKey:@"RTP-Info"];
  [self sendRequest:request with:ToStatus(block)];
}

- (bool)connectSocket { 
  if (fd_ >= 0) 
    close(fd_);
  fd_ = socket(AF_INET, SOCK_STREAM, 0);
  if (fd_ < 0) {
    ERROR("error creating socket");
    return false;
  }
  struct sockaddr_in addr;
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port_);
  inet_aton(address_.UTF8String, &addr.sin_addr);
  if (connect(fd_, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
    ERROR("Failed to connect: %d", errno);
    return false;
  }
  fcntl(fd_, F_SETFL, fcntl(fd_, F_GETFL, 0) | O_NONBLOCK);
  return true;
}

- (void)connect:(OnStatus)block {
  block = [block copy];
  if (![self connectSocket]) {
    ERROR("failed to setup control socket");
    block(-1);
    return;
  }
  [self announce:^(int st) {
    if (st != 200) { 
      ERROR("Failed to announce");
      block(st);
      return;
    }
    [self setup:^(int st) { 
      if (st != 200) {
        ERROR("Failed to setup");
        block(st);
        return;
      }
      [self record:^(int st) {
        if (st != 200) {
          ERROR("Failed to record");
          block(st);
          return;
        } else { 
          block(st);
        }
      }];
    }];
  }];
} 

- (void)announce:(OnStatus)block {
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
  [self sendRequest:req with:ToStatus(block)]; 
}

- (void)setup:(OnStatus)block { 
  RTSPRequest *req = [self createRequest];
  req.method = @"SETUP";
  [req.headers setValue:@"RTP/AVP/TCP;unicast;interleaved=0-1;mode=record" forKey:@"Transport"];
  [self sendRequest:req with:Block_copy(^(RTSPResponse *response) {
    [response.headers enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
      if ([((NSString *)key) caseInsensitiveCompare:@"session"] == 0) 
        self.sessionID = (NSString *)val;
        //NSLog(@"got session ID: %@", self.sessionID);
    }];
    block(response ? response.status : -1);
  })];
}

- (void)record:(OnStatus)block { 
  RTSPRequest *request = [self createRequest];
  request.method = @"RECORD";
  [request.headers setValue:@"ntp=0-" forKey:@"Range"];
  [request.headers setValue:@"seq=0;rtptime=0" forKey:@"RTP-Info"];
  [self sendRequest:request with:ToStatus(block)];
}

- (void)sendVolume:(double)pct with:(OnStatus)block { 
  if (fd_ <= 0) {
    return;
  }
  // value appears to be in some sort of decibel value 
  // 0 is max, -144 is min  
  double volume = 0;  
  if (pct < 0.01) 
    volume = -144;
  else {
    double max = 0;
    double min = -30;
    volume = (pct * (max - min)) + min;
  }

  RTSPRequest *req = [self createRequest];
  req.method = @"SET_PARAMETER";

  [req.headers setValue:@"text/parameters" forKey:@"Content-Type"];
  req.body = [[NSString stringWithFormat:@"volume: %.6f\r\n", volume] dataUsingEncoding:NSUTF8StringEncoding];
  [self sendRequest:req with:ToStatus(block)];
}

@end

static OnResponse ToStatus(OnStatus block) {
   block = [block copy];
   return Block_copy(^(RTSPResponse *response) {
      //NSLog(@"got response: %@", response);
      block(response ? response.status : 0);
   });
}

