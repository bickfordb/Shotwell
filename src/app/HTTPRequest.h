#import <Cocoa/Cocoa.h>

@interface HTTPRequest : NSObject {
  NSString *method_; 
  NSString *uri_;
  NSMutableDictionary *headers_;
  NSData *body_;
}
@property (retain) NSData *body;
@property (retain) NSString *method;
@property (retain) NSString *uri;
@property (retain) NSMutableDictionary *headers;
@end
