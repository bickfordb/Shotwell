#ifndef _SDL_AUDIO_SINK_H_
#define _SDL_AUDIO_SINK_H_

#include <pthread.h>
#include "audio_sink.h"
#include "log.h"

namespace md0 { 
namespace sdl { 

class SDL;

class SDL : public AudioSink {
 private:
  AudioSource *audio_src_; 
  pthread_mutex_t lock_;
  double volume_;
  static pthread_mutex_t shared_lock_;
  static SDL *shared_instance_;
  void GetAudio(uint8_t *, size_t l);

  static void GetAudioCallback(void *ctx, uint8_t *stream, int len);
 public:
  SDL();
  ~SDL();

  double Volume() { return volume_; }
  void SetVolume(double pct) { 
    INFO("set volume: %f", pct);
    volume_ = pct;
  }
  static void Init();
  static SDL *SharedInstance() { return shared_instance_; }

  AudioSource *Source();
  void SetSource(AudioSource *src);
  void Stop();
  void Start();
  void FlushStream();
};
}
}
#endif


