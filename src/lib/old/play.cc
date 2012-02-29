#include <stdio.h>
#include "play.h"
#include <inttypes.h>
#include <math.h>
#include <limits.h>
#include <libavutil/avutil.h>
#include <libavutil/avstring.h>
#include <libavformat/avformat.h>
#include <libavdevice/avdevice.h>
#include <libswscale/swscale.h>
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/avfiltergraph.h>

#include <SDL/SDL.h>
#include <SDL/SDL_thread.h>
#include "log.h"

#define MAX_QUEUE_SIZE (15 * 1024 * 1024)
#define MIN_AUDIOQ_SIZE (20 * 16 * 1024)
#define MIN_FRAMES 5

/* SDL audio buffer size, in samples. Should be small to have precise
   A/V sync as SDL does not have hardware buffer fullness info. */
#define SDL_AUDIO_BUFFER_SIZE 1024

/* no AV sync correction is done if below the AV sync threshold */
#define AV_SYNC_THRESHOLD 0.01
/* no AV correction is done if too big error */
#define AV_NOSYNC_THRESHOLD 10.0

#define FRAME_SKIP_FACTOR 0.05

/* maximum audio speed change to get correct sync */
#define SAMPLE_CORRECTION_PERCENT_MAX 10

/* we use about AUDIO_DIFF_AVG_NB A-V differences to make the average */
#define AUDIO_DIFF_AVG_NB   20

/* NOTE: the size must be big enough to compensate the hardware audio buffersize size */
#define SAMPLE_ARRAY_SIZE (2 * 65536)

static int sws_flags = SWS_BICUBIC;
static AVPacket flush_pkt;

struct PacketQueue {
    AVPacketList *first_pkt;
    AVPacketList *last_pkt;
    int nb_packets;
    int size;
    int abort_request;
    SDL_mutex *mutex;
    SDL_cond *cond;
};

#define VIDEO_PICTURE_QUEUE_SIZE 2
#define SUBPICTURE_QUEUE_SIZE 4
#define AUDIO_CTX(m) m->format_ctx->streams[m->audio_stream_idx]->codec

struct Media {
    SDL_Thread *decode_thread;
    AVInputFormat *src_format;
    char *filename;
    AVFormatContext *format_ctx;
    int audio_stream_idx;
    struct PacketQueue audio_queue;
    AVPacket audio_pkt_temp;
    AVPacket audio_pkt;
    AVFrame *frame;
    uint8_t *audio_buf;
    unsigned int audio_buf_size;
    int audio_buf_idx;
    int paused;
    uint8_t silence_buf[SDL_AUDIO_BUFFER_SIZE];
};


static int decode(void *a);
static int get_stream_index(AVFormatContext *c, int codec_type);
static int audio_decode_frame(struct Media *media);
static int media_init(struct Media *media, const char *filename);
static struct Media *media_alloc();
static struct Media *play_open(const char *filename);
static void audio_callback(void *userdata, Uint8 *stream, int len);
static void media_dealloc(struct Media *media);
static void packet_queue_init(struct PacketQueue *q);
static int packet_queue_put(struct PacketQueue *q, AVPacket *pkt);
static int packet_queue_get(struct PacketQueue *q, AVPacket *pkt, int block);

static void packet_queue_init(struct PacketQueue *q) {
  memset(q, 0, sizeof(struct PacketQueue));
  q->mutex = SDL_CreateMutex();
  q->cond = SDL_CreateCond();
}

static int packet_queue_put(struct PacketQueue *q, AVPacket *pkt) {

  AVPacketList *pkt1;
  if(av_dup_packet(pkt) < 0) {
    return -1;
  }
  pkt1 = av_malloc(sizeof(AVPacketList));
  if (!pkt1)
    return -1;
  pkt1->pkt = *pkt;
  pkt1->next = NULL;
  
  
  SDL_LockMutex(q->mutex);
  
  if (!q->last_pkt)
    q->first_pkt = pkt1;
  else
    q->last_pkt->next = pkt1;
  q->last_pkt = pkt1;
  q->nb_packets++;
  q->size += pkt1->pkt.size;
  SDL_CondSignal(q->cond);
  
  SDL_UnlockMutex(q->mutex);
  return 0;
}

int quit = 0;

static int packet_queue_get(struct PacketQueue *q, AVPacket *pkt, int block)
{
  AVPacketList *pkt1;
  int ret;
  INFO("lock mutex"); 
  SDL_LockMutex(q->mutex);
  INFO("after lock mutex"); 
  
  for(;;) {
    INFO("loop");
    
    if(quit) {
      ret = -1;
      break;
    }

    pkt1 = q->first_pkt;
    if (pkt1) {
      q->first_pkt = pkt1->next;
      if (!q->first_pkt)
	q->last_pkt = NULL;
      q->nb_packets--;
      q->size -= pkt1->pkt.size;
      *pkt = pkt1->pkt;
      av_free(pkt1);
      ret = 1;
      break;
    } else if (!block) {
      ret = 0;
      break;
    } else {
      log("wait");
      SDL_CondWait(q->cond, q->mutex);
    }
  }
  log("unlock");
  SDL_UnlockMutex(q->mutex);
  log("after unlock");
  return ret;
}

