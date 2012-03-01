
#ifndef _MOVIE_H_
#define _MOVIE_H_

#include <string>
#include <pthread.h>
#include "av.h"

#include "packet_chan.h"

void MovieInit();

typedef enum {
  kErrorMovieState = -1,
  kPausedMovieState = 0,
  kPlayingMovieState = 1
} MovieState;

typedef enum  {
  kStateChangeMovieEvent = 0,
  kRateChangeMovieEvent,
  kAudioFrameProcessedMovieEvent,
  kEndedMovieEvent
} MovieEvent;

class Movie;
typedef void (*MovieListener)(void *ctx, Movie *m, MovieEvent event, void *data);

class Movie {
private:
    std::string filename_;
    pthread_t reader_thread_;
    AVInputFormat *src_format_;
    AVFormatContext *format_ctx_;
    int audio_stream_idx_;
    pthread_mutex_t lock_;
    PacketChan *audio_packet_chan_;
    unsigned int audio_buf_size_;
    AVPacket *curr_audio_packet_;
    AVPacket curr_audio_packet_adj_;
    AVFrame *curr_audio_frame_;
    int curr_audio_frame_offset_;
    int curr_audio_frame_remaining_;
    int64_t duration_;
    int64_t elapsed_;
    int64_t seek_to_;
    AVRational time_base_;
    MovieState state_;
    double volume_;
    MovieListener listener_;
    void *listener_ctx_;

public:
    void SetListener(MovieListener listener, void *ctx);
    void ReadAudio(uint8_t *stream, int len);
    void Read(void);
    int AdvanceFrame(void);
    Movie(const std::string & filename);
    ~Movie();
    void Play();
    void Stop();
    double Duration();
    double Elapsed();
    MovieState state();
    void Seek(double seconds); 
    void SetVolume(double pct); 
    double Volume(); 
    bool isSeeking();
};
#endif

