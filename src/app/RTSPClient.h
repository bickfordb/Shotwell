#import <Cocoa/Cocoa.h>
#import "app/Loop.h"
#import "app/RTSPRequest.h"
#import "app/RTSPResponse.h"

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

@interface RTSPClient : NSObject {
  Loop *loop_;
  NSData *iv_;
  NSData *key_;
  NSString *address_;
  NSString *challenge_;
  NSString *cid_;
  NSString *sessionID_;
  NSString *urlAbsPath_;
  bool isPaused_;
  bool isRequestFlush_;
  bool isRequestVolume_;
  double volume_;
  int cseq_; 
  int fd_;
  int framesPerPacket_;
  uint16_t dataPort_;
  uint16_t port_;
  uint32_t ssrc_;
  RTSPState state_;
}

@property (retain) Loop *loop;
@property (retain) NSData *iv;
@property (retain) NSData *key;
@property (retain) NSString *address;
@property (retain) NSString *challenge;
@property (retain) NSString *cid;
@property (retain) NSString *sessionID;
@property (retain) NSString *urlAbsPath;
@property (readonly) bool isConnected;
@property bool isPaused;
@property double volume;
@property int framesPerPacket;
@property uint16_t dataPort;
@property uint16_t port;
@property RTSPState state;
@property uint32_t ssrc;

- (id)initWithLoop:(Loop *)loop address:(NSString *)address port:(uint16_t)port;
- (void)flush;
@end

// vim: filetype=objcpp