static struct Media *media_alloc()
{
  return calloc(sizeof(struct Media), 1);
}

static int media_init(struct Media *media, const char *filename)
{
  media->filename = malloc(strlen(filename) + 1);
  if (media->filename == NULL)
    return -1;
  strcpy(media->filename, filename);
  media->audio_stream_idx = -1;
  av_init_packet(&media->audio_pkt);
  av_init_packet(&media->audio_pkt_temp);
  media->frame = avcodec_alloc_frame();
  avcodec_get_frame_defaults(media->frame);
  media->audio_buf_idx = 0;
  media->audio_buf_size = 0; 
  media->audio_buf = NULL;
  packet_queue_init(&media->audio_queue);
  return 0;
}


static void media_dealloc(struct Media *media) {
  if (media == NULL) {
    return;
  }
  if (media->filename) {
    free(media->filename);
    media->filename = NULL;
  }
  free(media);
}



static struct Media *play_open(const char *filename)
{
    struct Media *media = media_alloc();
    if (media == NULL) {
      log("failed to alloc");
      goto fail;
    }
    log("alloc");
    if (media_init(media, filename) != 0) {
      media_dealloc(media);
      log("failed to init");
      goto fail;
    }
    log("f: %s", media->filename);
    media->decode_thread = SDL_CreateThread(decode, media);
    if (!media->decode_thread) {
      log("could not create thread");
      goto fail;
    }  
    return media;
fail:
    log("failed to open");
    media_dealloc(media);
    return NULL;
}

static int get_stream_index(AVFormatContext *c, int codec_type) {
  for (int i = 0; i < c->nb_streams; i++) {
    if (c->streams[i]->codec->codec_type == codec_type) {
      return i;
    }
  }
  return -1;    
}

static int audio_decode_frame(struct Media *media) {
  AVPacket *pkt_temp = &media->audio_pkt_temp;
  AVPacket *pkt = &media->audio_pkt;
  AVCodecContext *dec = AUDIO_CTX(media);
  int n, len1, data_size, got_frame;
  double pts;
  int new_packet = 0;
  int flush_complete = 0;

  for (;;) {
    log("decode frame loop");
    log("pkt_temp.size: %d"
        " pkt_temp.data: %p"
        " new_packet: %d", 
        pkt_temp->size,
        pkt_temp->data,
        new_packet);
    /* NOTE: the audio packet can contain several frames */
    while (pkt_temp->size > 0 || (!pkt_temp->data && new_packet)) {
      avcodec_get_frame_defaults(media->frame);

      if (flush_complete)
        break;
      new_packet = 0;
      log("decode audio4");
      len1 = avcodec_decode_audio4(dec, media->frame, &got_frame, pkt_temp);
      log("decode result: %d", len1);
      if (len1 < 0) {
        /* if error, we skip the frame */
        pkt_temp->size = 0;
        break;
      }

      pkt_temp->data += len1;
      pkt_temp->size -= len1;

      if (!got_frame) {
        log("no frame");
        /* stop sending empty packets if the decoder is finished */
        if (!pkt_temp->data && dec->codec->capabilities & CODEC_CAP_DELAY) { 
          log("flush complete");
          flush_complete = 1;
        }
        continue;
      }
      log("get buffer size");
      data_size = av_samples_get_buffer_size(NULL, dec->channels,
          media->frame->nb_samples,
          dec->sample_fmt, 1);
      log("data: %d", data_size); 
      media->audio_buf = media->frame->data[0];
      media->audio_buf_size = data_size;
      return data_size;
    }

    log("pkt");

    /* free the current packet */
    if (pkt->data)
      av_free_packet(pkt);
    log("free pkt");
    memset(pkt_temp, 0, sizeof(*pkt_temp));

    if (media->paused || media->audio_queue.abort_request) {
      log("paused");
      goto error;
    }

    log("get packet");
    /* read next packet */
    if ((new_packet = packet_queue_get(&media->audio_queue, pkt, 1)) < 0) {
      log("error getting packet");
      goto error;
    }
    log("got backet: %p", new_packet);

    if (pkt->data == flush_pkt.data) {
      log("flush buffers");
      avcodec_flush_buffers(dec);
    }

    *pkt_temp = *pkt;
  }

  error:
    log("error decoding");
    return -1;
}

