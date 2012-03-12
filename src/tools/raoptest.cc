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
  raop.Play("/Users/bran/projects/md1/test-data/y.pcm");
  INFO("done");
  return 0;
}



