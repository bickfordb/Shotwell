#include "log.h"
#include "raop.h"
#include <unistd.h>
#include <fcntl.h>

using namespace md1::raop;

int main(int argc, char **argv) {
  INFO("raop start");
  Client raop("10.0.1.10", 5000);
  if (!raop.Connect()) {
    ERROR("Failed to open connection");
    return -1;
  } else { 
    INFO("connected");
  }
  int f = open("/Users/bran/projects/md1/test-data/y.pcm", O_RDONLY);
  //FILE *f = fopen("/Users/bran/projects/md1/test-data/y.pcm", "r");
  //FILE *f = fopen("/Users/bran/projects/md1/test-data/y.pcm", "r");
  if (f < 0) { 
    ERROR("Failed to open file");
    return -1;
  }
  uint8_t buf[64];
  INFO("reading file");
  while (1) {
    int amt = read(f, buf, 4);
    if (amt > 0) {
      raop.WritePCM(buf, amt, false);
    } else if (amt < 0) { 
      break; 
    }
  }
  INFO("done");
  return 0;
}



