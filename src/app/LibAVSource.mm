#import "app/LibAVSource.h"
#import "app/Log.h"

static AVPacket flushPacket;

@interface LibAVSource (Prrrivate) 
- (AVCodecContext *)audioCodecContext;
@end

@implementation LibAVSource

- (NSURL *)url { 
  return url_;
}

- (AVCodecContext *)audioCodecContext {
  if (audioStreamIndex_ < 0) {
    if (!formatContext_)
      return NULL;
    for (int i = 0; i < formatContext_->nb_streams; i++) {
      if (formatContext_->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
        audioStreamIndex_ = i;
        break;
      }
    }
    if (audioStreamIndex_ < 0) 
      return NULL;
  }
  return formatContext_->streams[audioStreamIndex_]->codec;
}

- (void)dealloc { 
  [url_ release];
  if (formatContext_) {
    avformat_close_input(&formatContext_);
  }
  if (formatContext_) {
    avformat_free_context(formatContext_);
  }
  // maybe free ->data?
  [super dealloc];
}

+ (void)initialize { 
  av_init_packet(&flushPacket);
  flushPacket.data = (uint8_t *)"FLUSH";
  av_log_set_level(AV_LOG_QUIET);
  avcodec_register_all();
  avfilter_register_all();
  av_register_all();
  avformat_network_init();
}

- (id)initWithURL:(NSURL *)url { 
  self = [super init];
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
    currAudioFrame_ = avcodec_alloc_frame();
    avcodec_get_frame_defaults(currAudioFrame_);   
    currAudioFrameOffset_ = 0;
    currAudioFrameRemaining_ = 0;
    state_ = kPausedAudioSourceState;

    memset(&currAudioPacket_, 0, sizeof(AVPacket));
    av_init_packet(&currAudioPacket_);

    memset(&currAudioPacketAdj_, 0, sizeof(currAudioPacketAdj_));
    av_init_packet(&currAudioPacketAdj_);
    currAudioFrameOffset_ = 0;
  }
  return self;
}

- (bool)open {
  int err = 0;
  duration_ = 0;
  audioStreamIndex_ = -1;
  formatContext_ = avformat_alloc_context();

  NSString *url0 = url_.isFileURL ? url_.path : url_.absoluteString;
  err = avformat_open_input(&formatContext_, url0.UTF8String, NULL, NULL);
  if (err != 0) {
    ERROR(@"could not open: %d", err);
    return false;
  } 
  err = avformat_find_stream_info(formatContext_, NULL);
  if (err < 0) {
    ERROR(@"could not find stream info");
    return false;
  } 
  for (int i = 0; i < formatContext_->nb_streams; i++) {
    if (formatContext_->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
      audioStreamIndex_ = i;
    }
  }
  if (audioStreamIndex_ < 0) {
    ERROR(@"couldnt locate audio stream index");
    return false;
  }  
  timeBase_ = formatContext_->streams[audioStreamIndex_]->time_base;
  duration_ = formatContext_->streams[audioStreamIndex_]->duration;
  elapsed_ = 0;
  AVCodecContext *audioCodecContext = self.audioCodecContext;
  AVCodec *codec = avcodec_find_decoder(audioCodecContext->codec_id); 
  avcodec_open2(audioCodecContext, codec, NULL);

  // N.B. avformat_seek_.. would fail sporadically, so av_seek_frame is used here instead.
  if (seekTo_ >= 0)  {
    av_seek_frame(formatContext_, -1, seekTo_, 0);
    seekTo_ = -1;
  }

  state_ = kPlayingAudioSourceState;
  return true;
}


- (bool)readPacket:(AVPacket *)packet {  
  if (!opened_) {
    opened_ = [self open];
    if (!opened_)
      return false;
  } 
  if (state_ == kPausedAudioSourceState) {
    return false;
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
    int read = av_read_frame(formatContext_, packet);
    if (read < 0) { 
      if (read != -5) {// eof
        ERROR(@"read packet fail (%d)", read);
      } 
      state_ = kEOFAudioSourceState;
      return false;
    } 
    if (packet->size <= 0)  {
      continue;
    }

    if (packet->stream_index != audioStreamIndex_) {
      continue;
    }
    // Totally confusing:
    // This should be called here to duplicate the ".data" section of a packet.
    elapsed_ = packet->pts;
    return true;
  }
}

- (void)seek:(int64_t)usecs {  
  seekTo_ = (usecs / ((long double)1000000.0)) * AV_TIME_BASE;
}

- (bool)isSeeking { 
  return seekTo_ >= 0;
}

- (void)getAudio:(uint8_t *)stream length:(size_t)len {
  while (len > 0) {
    if (currAudioFrameRemaining_ > 0) {
      int amt = MIN(len, currAudioFrameRemaining_);
      memcpy(
          stream, 
          currAudioFrame_->data[0] + currAudioFrameOffset_, 
          amt);
      len -= amt;
      stream += amt;
      currAudioFrameRemaining_ -= amt;
      currAudioFrameOffset_ += amt;
      continue;
    }
    if (![self readFrame]) {
      memset(stream, 0, len);
      break;
    }
  }
}

- (bool)readFrame { 
  for (;;) {
    if (currAudioPacketAdj_.size <= 0) {
      av_free_packet(&currAudioPacket_);
      if (![self readPacket:&currAudioPacket_]) {
        return false;
      }
      currAudioPacketAdj_ = currAudioPacket_;
      continue;
    }
    if (currAudioPacketAdj_.data == flushPacket.data)
      avcodec_flush_buffers(self.audioCodecContext);

    // Reset the frame
    avcodec_get_frame_defaults(currAudioFrame_);   
    currAudioFrameRemaining_ = 0;
    currAudioFrameOffset_ = 0;
    // Each audio packet may contain multiple frames.
    int gotFrame = 0;
    int amtDecoded = avcodec_decode_audio4(
        self.audioCodecContext,
        currAudioFrame_, 
        &gotFrame,
        &currAudioPacketAdj_);
    if (amtDecoded < 0) {
      char error[256];
      av_strerror(amtDecoded, error, 256);
      ERROR(@"decode error: %s", error);
      // skip this packet.
      currAudioPacketAdj_.size = 0;
      continue;
    } 
    if (!gotFrame)
      continue;

    currAudioPacketAdj_.data += amtDecoded;
    currAudioPacketAdj_.size -= amtDecoded;
    // find the size of a frame:
    int data_size = av_samples_get_buffer_size(
        NULL,
        self.audioCodecContext->channels,
        currAudioFrame_->nb_samples,
        self.audioCodecContext->sample_fmt, 
        1);
    currAudioFrameRemaining_ = data_size;
    return true;
  } 
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

- (bool)isPaused {
  return state_ != kPlayingAudioSourceState;
}

- (void)setIsPaused:(bool)isPaused {
  @synchronized(self) {
    if (isPaused) { 
      if (state_ == kPlayingAudioSourceState)  {
        state_ = kPausedAudioSourceState;
      }
    } else {
      if (state_ == kPausedAudioSourceState) {
        state_ = kPlayingAudioSourceState;
      }
    }
  }
}

- (AudioSourceState)state {
  return state_;  
}
@end
