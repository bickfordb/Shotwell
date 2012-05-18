#import <Cocoa/Cocoa.h>
#import <event2/buffer.h>

@interface BitBuffer : NSObject { 
  struct evbuffer *buffer_;
  uint8_t val_;
  uint8_t size_;
}

- (id)initWithBuffer:(struct evbuffer *)buffer;
- (void)write:(uint8_t)data length:(size_t)length;
- (void)flush;
@end

// vim: filetype=objcpp