static int audio_decode_frame2(struct Media *media);
static int audio_decode_frame2(struct Media *media) {
  AVPacket *pkt_temp = &media->audio_pkt_temp;
  AVPacket *pkt = &media->audio_pkt;
  AVCodecContext *dec = AUDIO_CTX(media);
  int n, len1, data_size, got_frame;
  double pts;
  int new_packet = 0;
  int flush_complete = 0;

  for (;;) {
    log("decode frame loop");
    if (media->audio_pkt.size == 0) {
      if (packet_queue_get(&media->audio_queue, &media->audio_pkt) < 0) { 
        log("unable to read from packet queue");
        goto error;
      }
    }
  }
  error:
    log("error decoding");
    return -1;
}

static void audio_callback(void *userdata, Uint8 *stream, int len) {
  log("audio callback: %p", userdata);
  struct Media *media = (struct Media *)userdata;
    int audio_size, len1;
    double pts;

    while (len > 0) {
        log("len: %d, audio_buf_size: %d, audio_buf_idx: %d", 
            len, 
            media->audio_buf_size,
            media->audio_buf_idx
            );
        if (media->audio_buf_idx >= media->audio_buf_size) {
           log("decoding frame");
           audio_size = audio_decode_frame2(media);
           log("decode %d", audio_size);
           if (audio_size < 0) {
                /* if error, just output silence */
               media->audio_buf = media->silence_buf;
               media->audio_buf_size = sizeof(media->silence_buf);
           } else {
               //audio_size = synchronize_audio(media, (int16_t *)media->audio_buf, audio_size,
               //                               pts);
               //media->audio_buf_size = audio_size;
           }
           media->audio_buf_idx = 0;
        }
        len1 = media->audio_buf_size - media->audio_buf_idx;
        if (len1 > len)
            len1 = len;
        memcpy(stream, (uint8_t *)media->audio_buf + media->audio_buf_idx, len1);
        len -= len1;
        stream += len1;
        media->audio_buf_idx += len1;
    }
}

static int decode(void *context) {
  log("decoder thread");
  struct Media *media = (struct Media *)context;
  AVDictionary **opts = NULL;
  AVDictionaryEntry *t;
  AVPacket pkt1, *pkt = &pkt1;
  int eof = 0;
  int err;
  int i;
  int pkt_in_play_range = 0;
  int ret;
  media->audio_stream_idx = -1;
  log("opening: %s", media->filename); 
  err = avformat_open_input(&media->format_ctx, media->filename, NULL, NULL);
  if (err != 0) {
    log("could not open: %d", err);
    goto fail;
  } 
  printf("opened\n");
  err = avformat_find_stream_info(media->format_ctx, NULL);
  if (err < 0) {
    log("could not find stream info");
    goto fail;
  } 
  log("found stream info");
  media->audio_stream_idx = get_stream_index(
      media->format_ctx, 
      AVMEDIA_TYPE_AUDIO);
  log("dumping");
  av_dump_format(
      media->format_ctx, 
      media->audio_stream_idx,  
      media->filename,
      0);
  log("got stream index: %d\n", media->audio_stream_idx);
  SDL_AudioSpec req_spec;
  SDL_AudioSpec spec;
  AVCodecContext *audio_codec_ctx = AUDIO_CTX(media);
  
  req_spec.freq = audio_codec_ctx->sample_rate;
  req_spec.format = AUDIO_S16SYS;
  req_spec.channels = audio_codec_ctx->channels;
  req_spec.silence = 0;
  req_spec.samples = SDL_AUDIO_BUFFER_SIZE;
  req_spec.callback = audio_callback;
  req_spec.userdata = media;
  
  if(SDL_OpenAudio(&req_spec, &spec) < 0) {
    log("open audio failed: %s", SDL_GetError());
    goto fail;
  }
  log("opened audio");
  SDL_PauseAudio(0);

  //AVPacket packet;
  SDL_Event event;
  log("reading frames");
  while (1) {
    AVPacket *packet = malloc(sizeof(AVPacket));
    memset(packet, 0, sizeof(packet));
    av_init_packet(packet);
    //av_init_packet(&packet);
    int read = av_read_frame(media->format_ctx, packet);
    if (read < 0) { 
      log("read frame fail: %d", read);
      break;
    } 
    if (packet->stream_index != media->audio_stream_idx) {
      av_free_packet(packet);
      continue;
    }

    int put = packet_queue_put(&media->audio_queue, packet);
    if (put < 0) 
      log("failed to put packet: %d", put);
    SDL_PollEvent(&event);
    //log("poll event: %d", (int)event.type);
  }

  return 0;
fail:
  if (media->format_ctx != NULL)
    avformat_free_context(media->format_ctx);
  return -1;
}

int play_init() { 
  // libav init
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
      log("Could not initialize SDL - %s\n", SDL_GetError());
      exit(1);
  } 
  return 0;
}


struct Media *play(const char *filename) {
  printf("play: %s\n", filename);
  struct Media *media = play_open(filename);
  AVPacket flush_pkt;
  AVInputFormat *input_format;
  av_init_packet(&flush_pkt);
  flush_pkt.data = "FLUSH";
  return 0;
}
