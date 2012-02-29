
#include "log.h"
#include "movie.h"
#include "av.h"

#define MIN(A, B) ((A < B) ? A : B)
#define AUDIO_CODEC_CONTEXT() (format_ctx_->streams[audio_stream_idx_]->codec)
#define SDL_AUDIO_BUFFER_SIZE 1024


// The currently playing movie if there is one.
static Movie *currently_playing = NULL;
// A lock around static movie sources.
static pthread_mutex_t lock;
static AVPacket flush_pkt;

static void *ReadMovieThread(void *m);
static void GetAudioThread(void *m, Uint8 *stream, int len);

static void *ReadMovieThread(void *m) {
  Movie *movie = (Movie *)m;
  movie->Read();
  return NULL;
}

static void GetAudioThread(void *m, Uint8 *stream, int len)  {
  pthread_mutex_lock(&lock); 
  if (currently_playing != NULL)
    currently_playing->ReadAudio(stream, len);
  pthread_mutex_unlock(&lock); 
}

static int movie_inited = 0;

void MovieInit() { 
  if (movie_inited)
    return;
  pthread_mutex_init(&lock, NULL);
  avcodec_register_all();
  avdevice_register_all();
  avfilter_register_all();
  av_register_all();
  avformat_network_init();
  int sdl_flags = SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER;
#if !defined(__MINGW32__) && !defined(__APPLE__)
  sdl_flags |= SDL_INIT_EVENTTHREAD; /* Not supported on Windows or Mac OS X */
#endif
  if (SDL_Init(sdl_flags)) {
    ERROR("Could not initialize SDL - %s\n", SDL_GetError());
    exit(1);
  } 
  av_init_packet(&flush_pkt);
  flush_pkt.data = (uint8_t *)"FLUSH";
  currently_playing = NULL; 
  SDL_AudioSpec req_spec;
  SDL_AudioSpec spec;
  req_spec.freq = 44100;//audio_codec_ctx->sample_rate;
  req_spec.format = AUDIO_S16SYS;
  req_spec.channels = 2;//audio_codec_ctx->channels;
  req_spec.silence = 0;
  req_spec.samples = SDL_AUDIO_BUFFER_SIZE;
  req_spec.callback = GetAudioThread;
  req_spec.userdata = NULL;
  if(SDL_OpenAudio(&req_spec, &spec) < 0) {
    ERROR("open audio failed: %s", SDL_GetError());
  }
  SDL_PauseAudio(0);
  movie_inited = 1;
}

void Movie::SetListener(MovieListener listener, void *ctx) { 
  listener_ = listener;
  listener_ctx_ = ctx;
}
 
