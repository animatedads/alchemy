#include "vision_ffmpeg.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
#include <libavutil/pixdesc.h>
#include <libswscale/swscale.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

struct VisionFfmpeg {
    AVFormatContext *fmt;
    AVCodecContext *dec;
    AVFrame *frame;
    AVPacket *pkt;
    struct SwsContext *sws;
    int stream, w, h;
    double fps, next_due, first_pts, last_pts;
    long decoded, emitted;
    AVRational tb;
};

static void msg(char *e,size_t n,const char *s){ if(e&&n)snprintf(e,n,"%s",s?s:""); }
static void averr(char *e,size_t n,const char *where,int rc){
    char b[160]; av_strerror(rc,b,sizeof b);
    if(e&&n) snprintf(e,n,"%s: %s (%d)",where,b,rc);
}
void vision_ffmpeg_close(VisionFfmpeg *v){
    if(!v)return;
    sws_freeContext(v->sws); av_packet_free(&v->pkt); av_frame_free(&v->frame);
    avcodec_free_context(&v->dec); avformat_close_input(&v->fmt); free(v);
}
VisionFfmpeg *vision_ffmpeg_open(const char *url,int w,int h,double fps,char *e,size_t n){
    VisionFfmpeg *v=calloc(1,sizeof *v); int rc; const AVCodec *codec=NULL;
    AVDictionary *opts=NULL;
    if(!v){msg(e,n,"allocation failed");return NULL;}
    v->w=w; v->h=h; v->fps=fps>0?fps:5.0;
    v->next_due=NAN; v->first_pts=NAN; v->last_pts=NAN;

    /* Live MJPEG needs very little probing.  Avoid consuming most of a short
       qualification window in stream analysis. */
    av_dict_set(&opts,"probesize","32768",0);
    av_dict_set(&opts,"analyzeduration","250000",0);
    if((rc=avformat_open_input(&v->fmt,url,NULL,&opts))<0){
        av_dict_free(&opts); averr(e,n,"avformat_open_input",rc); goto fail;
    }
    av_dict_free(&opts);
    if((rc=avformat_find_stream_info(v->fmt,NULL))<0){averr(e,n,"avformat_find_stream_info",rc);goto fail;}
    rc=av_find_best_stream(v->fmt,AVMEDIA_TYPE_VIDEO,-1,-1,&codec,0);
    if(rc<0){averr(e,n,"av_find_best_stream",rc);goto fail;} v->stream=rc;
    v->tb=v->fmt->streams[v->stream]->time_base;
    v->dec=avcodec_alloc_context3(codec); if(!v->dec){msg(e,n,"avcodec_alloc_context3 failed");goto fail;}
    if((rc=avcodec_parameters_to_context(v->dec,v->fmt->streams[v->stream]->codecpar))<0){averr(e,n,"parameters_to_context",rc);goto fail;}
    if((rc=avcodec_open2(v->dec,codec,NULL))<0){averr(e,n,"avcodec_open2",rc);goto fail;}
    v->frame=av_frame_alloc(); v->pkt=av_packet_alloc();
    if(!v->frame||!v->pkt){msg(e,n,"frame/packet allocation failed");goto fail;}
    return v;
fail: vision_ffmpeg_close(v); return NULL;
}
static double frame_time(VisionFfmpeg *v){
    int64_t p=v->frame->best_effort_timestamp;
    if(p==AV_NOPTS_VALUE) {
        if(isnan(v->last_pts)) return 0.0;
        return v->last_pts + 1.0/25.0;
    }
    return p*av_q2d(v->tb);
}
static int convert(VisionFfmpeg *v,unsigned char *dst,size_t cap,double t,double *ts,char *e,size_t n){
    size_t need=(size_t)v->w*v->h*3; if(cap<need){msg(e,n,"destination too small");return -2;}

    enum AVPixelFormat srcfmt=(enum AVPixelFormat)v->frame->format;
    int srcRange=(v->frame->color_range==AVCOL_RANGE_JPEG);
    /* YUVJ formats are layout-compatible full-range YUV formats.  Tell
       swscale that explicitly instead of asking it to instantiate a deprecated
       YUVJ conversion context. */
    if(srcfmt==AV_PIX_FMT_YUVJ420P){srcfmt=AV_PIX_FMT_YUV420P;srcRange=1;}
    else if(srcfmt==AV_PIX_FMT_YUVJ422P){srcfmt=AV_PIX_FMT_YUV422P;srcRange=1;}
    else if(srcfmt==AV_PIX_FMT_YUVJ444P){srcfmt=AV_PIX_FMT_YUV444P;srcRange=1;}

    v->sws=sws_getCachedContext(v->sws,v->frame->width,v->frame->height,srcfmt,
                                v->w,v->h,AV_PIX_FMT_RGB24,SWS_AREA,NULL,NULL,NULL);
    if(!v->sws){msg(e,n,"sws_getCachedContext failed");return -3;}
    const int *coeff=sws_getCoefficients(SWS_CS_DEFAULT);
    sws_setColorspaceDetails(v->sws,coeff,srcRange,coeff,1,0,1<<16,1<<16);

    uint8_t *out[4]={dst,NULL,NULL,NULL}; int stride[4]={v->w*3,0,0,0};
    sws_scale(v->sws,(const uint8_t * const*)v->frame->data,v->frame->linesize,0,v->frame->height,out,stride);
    if(ts)*ts=t;
    v->emitted++;
    return 1;
}
int vision_ffmpeg_next_rgb24(VisionFfmpeg *v,unsigned char *dst,size_t cap,double *ts,char *e,size_t n){
    int rc;
    for(;;){
        while((rc=avcodec_receive_frame(v->dec,v->frame))>=0){
            double t=frame_time(v); v->decoded++; v->last_pts=t;
            if(isnan(v->first_pts)){v->first_pts=t; v->next_due=t;}
            if(t+1e-6 < v->next_due) continue;

            /* Advance on the requested output clock, not on whichever source
               frame happened to cross the threshold.  This prevents drift. */
            do { v->next_due += 1.0/v->fps; } while(v->next_due <= t);
            return convert(v,dst,cap,t,ts,e,n);
        }
        if(rc!=AVERROR(EAGAIN) && rc!=AVERROR_EOF){averr(e,n,"avcodec_receive_frame",rc);return -4;}
        rc=av_read_frame(v->fmt,v->pkt);
        if(rc<0) return 0;
        if(v->pkt->stream_index==v->stream){
            rc=avcodec_send_packet(v->dec,v->pkt); av_packet_unref(v->pkt);
            if(rc<0 && rc!=AVERROR(EAGAIN)){averr(e,n,"avcodec_send_packet",rc);return -5;}
        } else av_packet_unref(v->pkt);
    }
}
