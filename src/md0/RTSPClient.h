#import <Cocoa/Cocoa.h>
#import "md0/Loop.h"
#import "md0/RTSPRequest.h"
#import "md0/RTSPResponse.h"

typedef void (^OnStatus)(int status); 
typedef void (^OnResponse)(RTSPResponse *response); 

@interface RTSPClient : NSObject {
  Loop *loop_;
  NSData *iv_;
  NSData *key_;
  NSString *address_;
  NSString *challenge_;
  NSString *cid_;
  NSString *sessionID_;
  NSString *urlAbsPath_;
  int cseq_; 
  int fd_;
  uint16_t dataPort_;
  uint16_t port_;
  uint32_t ssrc_;
}

@property (retain) Loop *loop;
@property (retain) NSData *iv;
@property (retain) NSData *key;
@property (retain) NSString *address;
@property (retain) NSString *challenge;
@property (retain) NSString *cid;
@property (retain) NSString *sessionID;
@property (retain) NSString *urlAbsPath;
@property uint16_t dataPort;
@property uint16_t port;

- (id)initWithLoop:(Loop *)loop address:(NSString *)address port:(uint16_t)port;
- (void)announce:(OnStatus)block;
- (void)record:(OnStatus)block;
- (void)setup:(OnStatus)block;
- (void)flush:(OnStatus)block;
- (void)sendVolume:(double)pct with:(OnStatus)block;
- (void)tearDown:(OnStatus)block;
- (void)connect:(OnStatus)block;
- (bool)connectSocket;
- (void)sendRequest:(RTSPRequest *)request with:(OnResponse)block;
- (void)readResponseWithBlock:(OnResponse)block;
- (void)readHeader:(RTSPResponse *)response with:(OnResponse)block;
- (RTSPRequest *)createRequest;
@end

// vim: filetype=objcpp

