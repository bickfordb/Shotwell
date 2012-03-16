#include "md0/lib/log.h"
#include "md0/lib/sdl.h" 

extern "C" {
#include <SDL/SDL.h>
#undef main
#include <SDL/SDL_thread.h>
}

namespace md0 {
namespace sdl { 

SDL *SDL::shared_instance_ = NULL;
pthread_mutex_t SDL::shared_lock_;

const int kSDLAudioBufferSize = 1024;
bool inited = false;

void SDL::GetAudioCallback(void *ctx, uint8_t *stream, int len) { 
  pthread_mutex_lock(&shared_lock_);
  if (shared_instance_) 
    shared_instance_->GetAudio(stream, len);
  else
    memset(stream, 0, len);
  pthread_mutex_unlock(&shared_lock_);
}

void SDL::Init() {
  if (inited) 
    return;
  inited = true;
  pthread_mutex_init(&shared_lock_, NULL);
  shared_instance_ = new SDL();

  int sdl_flags = SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER;
#if !defined(__MINGW32__) && !defined(__APPLE__)
  sdl_flags |= SDL_INIT_EVENTTHREAD; /* Not supported on Windows or Mac OS X */
#endif
  if (SDL_Init(sdl_flags)) {
    ERROR("Could not initialize SDL - %s\n", SDL_GetError());
    exit(1);
  } 
  SDL_AudioSpec req_spec;
  SDL_AudioSpec spec;
  req_spec.freq = 44100;
  req_spec.format = AUDIO_S16SYS;
  req_spec.channels = 2;
  req_spec.silence = 0;
  req_spec.samples = 1024;
  req_spec.callback = SDL::GetAudioCallback;
  req_spec.userdata = NULL;
  if(SDL_OpenAudio(&req_spec, &spec) < 0) {
    ERROR("open audio failed: %s", SDL_GetError());
  }
  SDL_PauseAudio(0);
}

SDL::SDL() {
  audio_src_ = NULL;
  volume_ = 0.5;
  pthread_mutex_init(&lock_, NULL);
}

SDL::~SDL() {
  pthread_mutex_lock(&lock_);
  audio_src_ = NULL;
  pthread_mutex_lock(&lock_);
}

AudioSource *SDL::Source() {
  return audio_src_;
}

void SDL::SetSource(AudioSource *src) {
  pthread_mutex_lock(&lock_);
  audio_src_ = src;
  pthread_mutex_unlock(&lock_);
}

void SDL::Stop() { 
  SDL_PauseAudio(1);
}

void SDL::Start() { 
  SDL_PauseAudio(0);
}

void SDL::FlushStream() { 

}

void SDL::GetAudio(uint8_t *stream, size_t len) { 
  uint8_t s[len];
  memset(s, 0, len);
  memset(stream, 0, len);
  // FIXME: Not sure if we should lock this object or audio_src while we're using it?
  pthread_mutex_lock(&lock_);
  if (audio_src_) {
    audio_src_->GetAudio(s, len); 
  } else {
    memset(s, 0, len);
  }
  pthread_mutex_unlock(&lock_);
  int vol = volume_ * SDL_MIX_MAXVOLUME;
  SDL_MixAudio(stream, s, len, vol);
}

}
}
