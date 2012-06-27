#import "app/BitBuffer.h"

@implementation BitBuffer
- (id)initWithBuffer:(struct evbuffer *)buffer {
  self = [super init];
  if (self) {
    buffer_ = buffer;
    val_ = 0;
    size_ = 0;
  }
  return self;
}
- (void)write:(uint8_t)data length:(size_t)length {
  while (length > 0) {
    length--;
    val_ = val_ << 1;
    val_ |= (data >> length) & 0x1;
    size_++;
    if (size_ == 8) {
      evbuffer_add(buffer_, &val_, 1);
      val_ = 0;
      size_ = 0;
    }
  }
}

- (void)flush {
  if (size_ > 0) {
    val_ = val_ << (8 - size_);
    evbuffer_add(buffer_, &val_, 1);
    val_ = 0;
    size_ = 0;
  }
}
@end
