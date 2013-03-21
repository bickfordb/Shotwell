#import <Cocoa/Cocoa.h>

@interface HTTPResponse : NSObject {
  int status_;
  NSMutableDictionary *headers_;
  NSData *body_;
}
@property int status;
@property (retain) NSMutableDictionary *headers;
@property (retain) NSData *body;
@end


