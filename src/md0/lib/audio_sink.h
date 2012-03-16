#ifndef _AUDIO_SINK_H_
#define _AUDIO_SINK_H_

#include "audio_source.h"

namespace md0 { 

class AudioSink {
 public:
  virtual void SetVolume(double pct) = 0;
  virtual double Volume() = 0;
  virtual void Stop() = 0;
  virtual void Start() = 0;
  virtual void SetSource(AudioSource *source) = 0;
  virtual void FlushStream() = 0;
  virtual AudioSource *Source() = 0;
  virtual ~AudioSink() { };

};

}

#endif
