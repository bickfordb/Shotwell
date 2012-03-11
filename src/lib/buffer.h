#ifndef __BUFFER_H_
#define __BUFFER_H_
#include <stdint.h>
#include "frame.h"

struct Buffer { 
  uint8_t *data_;
  size_t length_;

  Buffer(uint8_t *data, int length) : data_(data), length_(length) { 
  }
  ~Buffer() { 
  }

  Buffer(const Buffer &other) {
    length_ = other.length_;
    data_ = other.data_;
  }

  const Buffer operator+(int i) {
    return length_ - i > 0 ? Buffer(data_ + i, length_ - i) : Buffer(NULL, 0);
  }

  Buffer &operator+=(int i) {
    int len = length_ - i;
    if (len > 0) {
      length_ = len;
      data_ += i;
    } else {
      data_ = NULL;
      length_ = 0;
    }
    return *this;
  }

  Buffer(Frame &frame) : length_(frame.length()), data_(frame.data()) { 
  }

  uint8_t *data() const { 
    return data_;
  }

  uint8_t *c_str() const { 
    return data_;
  }


  size_t length() const { 
    return length_;
  }
  
  size_t size() const { 
    return length_;
  }

  void Read(Buffer &other) {
    memcpy((void *)data_, (const void *)(other.data()), other.length());
  }

  void Write(Buffer &other) {
    memcpy((void *)other.data(), (const void *)data(), length());
  }
};

#endif
