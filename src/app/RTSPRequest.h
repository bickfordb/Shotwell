#import <Cocoa/Cocoa.h>

@interface RTSPRequest : NSObject {
  NSString *method_;
  NSString *uri_;
  NSMutableDictionary *headers_;
  NSData *body_;
}
@property (retain) NSString *method;
@property (retain) NSString *uri;
@property (retain) NSData *body;
@property (retain) NSMutableDictionary *headers;
@end

// vim: filetype=objcpp
