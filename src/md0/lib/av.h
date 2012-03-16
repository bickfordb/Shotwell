#ifndef _AV_H_
#define _AV_H_

extern "C" {

#include <libavutil/avutil.h>
#include <libavutil/avstring.h>
#include <libavformat/avformat.h>
#include <libavdevice/avdevice.h>
#include <libswscale/swscale.h>
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/avfiltergraph.h>
}

void AVInit();
#endif
