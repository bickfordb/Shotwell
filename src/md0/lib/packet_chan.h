#ifndef _PACKET_CHAN_H_
#define _PACKET_CHAN_H_

extern "C" {
#include "av.h"
}
#include <pthread.h>

class PacketChan {
private:
  AVPacket **buf_;  
  int head_;
  int count_;
  int max_size_;
  pthread_mutex_t mutex_;
  void Clear();
public:
  PacketChan(int size);
  ~PacketChan();
  AVPacket *Get();
  int Put(AVPacket *p);
  void Reset(); 
};
#endif
