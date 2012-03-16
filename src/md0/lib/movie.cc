#include <sys/time.h>

#include "md0/lib/log.h"
#include "md0/lib/movie.h"
#include "md0/lib/av.h"
#include "md0/lib/chan.h"
#include "md0/lib/raop.h"
#include "md0/lib/audio_sink.h"
#include "md0/lib/sdl.h"

#define MIN(A, B) ((A < B) ? A : B)
#define AUDIO_CODEC_CONTEXT() (format_ctx_->streams[audio_stream_idx_]->codec)

namespace md0 {
namespace movie { 

AudioSink *shared_sink_;
pthread_mutex_t shared_lock_;

long double Now(); 
class Reader;

// The currently playing movie if there is one.
AVPacket flush_pkt;

class Reader : public AudioSource {
 public:
  AVPacket curr_audio_packet_;
  AVPacket curr_audio_packet_adj_;
  AVFrame *curr_audio_frame_;
  bool opened_;
  int curr_audio_frame_offset_;
  int curr_audio_frame_remaining_; 
  AVFormatContext *format_ctx_;
  int audio_stream_idx_;
  int64_t elapsed_;
  int64_t duration_;
  bool stop_;
  int64_t seek_to_;
  md0::movie::MovieState state_; 
  Movie *movie_;
  pthread_mutex_t lock_; 
  AVRational time_base_;
  ~Reader() {
    movie_ = NULL;
    if (format_ctx_) {
      avformat_close_input(&format_ctx_);
    }
    if (format_ctx_) {
      avformat_free_context(format_ctx_);
    }
    av_free_packet(&curr_audio_packet_);
    av_free_packet(&curr_audio_packet_adj_);
    pthread_mutex_destroy(&lock_);
  }

  Reader(Movie *movie) : movie_(movie) {
    opened_ = false;
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

    memset(&curr_audio_packet_, 0, sizeof(AVPacket));
    av_init_packet(&curr_audio_packet_);

    memset(&curr_audio_packet_adj_, 0, sizeof(curr_audio_packet_adj_));
    av_init_packet(&curr_audio_packet_adj_);
    curr_audio_frame_offset_ = 0;
  }

  void Lock() {
    pthread_mutex_lock(&lock_);
  }

  void Unlock() {
    pthread_mutex_unlock(&lock_);
  }

  bool Open() { 
    int err = 0;
    duration_ = 0;
    audio_stream_idx_ = -1;
    format_ctx_ = avformat_alloc_context();
    err = avformat_open_input(&format_ctx_, movie_->filename().c_str(), NULL, NULL);
    if (err != 0) {
      ERROR("could not open: %d", err);
      return false;
    } 
    err = avformat_find_stream_info(format_ctx_, NULL);
    if (err < 0) {
      ERROR("could not find stream info");
      return false;
    } 
    for (int i = 0; i < format_ctx_->nb_streams; i++) {
      if (format_ctx_->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
        audio_stream_idx_ = i;
      }
    }
    if (audio_stream_idx_ < 0) {
      ERROR("couldnt locate audio stream index");
      return false;
    }  
    duration_ = format_ctx_->streams[audio_stream_idx_]->duration;
    time_base_ = format_ctx_->streams[audio_stream_idx_]->time_base;
    elapsed_ = 0;
    AVCodecContext *audio_codec_ctx = AUDIO_CODEC_CONTEXT();
    AVCodec *codec = avcodec_find_decoder(audio_codec_ctx->codec_id); 
    avcodec_open2(audio_codec_ctx, codec, NULL);

    if (movie_) { 
      movie_->Signal(kRateChangeMovieEvent, NULL);
    } 
    // N.B. avformat_seek_.. would fail sporadically, so av_seek_frame is used here instead.
    if (seek_to_ >= 0)  {
      av_seek_frame(format_ctx_, -1, seek_to_, 0);
      seek_to_ = -1;
    }

    state_ = kPlayingMovieState;
    return true;
  }

  bool ReadPacket(AVPacket *packet) {  
    if (!opened_) {
      opened_ = Open();
      if (!opened_)
        return false;
    } 
    if (state_ == kPausedMovieState) {
      return false;
    }
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

    while (1) { 
      int read = av_read_frame(format_ctx_, packet);
      if (read < 0) { 
        if (read != -5) {// eof
          ERROR("read packet fail (%d)", read);
        } 
        state_ = kErrorMovieState;
        if (movie_) {
          movie_->Signal(kRateChangeMovieEvent, NULL);
          movie_->Signal(kEndedMovieEvent, NULL);
        }
        return false;
      } 
      if (packet->size <= 0)  {
        continue;
      }

      if (packet->stream_index != audio_stream_idx_) {
        continue;
      }
      // Totally confusing:
      // This should be called here to duplicate the ".data" section of a packet.
      elapsed_ = packet->pts;
      return true;
    }
  }

  void GetAudio(uint8_t *stream, size_t len) { 
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
      if (!ReadFrame()) {
        memset(stream, 0, len);
        break;
      }
    }
  }

