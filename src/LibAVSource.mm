#import "LibAVSource.h"
#import "Log.h"
#import "Util.h"

extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
}

static AVPacket flushPacket;

@implementation LibAVSource {
  AVPacket packet_;
  AVPacket packetAdj_;
  AVFrame *frame_;
  bool opened_;
  int frameOffset_;
  int frameRemaining_;
  AVFormatContext *formatContext_;
  AVCodecContext *codecContext_;
  int audioStreamIndex_;
  int64_t elapsed_;
  int64_t duration_;
  bool stop_;
  int64_t seekTo_;
  pthread_mutex_t lock_;
  AVRational timeBase_;
  NSURL *url_;
}

- (NSURL *)url {
  return url_;
}

- (void)dealloc {
  [url_ release];
  if (formatContext_) {
    avformat_close_input(&formatContext_);
  }
  if (formatContext_) {
    avformat_free_context(formatContext_);
  }
  av_free_packet(&packet_);
  // maybe free ->data?
  [super dealloc];
}

+ (void)initialize {
  av_init_packet(&flushPacket);
  flushPacket.data = (uint8_t *)"FLUSH";
  //av_log_set_level(AV_LOG_QUIET);
  avcodec_register_all();
  avfilter_register_all();
  av_register_all();
  avformat_network_init();
}

- (id)initWithURL:(NSURL *)url {
  self = [super init];
  if (!url) {
    ERROR(@"expecting URL");
    [self release];
    return nil;
  }
  if (self) {
    url_ = [url retain];
    // Don't retain:
    opened_ = false;
    audioStreamIndex_ = - 1;
    elapsed_ = 0;
    duration_ = 0;
    timeBase_.den = 0;
    timeBase_.num = 0;
    seekTo_ = -1;
    formatContext_ = NULL;
    stop_ = false;
    frame_ = avcodec_alloc_frame();
    avcodec_get_frame_defaults(frame_);
    frameOffset_ = 0;
    frameRemaining_ = 0;

    memset(&packet_, 0, sizeof(AVPacket));
    av_init_packet(&packet_);

    memset(&packetAdj_, 0, sizeof(packetAdj_));
    av_init_packet(&packetAdj_);
    frameOffset_ = 0;
  }
  return self;
}

- (NSError *)open {
  NSError *err = nil;
  //int err = 0;
  duration_ = 0;
  audioStreamIndex_ = -1;
  formatContext_ = avformat_alloc_context();
  AVCodec *codec;

  NSString *url0 = url_.isFileURL ? url_.path : url_.absoluteString;
  err = MkError(@"avformat_open_input", avformat_open_input(&formatContext_, url0.UTF8String, NULL, NULL));
  if (err != nil) { return err; }

  err = MkError(@"avformat_find_stream_info", avformat_find_stream_info(formatContext_, NULL));
  if (err != nil) { return err; }

  for (int i = 0; i < formatContext_->nb_streams; i++) {
    if (formatContext_->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      audioStreamIndex_ = i;
    }
  }

  if (audioStreamIndex_ < 0) {
    ERROR(@"couldnt locate audio stream index");
    err = MkError(@"cant find audio stream index", -1);
    return err;
  }

  timeBase_ = formatContext_->streams[audioStreamIndex_]->time_base;
  duration_ = formatContext_->streams[audioStreamIndex_]->duration;
  elapsed_ = 0;
  codecContext_ = formatContext_->streams[audioStreamIndex_]->codec;
  if (!codecContext_) {
    return MkError(@"open.codecContext", -5000);
  }

  codec = avcodec_find_decoder(codecContext_->codec_id);
  err = MkError(@"avcodec_open2", avcodec_open2(codecContext_, codec, NULL));
  if (err != nil) { return err; }

  // N.B. avformat_seek_.. would fail sporadically, so av_seek_frame is used here instead.
  /*
  if (seekTo_ >= 0)  {
    err = MkError(@"av_seek_frame", av_seek_frame(formatContext_, -1, seekTo_, 0);
    seekTo_ = -1;
  }*/
  return nil;
}

