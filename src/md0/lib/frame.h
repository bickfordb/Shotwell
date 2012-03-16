#ifndef __FRAME_H_
#define __FRAME_H_
#include <stdint.h>

struct Frame { 
  uint8_t *data_;
  size_t length_;

  Frame(int length) : length_(length) { 
    data_ = (uint8_t *)malloc(length_);
    memset(data_, 0, length_);
  }
  ~Frame() { 
    free(data_);
  }

  uint8_t *data() {
    return data_;
  }

  size_t length() { 
    return length_;
  }

  Frame(Frame &other) {
    length_ = other.length_;
    data_ = (uint8_t *)malloc(length_);
    memcpy((void *)data_, (const void *)other.data_, length_); 
  }
};

#endif
