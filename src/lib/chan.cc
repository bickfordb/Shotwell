#include "chan.h"
#include <stdlib.h>

Chan::Chan(int max_size) {
  buf_ = (void **)malloc(sizeof(void *) * max_size);
  count_ = 0;
  head_ = 0;
  pthread_mutex_init(&mutex_, NULL);
  max_size_ = max_size;
}

Chan::~Chan() {
  free(buf_);
}

void *Chan::Get() { 
  void *ret = NULL;
  pthread_mutex_lock(&mutex_);
  if (count_ > 0) { 
    ret = buf_[head_];
    head_ = head_ + 1;
    if (head_ >= max_size_) 
      head_ = 0;
    count_ = count_ - 1;
  }
  pthread_mutex_unlock(&mutex_);
  return ret;
}

int Chan::Put(void *p) { 
  int ret = -1;
  pthread_mutex_lock(&mutex_);
  if (count_ < max_size_) {
    int tail = (head_ + count_) % max_size_;
    buf_[tail] = p;
    count_++;
    ret = 0;
  }
  pthread_mutex_unlock(&mutex_);
  return ret;
}

