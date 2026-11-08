/* ooRexx Media Object Access: native H.264 codec-only provider.
 * ooRexx owns demux, PES assembly, seek, PTS and frame selection.
 * This provider consumes complete Annex-B video access units, uses the
 * installed libavcodec shared library in-process, and returns RGB24 pixels.
 * No ffmpeg process, libavformat, media filename, networking or file IO.
 * ABI is deliberately pinned to libavcodec 61/libavutil 59/libswscale 8.
 * When matching developer headers are available prefer using upstream
 * headers; this small ABI excerpt is necessary for this runtime-only build.
 */
#include <rexx.h>
#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <string>
#include <vector>
#include <deque>
#include <mutex>
#include <unordered_map>
#include <memory>
#include <algorithm>
#include <cstdio>
#include <dlfcn.h>

struct AVCodec; struct AVCodecContext; struct AVBufferRef; struct AVPacketSideData;
struct AVPacketPartial { AVBufferRef *buf; int64_t pts,dts; uint8_t *data; int size; };
struct AVFramePartial { uint8_t *data[8]; int linesize[8]; uint8_t **extended_data; int width,height; int nb_samples; int format; int key_frame; int pict_type; struct {int num,den;} sample_aspect_ratio; int64_t pts; };

using u32 = unsigned;
struct Library {
  void *codec=nullptr,*util=nullptr,*swscale=nullptr;
  unsigned (*avcodec_version)()=nullptr;
  unsigned (*avutil_version)()=nullptr;
  unsigned (*swscale_version)()=nullptr;
  const AVCodec *(*find_decoder)(int)=nullptr;
  AVCodecContext *(*alloc_context)(const AVCodec*)=nullptr;
  int (*open)(AVCodecContext*,const AVCodec*,void*)=nullptr;
  int (*send)(AVCodecContext*,const void*)=nullptr;
  int (*receive)(AVCodecContext*,void*)=nullptr;
  void (*free_context)(AVCodecContext**)=nullptr;
  void *(*packet_alloc)()=nullptr;
  int (*packet_from_data)(void*,uint8_t*,int)=nullptr;
  void (*packet_free)(void**)=nullptr;
  void *(*frame_alloc)()=nullptr;
  void (*frame_unref)(void*)=nullptr;
  void (*frame_free)(void**)=nullptr;
  void *(*mem_allocz)(size_t)=nullptr;
  void (*mem_free)(void*)=nullptr;
  const char *(*pix_fmt_name)(int)=nullptr;
  void *(*scale_context)(int,int,int,int,int,int,int,void*,void*,const double*)=nullptr;
  int (*scale)(void*,const uint8_t *const*,const int*,int,int,uint8_t *const*,const int*)=nullptr;
  void (*scale_free)(void*)=nullptr;
  std::string error;
  template<class T> bool bind(T &fn,void *handle,const char *name) {
    fn=reinterpret_cast<T>(dlsym(handle,name));
    if (!fn) {error=std::string("missing codec symbol ")+name;return false;}
    return true;
  }
  bool init(){
    codec=dlopen("libavcodec.so.61",RTLD_NOW|RTLD_LOCAL);
    util=dlopen("libavutil.so.59",RTLD_NOW|RTLD_LOCAL);
    swscale=dlopen("libswscale.so.8",RTLD_NOW|RTLD_LOCAL);
    if (!codec||!util||!swscale){error="required libavcodec61/libavutil59/libswscale8 unavailable";return false;}
    if(!bind(avcodec_version,codec,"avcodec_version")||
       !bind(avutil_version,util,"avutil_version")||
       !bind(swscale_version,swscale,"swscale_version"))return false;
    if((avcodec_version()>>16)!=61||(avutil_version()>>16)!=59||(swscale_version()>>16)!=8){error="FFmpeg public ABI major mismatch";return false;}
    return bind(find_decoder,codec,"avcodec_find_decoder")&&
      bind(alloc_context,codec,"avcodec_alloc_context3")&&
      bind(open,codec,"avcodec_open2")&&
      bind(send,codec,"avcodec_send_packet")&&
      bind(receive,codec,"avcodec_receive_frame")&&
      bind(free_context,codec,"avcodec_free_context")&&
      bind(packet_alloc,codec,"av_packet_alloc")&&
      bind(packet_from_data,codec,"av_packet_from_data")&&
      bind(packet_free,codec,"av_packet_free")&&
      bind(frame_alloc,util,"av_frame_alloc")&&
      bind(frame_unref,util,"av_frame_unref")&&
      bind(frame_free,util,"av_frame_free")&&
      bind(mem_allocz,util,"av_mallocz")&&
      bind(mem_free,util,"av_free")&&
      bind(pix_fmt_name,util,"av_get_pix_fmt_name")&&
      bind(scale_context,swscale,"sws_getContext")&&
      bind(scale,swscale,"sws_scale")&&
      bind(scale_free,swscale,"sws_freeContext");
  }
};
static Library lib;
struct Frame {int width=0,height=0;int64_t pts=-1;std::vector<uint8_t> rgb;};
struct Session {
  AVCodecContext *ctx=nullptr;
  void *frame=nullptr;
  std::deque<Frame> output;
  size_t sent=0,received=0;
  ~Session(){ if(frame)lib.frame_free(&frame);if(ctx)lib.free_context(&ctx); }
};
static std::mutex gate;
static std::unordered_map<long,std::unique_ptr<Session>> sessions;
static long nextToken=1;
static std::string lastError;
static void error(const std::string &e){lastError=e;}
static bool writeResult(PRXSTRING ret,const void *ptr,size_t len){
  if(len>64*1024*1024){error("oversize native result");return false;}
  char *mem=(char*)RexxAllocateMemory(len+1);
  if(!mem){error("RexxAllocateMemory failed");return false;}
  if(len)std::memcpy(mem,ptr,len);
  mem[len]=0;ret->strptr=mem;ret->strlength=len;return true;
}
static bool writeText(PRXSTRING ret,const std::string &value){return writeResult(ret,value.data(),value.size());}
static long token(const CONSTRXSTRING &s){
  if(s.strlength==0||s.strlength>12)return -1;
  std::string t(s.strptr,s.strlength);
  for(char c:t)if(c<'0'||c>'9')return -1;
  return std::strtol(t.c_str(),nullptr,10);
}
static int64_t ptsValue(const CONSTRXSTRING &s){
  if(s.strlength==0||s.strlength>20)return -1;
  std::string t(s.strptr,s.strlength);
  for(char c:t)if((c<'0'||c>'9')&&c!='-')return -1;
  return std::strtoll(t.c_str(),nullptr,10);
}
static void writeBE32(uint8_t *p,uint32_t v){for(int i=3;i>=0;--i){p[i]=uint8_t(v);v>>=8;}}
static void writeBE64(uint8_t *p,uint64_t v){for(int i=7;i>=0;--i){p[i]=uint8_t(v);v>>=8;}}

