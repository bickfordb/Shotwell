#include <sys/time.h>
#import "md0/Util.h"

const int64_t kSPerUS = 1000000;

int64_t Now() {
  struct timeval t;
  gettimeofday(&t, NULL);
  int64_t ret = t.tv_usec;
  ret += t.tv_sec * kSPerUS;
  return ret;
}

