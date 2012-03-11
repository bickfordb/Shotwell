
#ifndef _MOVIE_H_
#define _MOVIE_H_

#include <string>
#include <pthread.h>
#include <tr1/memory>

using namespace std;
using namespace std::tr1;

void MovieInit();
int MovieStartRAOP(const string &host, int port);
void MovieStartSDL();

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
class ReaderThreadState;
typedef void (*MovieListener)(void *ctx, Movie *m, MovieEvent event, void *data);
double GetVolume();
void SetVolume(double);

class Movie {
private:
    string filename_;
    pthread_mutex_t lock_;
    MovieListener listener_;
    void *listener_ctx_;
    shared_ptr<ReaderThreadState> reader_thread_state_;
    void Lock();
    void Unlock();
public:
    void SetListener(MovieListener listener, void *ctx); 
    void Signal(MovieEvent event, void *data);
    Movie(const std::string & filename);
    ~Movie();
    void Play();
    void Stop();
    double Duration();
    double Elapsed();
    MovieState state();
    void Seek(double seconds); 
    string filename() { return filename_; }
    bool IsSeeking();
};
#endif