void Movie::ReadAudio(uint8_t *stream, int len) { 
  int orig_len = len;
  uint8_t *orig_stream = stream;
  while (len > 0) {
    if (curr_audio_frame_remaining_ > 0) {
      int amt = MIN(len, curr_audio_frame_remaining_);
      memcpy(
          stream, 
          curr_audio_frame_->data[0] + curr_audio_frame_offset_, 
          amt);
      len -= amt;
      stream += amt;
      curr_audio_frame_remaining_ -= amt;
      curr_audio_frame_offset_ += amt;
      continue;
    }
    if (AdvanceFrame() != 0) {
      memset(stream, 0, len);
      break;
    } else { 
      if (listener_)
        listener_(listener_ctx_, this, kAudioFrameProcessedMovieEvent, NULL);
    }
  }
  uint8_t s[orig_len];
  memcpy(s, orig_stream, orig_len);
  int vol = volume_ * SDL_MIX_MAXVOLUME;
  memset(orig_stream, 0, orig_len);
  SDL_MixAudio(orig_stream, s, orig_len, vol);
}
int Movie::AdvanceFrame() { 
  AVCodecContext *codec_ctx = AUDIO_CODEC_CONTEXT();
  for (;;) {
    if (curr_audio_packet_ == NULL
        || curr_audio_packet_adj_.size <= 0) {
      if (curr_audio_packet_ != NULL) { 
        av_free_packet(curr_audio_packet_);
        curr_audio_packet_ = NULL;
      }
      while (state_ = kPlayingMovieState) { 
        curr_audio_packet_ = audio_packet_chan_->Get();
        if (curr_audio_packet_ != NULL)
          break;
        usleep(10000);
      }   
      // Check for EOF
      if (!curr_audio_packet_) {
        return -1;
      }
      curr_audio_packet_adj_ = *curr_audio_packet_;
      continue;
    }
    if (curr_audio_packet_adj_.data == flush_pkt.data)
      avcodec_flush_buffers(codec_ctx);

    // Reset the frame
    avcodec_get_frame_defaults(curr_audio_frame_);   
    curr_audio_frame_remaining_ = 0;
    curr_audio_frame_offset_ = 0;
    // Each audio packet may contain multiple frames.
    int got_frame = 0;
    int amt_decoded = avcodec_decode_audio4(
        codec_ctx,
        curr_audio_frame_, 
        &got_frame,
        &curr_audio_packet_adj_);
    if (amt_decoded < 0) {
      char error[256];
      av_strerror(amt_decoded, error, 256);
      ERROR("decode error: %s", error);
      // skip this packet.
      curr_audio_packet_adj_.size = 0;
      continue;
    } else {
      curr_audio_packet_adj_.data += amt_decoded;
      curr_audio_packet_adj_.size -= amt_decoded;
    }
    if (!got_frame)
      return 0;
    // find the size of a frame:
    int data_size = av_samples_get_buffer_size(
        NULL,
        codec_ctx->channels,
        curr_audio_frame_->nb_samples,
        codec_ctx->sample_fmt, 
        1);
    curr_audio_frame_remaining_ = data_size;
    // update the elapsed pts
  
    //elapsed_ = curr_audio_packet_->pts;
    return 0;
  } 
}

Movie::Movie(const std::string & filename) { 
  MovieInit();
  listener_ = NULL;
  listener_ctx_ = NULL;
  pthread_mutex_init(&lock_, NULL);
  elapsed_ = 0;
  seek_to_ = -1;
  filename_ = filename;      
  audio_packet_chan_ = new PacketChan(16);     
  format_ctx_ = NULL;
  reader_thread_ = NULL;
  curr_audio_frame_ = avcodec_alloc_frame();
  avcodec_get_frame_defaults(curr_audio_frame_);   
  curr_audio_packet_ = NULL;
  memset(&curr_audio_packet_adj_, 0, sizeof(curr_audio_packet_adj_));
  curr_audio_frame_offset_ = 0;
  audio_stream_idx_ = -1;
  curr_audio_frame_remaining_ = 0;
  filename_ = filename;  
  INFO("opening %s", filename.c_str());
  AVDictionary **opts = NULL;
  AVDictionaryEntry *t;
  AVPacket pkt1, *pkt = &pkt1;
  int eof = 0;
  int err;
  int i;
  int pkt_in_play_range = 0;
  int ret;
  duration_ = 0;
  state_ = kErrorMovieState;
  audio_stream_idx_ = -1;
  AVFormatContext *c = NULL;
  format_ctx_ = avformat_alloc_context();
  err = avformat_open_input(&format_ctx_, filename_.c_str(), NULL, NULL);
  if (err != 0) {
    ERROR("could not open: %d", err);
    return;
  } 
  err = avformat_find_stream_info(format_ctx_, NULL);
  if (err < 0) {
    ERROR("could not find stream info");
    return;
  } 
  for (int i = 0; i < format_ctx_->nb_streams; i++) {
    if (format_ctx_->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      audio_stream_idx_ = i;
    }
  }
  if (audio_stream_idx_ < 0) {
    return;
  }  
  time_base_ = format_ctx_->streams[audio_stream_idx_]->time_base;
  duration_ = format_ctx_->streams[audio_stream_idx_]->duration;
  elapsed_ = 0;
  state_ = kPausedMovieState;
}

Movie::~Movie() {
  this->Stop();
  pthread_mutex_lock(&lock_);
  if (format_ctx_ != NULL)
    avformat_close_input(&format_ctx_);
  // pretty sure close also frees, but just in case:
  if (format_ctx_ != NULL)
    avformat_free_context(format_ctx_);
  delete audio_packet_chan_;
  pthread_mutex_unlock(&lock_);
}

