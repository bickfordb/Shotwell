#include "log.h"
#include "movie.h"
#include "av.h"
#include "chan.h"
#include "raop.h"
#include <sys/time.h>

#define MIN(A, B) ((A < B) ? A : B)
#define AUDIO_CODEC_CONTEXT() (format_ctx_->streams[audio_stream_idx_]->codec)

long double Now(); 
static void ResetAudioPackets(); 
static void *ReadMovieThread(void *m);
static void GetAudioThread(void *m, Uint8 *stream, int len);

const int kSDLAudioBufferSize = 1024;
// The currently playing movie if there is one.
static ReaderThreadState *reader_thread_state;
static Chan *audio_packet_chan; 

static double volume;
// A lock around static movie sources.
static pthread_mutex_t lock;
static AVPacket flush_pkt;

class ReaderThreadState {
public:
  AVPacket *curr_audio_packet_;
  AVPacket curr_audio_packet_adj_;
  AVFrame *curr_audio_frame_;
  int curr_audio_frame_offset_;
  int curr_audio_frame_remaining_; 
  AVFormatContext *format_ctx_;
  int audio_stream_idx_;
  int64_t elapsed_;
  int64_t duration_;
  bool stop_;
  int64_t seek_to_;
  MovieState state_; 
  Movie *movie_;
  pthread_mutex_t lock_; 
  AVRational time_base_;
  ~ReaderThreadState() {
    movie_ = NULL;
    if (format_ctx_) {
      avformat_close_input(&format_ctx_);
    }
    if (format_ctx_) {
      avformat_free_context(format_ctx_);
    }
    pthread_mutex_destroy(&lock_);
  }

  ReaderThreadState(Movie *movie) : movie_(movie) {
    audio_stream_idx_ = - 1;
    pthread_mutex_init(&lock_, NULL);
    elapsed_ = -1;
    duration_ = -1;
    seek_to_ = -1;
    format_ctx_ = NULL;
    stop_ = false;
    curr_audio_frame_ = avcodec_alloc_frame();
    avcodec_get_frame_defaults(curr_audio_frame_);   
    curr_audio_frame_offset_ = 0;
    curr_audio_frame_remaining_ = 0;
    state_ = kErrorMovieState;
    curr_audio_packet_ = NULL;
    memset(&curr_audio_packet_adj_, 0, sizeof(curr_audio_packet_adj_));
    curr_audio_frame_offset_ = 0;
  }

  void Lock() {
    pthread_mutex_lock(&lock_);
  }

  void Unlock() {
    pthread_mutex_unlock(&lock_);
  }