- (NSError *)readPacket:(AVPacket *)packet {
  NSError *err = nil;
  if (!opened_) {
    err = [self open];
    if (err) {
      return err;
    }
    opened_ = true;
  }
  if (seekTo_ >= 0) {
    int seekRet = av_seek_frame(formatContext_, -1, seekTo_, 0);
    if (seekRet < 0) {
      ERROR(@"Failed to seek (%d) to %ld, %f", seekRet, seekTo_, (double)(seekTo_ / ((double)AV_TIME_BASE)));
    }
    for (int i = 0; i < formatContext_->nb_streams; i++) {
      avcodec_flush_buffers(formatContext_->streams[i]->codec);
    }
    elapsed_ = seekTo_;
    seekTo_ = -1;
  }

  while (1) {
    // number of bytes red
    int read = av_read_frame(formatContext_, packet);
    if (read < 0) {
      if (read != -5) {// eof
        return MkError(@"read packet failure", read);
      } else {
        return nil;
      }
    }
    if (packet->size <= 0)  {
      continue;
    }

    if (packet->stream_index != audioStreamIndex_) {
      continue;
    }
    elapsed_ = packet->pts;
    return nil;
  }
}

- (void)seek:(int64_t)usecs {
  seekTo_ = (usecs / ((long double)1000000.0)) * AV_TIME_BASE;
}

- (bool)isSeeking {
  return seekTo_ >= 0;
}

- (NSError *)getAudio:(uint8_t *)stream length:(size_t *)streamLen {
  size_t ret = 0;
  size_t len = *streamLen;
  NSError *err = nil;
  while (len > 0) {
    if (frameRemaining_ > 0) {
      int amt = MIN(len, frameRemaining_);
      memcpy(stream, frame_->data[0] + frameOffset_, amt);
      len -= amt;
      stream += amt;
      ret += amt;
      frameRemaining_ -= amt;
      frameOffset_ += amt;
      continue;
    }
    err = [self readFrame];
    if (err) {
      memset(stream, 0, len);
      break;
    }
  }
  *streamLen = ret;
  return err;
}


- (NSError *)readFrame {
  NSError *err = nil;
  for (;;) {
    // while the packet size is empty
    if (packetAdj_.size <= 0) {
      av_free_packet(&packet_);
      err = [self readPacket:&packet_];
      if (err != nil) { return err; }
      packetAdj_ = packet_;
      // EOF:
      if (packet_.size <= 0) {
        return nil;
      }
      continue;
    }
    if (packetAdj_.data == flushPacket.data)
      avcodec_flush_buffers(codecContext_);

    // Reset the frame
    avcodec_get_frame_defaults(frame_);
    frameRemaining_ = 0;
    frameOffset_ = 0;
    // Each audio packet may contain multiple frames.
    int gotFrame = 0;
    int amtDecoded = avcodec_decode_audio4(codecContext_, frame_, &gotFrame, &packetAdj_);
    if (amtDecoded < 0) {
      char error[256];
      av_strerror(amtDecoded, error, 256);
      err = MkError(@"avcodec_decode_audio4", amtDecoded);
      ERROR(@"decode error: %s", error);

      // skip this packet.
      packetAdj_.size = 0;
      return err;
    }
    if (!gotFrame)
      continue;

    packetAdj_.data += amtDecoded;
    packetAdj_.size -= amtDecoded;
    // find the size of a frame:
    int data_size = av_samples_get_buffer_size(NULL, codecContext_->channels, frame_->nb_samples, codecContext_->sample_fmt, 1);
    frameRemaining_ = data_size;
    break;
  }
  return err;
}

- (int64_t)duration {
  int64_t ret = 0;
  ret = ((((long double)duration_) / timeBase_.den) * timeBase_.num) * 1000000.0;
  return ret;
}

- (int64_t)elapsed {
  int64_t ret = 0;
  ret = ((((long double) elapsed_) / timeBase_.den) * timeBase_.num) * 1000000.0;
  return ret;
}

@end
