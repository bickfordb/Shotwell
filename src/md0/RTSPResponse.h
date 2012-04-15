#import <Cocoa/Cocoa.h>

@interface RTSPResponse : NSObject { 
  int status_;
  NSMutableDictionary *headers_;
  NSData *body_;
}

@property (retain) NSData *body;
@property (retain) NSMutableDictionary *headers;
@property int status;
@end

// vim: filetype=objcpp

