#ifndef _CHAN_H_
#define _CHAN_H_
#include <pthread.h>

class Chan {
private:
  void **buf_;  
  int head_;
  int count_;
  int max_size_;
  pthread_mutex_t mutex_;
public:
  Chan(int size);
  ~Chan();
  void *Get();
  int Put(void *p);
};
#endif
