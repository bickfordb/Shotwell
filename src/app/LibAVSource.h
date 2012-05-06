// libav based AudioSource
#import <Cocoa/Cocoa.h>
#import "AudioSource.h"
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
}

@interface LibAVSource : NSObject <AudioSource> {
  AVPacket currAudioPacket_;
  AVPacket currAudioPacketAdj_;
  AVFrame *currAudioFrame_;
  bool opened_;
  int currAudioFrameOffset_;
  int currAudioFrameRemaining_; 
  AVFormatContext *formatContext_;
  int audioStreamIndex_;
  int64_t elapsed_;
  int64_t duration_;
  bool stop_;
  int64_t seekTo_;
  AudioSourceState state_; 
  pthread_mutex_t lock_; 
  AVRational timeBase_;
  NSString *url_;
}
- (bool)readFrame;
- (bool)readPacket:(AVPacket *)packet;
- (id)initWithURL:(NSString *)s;

- (NSString *)url;
@end
// vim: filetype=objcpp
