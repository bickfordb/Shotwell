#include "packet_chan.h"
#include "log.h"

PacketChan::PacketChan(int max_size) {
  buf_ = (AVPacket **)malloc(sizeof(AVPacket *) * max_size);
  if (buf_ == NULL) {
    ERROR("unable to allocate packet");
  } 
  count_ = 0;
  head_ = 0;
  pthread_mutex_init(&mutex_, NULL);
  max_size_ = max_size;
}

PacketChan::~PacketChan() {
  Clear();
  free(buf_);
}

void PacketChan::Clear() { 
  while (count_ > 0) {
    if (buf_[head_])
      av_free_packet(buf_[head_]);
    head_++;
    if (head_ >= max_size_) {
      head_ = 0;
    }
    count_--;
  }
}

void PacketChan::Reset() {
  pthread_mutex_lock(&mutex_);
  this->Clear(); 
  pthread_mutex_unlock(&mutex_);   
}

AVPacket *PacketChan::Get() { 
  AVPacket *ret = NULL;
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

int PacketChan::Put(AVPacket *p) { 
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

