#import "app/AV.h"

static int av_inited = 0;

void AVInit() { 
  if (av_inited)
    return;
  av_log_set_level(AV_LOG_QUIET);
  avcodec_register_all();
  avdevice_register_all();
  avfilter_register_all();
  av_register_all();
  avformat_network_init();
  av_inited = 1;
}