static bool drain(Session &s){
  while(true){
    int rc=lib.receive(s.ctx,s.frame);
    if(rc==-11||rc==-541478725)break; // EAGAIN or AVERROR_EOF
    if(rc<0){error("decoder receive error "+std::to_string(rc));return false;}
    auto *f=(AVFramePartial*)s.frame;
    if(f->width<16||f->height<16||f->width>4096||f->height>2160){error("decoded frame dimensions invalid");return false;}
    if(s.output.size()>=8){error("decoder queue exceeds 8-frame limit; caller must take each frame");return false;}
    Frame out;out.width=f->width;out.height=f->height;
    if(f->pts<0 || f->pts>8589934591LL){error("decoded frame has missing/wrapped 90kHz presentation ticks");return false;}
    out.rgb.resize(size_t(out.width)*out.height*3);
    // Public AVFrame PTS for libavutil 59 / FFmpeg 7; ABI major checked at load.
    out.pts=f->pts;
    void *sc=lib.scale_context(out.width,out.height,f->format,out.width,out.height,2,2,nullptr,nullptr,nullptr);
    if(!sc){error("sws_getContext unsupported source pixel format "+std::to_string(f->format));return false;}
    uint8_t *dst[8]={out.rgb.data(),nullptr,nullptr,nullptr,nullptr,nullptr,nullptr,nullptr};
    int strides[8]={out.width*3,0,0,0,0,0,0,0};
    int rows=lib.scale(sc,(const uint8_t *const*)f->data,f->linesize,0,out.height,dst,strides);
    lib.scale_free(sc);
    if(rows!=out.height){error("native scale did not return complete RGB24 frame");return false;}
    s.output.push_back(std::move(out));s.received++;
    lib.frame_unref(s.frame);
  }
  return true;
}

