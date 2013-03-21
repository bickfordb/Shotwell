#import <Cocoa/Cocoa.h>
#include <event2/event.h>
#include <event2/http.h>
#include <pthread.h>
#include <event2/buffer.h>
#import "LocalLibrary.h"
#import "Loop.h"

extern const int kDaemonDefaultPort;
extern NSString * const kDaemonServiceType;

@class Request;
@interface Daemon : NSObject {

  LocalLibrary *library_;
  struct evhttp *eventHTTP_;
  Loop *loop_;
  NSNetService *netService_;
}

+ (Daemon *)shared;
- (bool)handleHomeRequest:(Request *)r;
- (bool)handleHomeRequest:(Request *)r;
- (bool)handleLibraryRequest:(Request *)r;
- (bool)handleTrackRequest:(Request *)r;
- (void)handleRequest:(Request *)r;
- (id)initWithHost:(NSString *)host port:(int)port library:(LocalLibrary *)library;
@property (retain) NSNetService *netService;

@end
