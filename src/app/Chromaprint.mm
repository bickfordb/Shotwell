#include "app/Chromaprint.h"

#include <stdio.h>
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <chromaprint.h>
}

size_t kBufferSize = AVCODEC_MAX_AUDIO_FRAME_SIZE * 2;
size_t kMaxLength = 60;
NSString *kChromaprintAPIKey = @"bCv9x45K";

int ChromaprintFingerprint(NSString *path, NSString **fingerprint, int *duration) {
  av_register_all();
  av_log_set_level(AV_LOG_ERROR);
  ChromaprintContext *chromaprint = chromaprint_new(CHROMAPRINT_ALGORITHM_DEFAULT);
  int i, ok = -1, remaining, length, consumed, bufferSize, codecContextOpened = 0;
  char *fingerprintBytes = NULL;
  AVFormatContext *formatCtx = NULL;
  AVCodecContext *codecCtx = NULL;
  AVCodec *codec = NULL;
  AVStream *stream = NULL;
  AVPacket packet, packetTemp;
#ifdef HAVE_AV_AUDIO_CONVERT
  AVAudioConvert *convert_ctx = NULL;
#endif
  int16_t *buffer;
  AVFrame *frame = avcodec_alloc_frame();
  avcodec_get_frame_defaults(frame);

  if (avformat_open_input(&formatCtx, path.UTF8String, NULL, NULL) != 0) {
    ok = -2;
    goto done;
  }
  if (avformat_find_stream_info(formatCtx, 0) < 0) {
    ok = -3;
    goto done;
  }

  for (i = 0; i < formatCtx->nb_streams; i++) {
    codecCtx = formatCtx->streams[i]->codec;
    if (codecCtx && codecCtx->codec_type == AVMEDIA_TYPE_AUDIO) {
      stream = formatCtx->streams[i];
      break;
    }
  }
  if (!stream) {
    ok = -4;
    goto done;
  }

  codec = avcodec_find_decoder(codecCtx->codec_id);
  if (!codec) {
    ok = -5;
    goto done;
  }

  if (avcodec_open2(codecCtx, codec, NULL) < 0) {
    ok = -6;
    goto done;
  }
  codecContextOpened = 1;

  if (codecCtx->channels <= 0) {
    ok = -7;
    goto done;
  }
  if (codecCtx->sample_fmt != AV_SAMPLE_FMT_S16) {
    ok = -8;
    goto done;
  }

  av_init_packet(&packet);
  av_init_packet(&packetTemp);

  remaining = kMaxLength * codecCtx->channels * codecCtx->sample_rate;
	*duration = stream->time_base.num * stream->duration / stream->time_base.den;
  chromaprint_start(chromaprint, codecCtx->sample_rate, codecCtx->channels);
  while (1) {
    if (av_read_frame(formatCtx, &packet) < 0) {
      break;
    }

    packetTemp.data = packet.data;
    packetTemp.size = packet.size;
    while (packetTemp.size > 0) {
      bufferSize = kBufferSize;
      int gotFrame = 0;
      avcodec_get_frame_defaults(frame);
      consumed = avcodec_decode_audio4(codecCtx, frame, &gotFrame, &packetTemp);
      if (consumed < 0) {
        break;
      }
      packetTemp.data += consumed;
      packetTemp.size -= consumed;

      if (bufferSize <= 0) {
        if (bufferSize < 0) {
          fprintf(stderr, "WARNING: size returned from avcodec_decode_audioX is too small\n");
        }
        continue;
      }
      if (bufferSize > kBufferSize) {
        fprintf(stderr, "WARNING: size returned from avcodec_decode_audioX is too large\n");
        continue;
      }
      buffer = (int16_t *)frame->data[0];
      //length = MIN(remaining, bufferSize / 2);
      length = frame->linesize[0] / 2;
      remaining -= length;
      if (!chromaprint_feed(chromaprint, buffer, length)) {
        ok = -10;
        goto done;
      }

      if (kMaxLength) {
        remaining -= length;
        if (remaining <= 0) {
          goto finish;
        }
      }
    }
  }
finish:
  if (!chromaprint_finish(chromaprint)) {
    ok = -100;
    goto done;
  }
  if (!chromaprint_get_fingerprint(chromaprint, &fingerprintBytes)) {
    ok = -101;
    goto done;
  }
  *fingerprint = [NSString stringWithUTF8String:fingerprintBytes];
  chromaprint_dealloc(fingerprintBytes);
  ok = 0;
done:
  if (packet.data) {
    av_free_packet(&packet);
  }
  if (codecContextOpened) {
    avcodec_close(codecCtx);
  }
  if (formatCtx) {
    avformat_close_input(&formatCtx);
  }
  if (formatCtx) {
    avformat_free_context(formatCtx);
  }
  return ok;
}

NSDictionary *AcousticIDLookup(NSString *apiKey, NSString *fingerprint, int duration) {
  id result = nil;
  NSHTTPURLResponse *response = nil;
  NSError *error = nil;
  if (!apiKey) apiKey = kChromaprintAPIKey;

  NSString *s = [NSString stringWithFormat:@"http://api.acoustid.org/v2/lookup?duration=%d&fingerprint=%@&client=%@", duration, fingerprint, apiKey];
  NSURL *url = [NSURL URLWithString:s];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:1.0];
  NSData *body = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
  if (body) {
    result = [NSJSONSerialization JSONObjectWithData:body options:NSJSONReadingAllowFragments error:&error];
  }
  if (error) {
    NSLog(@"error: %@", error);
  }
  return result;
}

int ChromaprintGetAcousticID(NSString *apiKey, NSString *path, NSString **acousticID, double *score) {
    int st = 0;
    int duration = 0;
    NSString *key = nil;
    st = ChromaprintFingerprint(path, &key, &duration);
    if (st)
      return st;
    NSDictionary *response = AcousticIDLookup(@"bCv9x45K", key, duration);
    if (!response) {
      return -1000;
    }
    if ([response[@"status"] isEqualToString:@"ok"]) {
      NSArray *results = response[@"results"];
      for (NSDictionary *i in results) {
        *score = [i[@"score"] doubleValue];
        *acousticID = i[@"id"];
        break;
      }
    }
    return 0;
}

