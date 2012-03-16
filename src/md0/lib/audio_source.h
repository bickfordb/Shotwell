#ifndef _AUDIO_SOURCE_INTERFACE_

#include <stdint.h>
#include <assert.h>

namespace md0 {
class AudioSource { 
 public:
  virtual ~AudioSource() { };
  virtual void GetAudio(uint8_t *bytes, size_t len) = 0;
};
}
#endif