void Movie::SetVolume(double pct) {
  volume_ = pct;
}

double Movie::Volume() { 
  return volume_;
}

MovieState Movie::state() { 
  return state_;
}

void Movie::Seek(double seconds) { 
  if (state_ != kPlayingMovieState) 
    return;
  seek_to_ = seconds * AV_TIME_BASE;
}

bool Movie::isSeeking() {
  return seek_to_ >= 0;
}

void Movie::Read() { 
  INFO("start reader");
  AVCodecContext *audio_codec_ctx = AUDIO_CODEC_CONTEXT();
  AVCodec *codec = avcodec_find_decoder(audio_codec_ctx->codec_id); 
  avcodec_open2(audio_codec_ctx, codec, NULL);
  
  pthread_mutex_lock(&lock);
  currently_playing = this;
  pthread_mutex_unlock(&lock);
  state_ = kPlayingMovieState;
  if (listener_) {
    listener_(listener_ctx_, this, kRateChangeMovieEvent, NULL);
  } 
  SDL_Event event;
  audio_packet_chan_->Reset();
  seek_to_ = -1;
  // N.B. avformat_seek_.. would fail sporadically, so av_seek_frame is used here instead.
  av_seek_frame(format_ctx_, -1, elapsed_, 0);
  while (state_ == kPlayingMovieState) {
    if (seek_to_ >= 0) {
      int seek_ret = av_seek_frame(format_ctx_, -1, seek_to_, 0);
      if (seek_ret < 0) {
         ERROR("Failed to seek (%d) to %ld, %f", seek_ret, seek_to_, (double)(seek_to_ / ((double)AV_TIME_BASE)));
      } 
      for (int i = 0; i < format_ctx_->nb_streams; i++) {
        avcodec_flush_buffers(format_ctx_->streams[i]->codec);
      }
      elapsed_ = seek_to_;
      seek_to_ = -1;
    }

    AVPacket *packet = (AVPacket *)malloc(sizeof(AVPacket));
    if (packet == NULL) {
      ERROR("unable to allocate packet");
      break;
    }
    memset(packet, 0, sizeof(packet));
    av_init_packet(packet);
    int read = av_read_frame(format_ctx_, packet);
    if (read < 0) { 
      if (read != -5) // eof
        ERROR("read packet fail (%d)", read);
      state_ = kPausedMovieState;
      if (listener_) 
        listener_(listener_ctx_, this, kRateChangeMovieEvent, NULL);
      if (listener_) 
        listener_(listener_ctx_, this, kEndedMovieEvent, NULL);
      break;
    } 
    if (packet->size <= 0)  {
      ERROR("empty packet");
      av_free_packet(packet);
      continue;
    }

    if (packet->stream_index != audio_stream_idx_) {
      av_free_packet(packet);
      continue;
    }
    // Totally confusing:
    // This should be called here to duplicate the ".data" section of a packet.
    int dup_st = av_dup_packet(packet);
    if (dup_st < 0) {
      ERROR("unexpected dup failure: %d", dup_st);
      av_free_packet(packet);
      continue;
    }
    elapsed_ = packet->pts;
    while (state_ == kPlayingMovieState 
        && (audio_packet_chan_->Put(packet) != 0)) { 
      usleep(10000);
    }
  }
}

void Movie::Play() { 
  if (state_ != kPausedMovieState) 
    return;
  pthread_create(&reader_thread_, NULL, ReadMovieThread, (void *)this);
}

void Movie::Stop() {
  if (state_ != kPlayingMovieState)
    return;
  pthread_mutex_lock(&lock_);
  pthread_mutex_lock(&lock);
  if (reader_thread_) { 
    // This causes avformat_close_input to hang.  I don't fully understand this.
    //pthread_cancel(reader_thread_);
    reader_thread_ = NULL;
  }
  if (currently_playing == this) { 
    currently_playing = NULL;
  }
  pthread_mutex_unlock(&lock);
  state_ = kPausedMovieState;
  pthread_mutex_unlock(&lock_); 
}

double Movie::Duration() { 
  return (duration_ * time_base_.num) / ((double) time_base_.den);
}

double Movie::Elapsed() { 
  return (elapsed_ * time_base_.num) / ((double) time_base_.den);
}
