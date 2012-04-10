#import <Cocoa/Cocoa.h>
#include <event2/event.h>
#include <event2/dns.h>
#include <event2/http.h>
#include <pthread.h>

@interface HTTPRequest : NSObject {
  NSString *method_; 
  NSString *uri_;
  NSMutableDictionary *headers_;
  NSData *body_;
}
@property (retain, atomic) NSData *body;
@property (retain, atomic) NSString *method;
@property (retain, atomic) NSString *uri;
@property (retain, atomic) NSMutableDictionary *headers;
@end

@interface HTTPResponse : NSObject {
  int status_;
  NSMutableDictionary *headers_;
  NSData *body;
}

@property int status;
@property (retain, atomic) NSMutableDictionary *headers;
@property (retain, atomic) NSData *body;
@end

@class Loop;
@interface Event : NSObject { 
  struct event *event_;
  Loop *loop_;
  id delegate_;
}

@property (assign, nonatomic) id delegate;
@property (readonly) struct event *event;
@property (atomic, retain) Loop *loop;
+ (id)timeoutEventWithLoop:(Loop *)loop interval:(uint64_t)interval;
@end

@interface Loop : NSObject {
  bool running_;
  bool started_;
  struct event_base *base_;
}
@property (readonly, nonatomic) struct event_base *base;  
- (bool)fetchURL:(NSURL *)url withBlock:(void (^)(HTTPResponse *response))onResponse;
- (bool)fetchRequest:(HTTPRequest *)request address:(NSString *)host port:(uint16_t)port withBlock:(void (^)(HTTPResponse *response))onResponse;
@end