extern "C" size_t REXXENTRY MOAH264Open(const char*,size_t argc,PCONSTRXSTRING,const char*,PRXSTRING ret){
  std::lock_guard<std::mutex> lock(gate);
  if(argc!=0){writeText(ret,"ERROR bad argc");return 0;}
  if(!lib.codec&&!lib.init()){writeText(ret,"ERROR "+lib.error);return 0;}
  if(sessions.size()>=16){writeText(ret,"ERROR too many decoders");return 0;}
  const AVCodec *codec=lib.find_decoder(27); // AV_CODEC_ID_H264
  if(!codec){writeText(ret,"ERROR no H264 decoder");return 0;}
  std::unique_ptr<Session> s(new Session());s->ctx=lib.alloc_context(codec);
  if(!s->ctx){writeText(ret,"ERROR decoder allocation");return 0;}
  if(lib.open(s->ctx,codec,nullptr)<0){writeText(ret,"ERROR decoder open");return 0;}
  s->frame=lib.frame_alloc();if(!s->frame){writeText(ret,"ERROR frame alloc");return 0;}
  long id=nextToken++;sessions[id]=std::move(s);
  writeText(ret,std::to_string(id));return 0;
}
extern "C" size_t REXXENTRY MOAH264Feed(const char*,size_t argc,PCONSTRXSTRING arg,const char*,PRXSTRING ret){
  std::lock_guard<std::mutex> lock(gate);
  if(argc!=3){writeText(ret,"ERROR feed expects id, compressed access-unit bytes and PTS");return 0;}
  auto it=sessions.find(token(arg[0]));if(it==sessions.end()){writeText(ret,"ERROR unknown decoder");return 0;}
  auto &s=*it->second;
  size_t n=arg[1].strlength;
  if(n<1||n>4*1024*1024){writeText(ret,"ERROR compressed access unit size outside 1..4MiB");return 0;}
  uint8_t *data=(uint8_t*)lib.mem_allocz(n+64);
  if(!data){writeText(ret,"ERROR native alloc");return 0;}
  std::memcpy(data,arg[1].strptr,n);
  void *pkt=lib.packet_alloc();
  if(!pkt){lib.mem_free(data);writeText(ret,"ERROR packet alloc");return 0;}
  if(lib.packet_from_data(pkt,data,(int)n)<0){lib.mem_free(data);lib.packet_free(&pkt);writeText(ret,"ERROR packet data");return 0;}
  auto *p=(AVPacketPartial*)pkt;p->pts=ptsValue(arg[2]);p->dts=p->pts;
  int rc=lib.send(s.ctx,pkt);lib.packet_free(&pkt);
  if(rc==-11){writeText(ret,"ERROR decode backpressure; take pending frames before feeding");return 0;}
  if(rc<0){writeText(ret,"ERROR decoder send "+std::to_string(rc));return 0;}
  s.sent++;
  if(!drain(s)){writeText(ret,"ERROR "+lastError);return 0;}
  writeText(ret,std::to_string(s.output.size()));return 0;
}
extern "C" size_t REXXENTRY MOAH264Take(const char*,size_t argc,PCONSTRXSTRING arg,const char*,PRXSTRING ret){
  std::lock_guard<std::mutex> lock(gate);
  if(argc!=1){writeText(ret,"ERROR take argc");return 0;}
  auto it=sessions.find(token(arg[0]));if(it==sessions.end()){writeText(ret,"ERROR unknown decoder");return 0;}
  if(it->second->output.empty()){writeText(ret,"");return 0;}
  Frame &f=it->second->output.front();
  size_t len=20+f.rgb.size();std::vector<uint8_t> result(len);
  std::memcpy(result.data(),"MHP1",4);writeBE32(result.data()+4,(uint32_t)f.width);
  writeBE32(result.data()+8,(uint32_t)f.height);writeBE64(result.data()+12,(uint64_t)f.pts);
  std::memcpy(result.data()+20,f.rgb.data(),f.rgb.size());
  bool ok=writeResult(ret,result.data(),len);
  if(ok)it->second->output.pop_front();
  return 0;
}
extern "C" size_t REXXENTRY MOAH264Flush(const char*,size_t argc,PCONSTRXSTRING arg,const char*,PRXSTRING ret){
  std::lock_guard<std::mutex> lock(gate);
  if(argc!=1){writeText(ret,"ERROR flush argc");return 0;}
  auto it=sessions.find(token(arg[0]));if(it==sessions.end()){writeText(ret,"ERROR unknown decoder");return 0;}
  int rc=lib.send(it->second->ctx,nullptr);
  if(rc<0&&rc!=-541478725){writeText(ret,"ERROR flush code "+std::to_string(rc));return 0;}
  if(!drain(*it->second)){writeText(ret,"ERROR "+lastError);return 0;}
  writeText(ret,std::to_string(it->second->output.size()));return 0;
}
extern "C" size_t REXXENTRY MOAH264Close(const char*,size_t argc,PCONSTRXSTRING arg,const char*,PRXSTRING ret){
  std::lock_guard<std::mutex> lock(gate);
  if(argc!=1){writeText(ret,"ERROR close argc");return 0;}
  sessions.erase(token(arg[0]));writeText(ret,"OK");return 0;
}

/* ooRexx native package registration. No RxFuncAdd global mutable registry. */
#include <oorexxapi.h>
static RexxRoutineEntry moa_h264_routines[] = {
  REXX_CLASSIC_ROUTINE(MOAH264Open, MOAH264Open),
  REXX_CLASSIC_ROUTINE(MOAH264Feed, MOAH264Feed),
  REXX_CLASSIC_ROUTINE(MOAH264Take, MOAH264Take),
  REXX_CLASSIC_ROUTINE(MOAH264Flush, MOAH264Flush),
  REXX_CLASSIC_ROUTINE(MOAH264Close, MOAH264Close),
  REXX_LAST_ROUTINE()
};
static RexxPackageEntry moa_h264_package_entry = {
  STANDARD_PACKAGE_HEADER
  REXX_INTERPRETER_5_0_0, "Alchemy Media H264 Codec", "0.1", nullptr, nullptr,
  moa_h264_routines, nullptr
};
OOREXX_GET_PACKAGE(moa_h264);