  void Read() {  
    INFO("start reader");
    AVPacket pkt1, *pkt = &pkt1;
    int err;
    duration_ = 0;
    audio_stream_idx_ = -1;
    format_ctx_ = avformat_alloc_context();
    err = avformat_open_input(&format_ctx_, movie_->filename().c_str(), NULL, NULL);
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
    duration_ = format_ctx_->streams[audio_stream_idx_]->duration;
    time_base_ = format_ctx_->streams[audio_stream_idx_]->time_base;
    elapsed_ = 0;
    AVCodecContext *audio_codec_ctx = AUDIO_CODEC_CONTEXT();
    AVCodec *codec = avcodec_find_decoder(audio_codec_ctx->codec_id); 
    avcodec_open2(audio_codec_ctx, codec, NULL);

    Lock();
    if (movie_) { 
      movie_->Signal(kRateChangeMovieEvent, NULL);
    } 
    Unlock();
    ResetAudioPackets();
    // N.B. avformat_seek_.. would fail sporadically, so av_seek_frame is used here instead.
    if (seek_to_ >= 0)  {
      av_seek_frame(format_ctx_, -1, seek_to_, 0);
      seek_to_ = -1;
    }
    state_ = kPlayingMovieState;
    while (state_ != kErrorMovieState) {
      if (state_ == kPausedMovieState) {
        while (state_ == kPausedMovieState) { 
          usleep(100000);
        }
        continue;
      }
      if (seek_to_ >= 0) {
        int seek_ret = av_seek_frame(format_ctx_, -1, seek_to_, 0);
        if (seek_ret < 0) {
          ERROR("Failed to seek (%d) to %ld, %f", seek_ret, seek_to_, (double)(seek_to_ / ((double)AV_TIME_BASE)));
        }
        for (int i = 0; i < format_ctx_->nb_streams; i++) {
          avcodec_flush_buffers(format_ctx_->streams[i]->codec);
        }
        ResetAudioPackets();
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
        Lock();
        if (read != -5) {// eof
          ERROR("read packet fail (%d)", read);
        } 
        state_ = kErrorMovieState;
        if (movie_) {
          movie_->Signal(kRateChangeMovieEvent, NULL);
          movie_->Signal(kEndedMovieEvent, NULL);
        }
        av_free_packet(packet);
        Unlock();
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
      av_dup_packet(packet);
      elapsed_ = packet->pts;
      for (;;) {
        if (audio_packet_chan->Put((void *)packet) == 0) {
          break;
        }
        usleep(10000);
        if (state_ == kErrorMovieState) {
          av_free_packet(packet);
          break;
        }
      }
    }
  }
  void DecodeAudio(uint8_t *stream, int len) { 
    if (state_ != kPlayingMovieState)
      return;
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
      }
    }
    uint8_t s[orig_len];
    memcpy(s, orig_stream, orig_len);
    int vol = volume * SDL_MIX_MAXVOLUME;
    memset(orig_stream, 0, orig_len);
    SDL_MixAudio(orig_stream, s, orig_len, vol);
  }

  int AdvanceFrame() { 
    AVCodecContext *codec_ctx = AUDIO_CODEC_CONTEXT();
    for (;;) {
      if (curr_audio_packet_ == NULL
          || curr_audio_packet_adj_.size <= 0) {
        if (curr_audio_packet_ != NULL) { 
          av_free_packet(curr_audio_packet_);
          curr_audio_packet_ = NULL;
        }
        while (state_ == kPlayingMovieState) { 
          curr_audio_packet_ = (AVPacket *)audio_packet_chan->Get();
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
};



static void *ReadMovieThread(void *m) {
  shared_ptr<ReaderThreadState> st;
  st = *((shared_ptr<ReaderThreadState> *)m);
  pthread_mutex_lock(&lock);
  reader_thread_state = st.get();
  pthread_mutex_unlock(&lock);
  st->Read();
  pthread_mutex_lock(&lock);
  if (reader_thread_state == st.get())
    reader_thread_state = NULL;
  pthread_mutex_unlock(&lock);
  return NULL;
}

static void GetAudioThread(void *m, Uint8 *stream, int len)  {
  pthread_mutex_lock(&lock); 
  if (reader_thread_state != NULL)
    reader_thread_state->DecodeAudio(stream, len);
  pthread_mutex_unlock(&lock); 
}

static int movie_inited = 0;

static void ResetAudioPackets() { 
  pthread_mutex_lock(&lock);
  AVPacket *p;
  while ((p = (AVPacket *)audio_packet_chan->Get())) {
    av_free_packet(p);
  }
  pthread_mutex_unlock(&lock);
}

void MovieInit() { 
  if (movie_inited)
    return;
  volume = 0.5;
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
  audio_packet_chan = new Chan(16);
  av_init_packet(&flush_pkt);
  flush_pkt.data = (uint8_t *)"FLUSH";
  SDL_AudioSpec req_spec;
  SDL_AudioSpec spec;
  req_spec.freq = 44100;//audio_codec_ctx->sample_rate;
  req_spec.format = AUDIO_S16SYS;
  req_spec.channels = 2;//audio_codec_ctx->channels;
  req_spec.silence = 0;
  req_spec.samples = kSDLAudioBufferSize;
  req_spec.callback = GetAudioThread;
  req_spec.userdata = NULL;
  if(SDL_OpenAudio(&req_spec, &spec) < 0) {
    ERROR("open audio failed: %s", SDL_GetError());
  }
  SDL_PauseAudio(0);
  movie_inited = 1;
}

void Movie::SetListener(MovieListener listener, void *ctx) { 
  Lock();
  listener_ = listener;
  listener_ctx_ = ctx;
  Unlock();
}

void Movie::Signal(MovieEvent event, void *data) { 
  Lock();
  if (listener_) 
    listener_(listener_ctx_, this, event, data);
  Unlock();
}

void Movie::Lock() {
  pthread_mutex_lock(&lock_);
}

void Movie::Unlock() {
  pthread_mutex_unlock(&lock_);
}

Movie::Movie(const std::string & filename) : filename_(filename) { 
  MovieInit();
  listener_ = NULL;
  listener_ctx_ = NULL;
  pthread_mutex_init(&lock_, NULL);
}

Movie::~Movie() {
  Lock();
  if (reader_thread_state_) {
    reader_thread_state_->Lock();
    reader_thread_state_->state_ = kErrorMovieState;
    reader_thread_state_->movie_ = NULL;
    reader_thread_state_->Unlock();
  }
  Unlock();
  reader_thread_state_.reset();
  pthread_mutex_destroy(&lock_);
}

void SetVolume(double pct) {
  volume = pct;
}

double Volume() { 
  return volume;
}

MovieState Movie::state() { 
  MovieState st;
  Lock();
  if (reader_thread_state_) {
    st = reader_thread_state_->state_;
  } else { 
    st = kErrorMovieState;
  }
  Unlock();
  return st;
}

void Movie::Seek(double seconds) { 
  Lock();
  if (reader_thread_state_ && reader_thread_state_->seek_to_ < 0) {
    reader_thread_state_->seek_to_ = seconds * AV_TIME_BASE;
  }
  Unlock();
}

bool Movie::IsSeeking() {
  bool ret = false;
  Lock();
  if (reader_thread_state_)
    ret = reader_thread_state_->seek_to_ >= 0;
  Unlock();
  return ret;
}

void Movie::Play() { 
  Lock();
  if (reader_thread_state_ && reader_thread_state_->state_ == kPausedMovieState) {
    reader_thread_state_->state_ = kPlayingMovieState;
  } else {
    reader_thread_state_.reset(new ReaderThreadState(this));
    pthread_t t;
    pthread_create(&t, NULL, ReadMovieThread, &reader_thread_state_);
  }
  Unlock();
}

void Movie::Stop() {
  Lock();
  if (reader_thread_state_ && reader_thread_state_->state_ == kPlayingMovieState) { 
    reader_thread_state_->state_ = kPausedMovieState;
  }
  Unlock();
}

double Movie::Duration() { 
  Lock();
  double res = 0;
  if (reader_thread_state_ && reader_thread_state_->duration_ > 0) {
    res = (reader_thread_state_->duration_ * 
      reader_thread_state_->time_base_.num) /
      ((double) reader_thread_state_->time_base_.den);
  }
  Unlock();
  return res;
}

double Movie::Elapsed() {
  Lock();
  double res = 0;
  if (reader_thread_state_ && reader_thread_state_->elapsed_ >= 0)
    res = (reader_thread_state_->elapsed_ * 
      reader_thread_state_->time_base_.num) /
      ((double) reader_thread_state_->time_base_.den);
  Unlock();
  return res;
}


pthread_t raop_thread;
void *RunRAOP(void *ctx) {
  md1::raop::Client *client = (md1::raop::Client *)ctx;
  usleep(100000);
  while (!reader_thread_state) 
    usleep(10000);
  AVStream *src_stream = reader_thread_state->format_ctx_->streams[reader_thread_state->audio_stream_idx_];
  AVCodecContext *src_codec_context = src_stream->codec;
  AVFrame *frame = avcodec_alloc_frame();
  AVCodec *alac = avcodec_find_encoder_by_name("alac");
  double last_sent = 0;
  if (!alac) {
    ERROR("cant find alac");
    return NULL; 
  }

  AVCodecContext *alac_ctx = avcodec_alloc_context3(alac);
  if (!alac_ctx) {
    ERROR("cant alloc alac ctx");
    goto raopdone;
  }
  //alac_ctx->bit_rate = 44100;
  alac_ctx->channels = src_codec_context->channels;
  alac_ctx->sample_rate = src_codec_context->sample_rate;
  alac_ctx->compression_level = 0;
  //alac_ctx->sample_fmt = src_codec_context->sample_fmt;
  alac_ctx->time_base = src_stream->time_base;
  alac_ctx->sample_fmt = AV_SAMPLE_FMT_S16;
  INFO("opening alac");
  DEBUG("opening");
  if (avcodec_open2(alac_ctx, alac, NULL) < 0) {
    ERROR("failed to open codec");
    goto raopdone;
  }
 
 
  while (1) {
    AVPacket *src_packet = NULL;
    for (;;) {
      src_packet = (AVPacket *)audio_packet_chan->Get();
      if (src_packet)
        break;
      usleep(10000);
    }
    // make a packet to keep track of offsets.
    AVPacket src_packet_temp = *src_packet;
    while (src_packet_temp.size > 0) { 
      avcodec_get_frame_defaults(frame);   
      int got_frame = 0;
      int packet_offset = avcodec_decode_audio4(
          src_codec_context,
          frame, 
          &got_frame,
          &src_packet_temp);
      
      if (packet_offset < 0) {
        ERROR("failed to decode packet: %d", packet_offset);
        // skip the rest of this packet
        break;
      }
      if (packet_offset > 0) {
        src_packet_temp.data += packet_offset;
        src_packet_temp.size -= packet_offset;
      }
      if (got_frame) {
        bool is_eof = false;
        INFO("line size: %d", frame->linesize[0]);
        //client->WritePCM(frame->data[0], frame->linesize[0], is_eof);
      }
    }
    av_free_packet(src_packet);
  }
raopdone:
  delete client;
  return NULL;
}

int MovieStartRAOP(const string &host, int port) {
  SDL_PauseAudio(1);
  md1::raop::Client *remote = new md1::raop::Client(host, port);
  if (!remote->Connect())
    return -1;
  pthread_create(&raop_thread, NULL, RunRAOP, remote);
  return 0;
};

void MovieStartSDL() {
  SDL_PauseAudio(0);
};