  bool ReadFrame() { 
    for (;;) {
      if (curr_audio_packet_adj_.size <= 0) {
        av_free_packet(&curr_audio_packet_);
        if (!ReadPacket(&curr_audio_packet_)) {
          return false;
        }
        curr_audio_packet_adj_ = curr_audio_packet_;
        continue;
      }
      if (curr_audio_packet_adj_.data == flush_pkt.data)
        avcodec_flush_buffers(AUDIO_CODEC_CONTEXT());

      // Reset the frame
      avcodec_get_frame_defaults(curr_audio_frame_);   
      curr_audio_frame_remaining_ = 0;
      curr_audio_frame_offset_ = 0;
      // Each audio packet may contain multiple frames.
      int got_frame = 0;
      int amt_decoded = avcodec_decode_audio4(
          AUDIO_CODEC_CONTEXT(),
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
      } 
      if (!got_frame)
        continue;

      curr_audio_packet_adj_.data += amt_decoded;
      curr_audio_packet_adj_.size -= amt_decoded;
      // find the size of a frame:
      int data_size = av_samples_get_buffer_size(
          NULL,
          AUDIO_CODEC_CONTEXT()->channels,
          curr_audio_frame_->nb_samples,
          AUDIO_CODEC_CONTEXT()->sample_fmt, 
          1);
      curr_audio_frame_remaining_ = data_size;
      return true;
    } 
  }
};

bool inited = false;

void Movie::Init() { 
  if (inited)
    return;
  pthread_mutex_init(&shared_lock_, NULL);
  avcodec_register_all();
  avdevice_register_all();
  avfilter_register_all();
  av_register_all();
  avformat_network_init();
  md0::sdl::SDL::Init();
  shared_sink_ = md0::sdl::SDL::SharedInstance();
  shared_sink_->Start();
  av_init_packet(&flush_pkt);
  flush_pkt.data = (uint8_t *)"FLUSH";
  inited = true;
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
  listener_ = NULL;
  listener_ctx_ = NULL;
  reader_ = NULL;
  pthread_mutex_init(&lock_, NULL);
}

Movie::~Movie() {
  Lock();
  if (reader_) {
    reader_->Lock();
    reader_->state_ = kErrorMovieState;
    reader_->movie_ = NULL;
    reader_->Unlock();
  }
  Unlock();
  //reader_.reset();
  pthread_mutex_destroy(&lock_);
}

void SetVolume(double pct) {
  shared_sink_->SetVolume(pct);
}

double Volume() { 
  return shared_sink_->Volume();
}

MovieState Movie::state() { 
  MovieState st;
  Lock();
  if (reader_) {
    st = reader_->state_;
  } else { 
    st = kErrorMovieState;
  }
  Unlock();
  return st;
}

void Movie::Seek(double seconds) { 
  Lock();
  if (reader_ && reader_->seek_to_ < 0) {
    reader_->seek_to_ = seconds * AV_TIME_BASE;
  }
  Unlock();
  pthread_mutex_lock(&shared_lock_);
  shared_sink_->FlushStream();
  pthread_mutex_unlock(&shared_lock_);
}

bool Movie::IsSeeking() {
  bool ret = false;
  Lock();
  if (reader_)
    ret = reader_->seek_to_ >= 0;
  Unlock();
  return ret;
}

void Movie::Play() { 
  Lock();
  if (!reader_) {
    reader_ = new Reader(this); 
  } else {
    reader_->state_ = kPlayingMovieState;
  }
  pthread_mutex_lock(&shared_lock_);
  shared_sink_->SetSource(reader_);
  shared_sink_->FlushStream();
  pthread_mutex_unlock(&shared_lock_);
  Unlock();
}

void Movie::Stop() {
  Lock();
  if (reader_ && reader_->state_ == kPlayingMovieState) { 
    reader_->state_ = kPausedMovieState;
  }
  Unlock();
}

double Movie::Duration() { 
  Lock();
  double res = 0;
  if (reader_ && reader_->duration_ > 0) {
    res = (reader_->duration_ * 
           reader_->time_base_.num) /
        ((double) reader_->time_base_.den);
  }
  Unlock();
  return res;
}

double Movie::Elapsed() {
  Lock();
  double res = 0;
  if (reader_ && reader_->elapsed_ >= 0)
    res = (reader_->elapsed_ * 
           reader_->time_base_.num) /
        ((double) reader_->time_base_.den);
  Unlock();
  return res;
}

void Movie::StartSDL() {
  INFO("start sdl");
  pthread_mutex_lock(&shared_lock_);
  AudioSource *src = shared_sink_->Source();
  shared_sink_->Stop();
  shared_sink_ = md0::sdl::SDL::SharedInstance();
  if (src)
    shared_sink_->SetSource(src);
  shared_sink_->Start();
  pthread_mutex_unlock(&shared_lock_);
}

void Movie::StartRAOP(const string &host, uint16_t port) {
  pthread_mutex_lock(&shared_lock_);
  AudioSource *src = shared_sink_->Source();
  shared_sink_->Stop();
  shared_sink_ = new md0::raop::Client(host, port);
  shared_sink_->SetSource(src);
  shared_sink_->Start();
  pthread_mutex_unlock(&shared_lock_);
}

}
}

