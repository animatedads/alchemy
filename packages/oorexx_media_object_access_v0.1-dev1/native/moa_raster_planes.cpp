/* ooRexx Media Object Access: codec-independent RGB24/RGBA32 planes.
 * Native byte loops only; ooRexx owns format semantics and file output.
 * No dependency on PNG, H264, libavformat or filesystem IO.
 */
#include <rexx.h>
#include <oorexxapi.h>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
namespace {
constexpr size_t MAX_RESULT=64U*1024U*1024U;
constexpr uint64_t MAX_PIXELS=12000000ULL;
static bool reply(PRXSTRING ret,const void*mem,size_t len){
  if(len>MAX_RESULT)return false;
  char* out=(char*)RexxAllocateMemory(len+1);if(!out)return false;
  if(len)std::memcpy(out,mem,len);
  out[len]=0;
  ret->strptr=out;ret->strlength=len;return true;
}
static size_t fail(PRXSTRING ret,const std::string&e){
  std::string m="ERROR "+e;reply(ret,m.data(),m.size());return 0;
}
static bool number(const CONSTRXSTRING&s,uint64_t&v){
  if(!s.strptr||s.strlength==0||s.strlength>12)return false;
  v=0;for(size_t i=0;i<s.strlength;i++){
    char c=s.strptr[i];if(c<'0'||c>'9')return false;
    v=v*10+uint64_t(c-'0');if(v>1000000000ULL)return false;
  }
  return true;
}
static bool raster(PCONSTRXSTRING a,size_t n,uint64_t&w,uint64_t&h,uint64_t&d){
  if(n<4||!number(a[1],w)||!number(a[2],h)||!number(a[3],d))return false;
  return w>0&&h>0&&w<=8192&&h<=8192&&w*h<=MAX_PIXELS&&(d==3||d==4)&&
         a[0].strlength==w*h*d;
}
}
extern "C" size_t REXXENTRY MOARasterPlane(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING ret){
  uint64_t w,h,d;if(n!=5||!raster(a,n,w,h,d)||a[4].strlength!=1)return fail(ret,"invalid channel arguments");
  int channel=-1;char ch=a[4].strptr[0];
  switch(ch){case 'R':case 'r':channel=0;break;case 'G':case 'g':channel=1;break;
             case 'B':case 'b':channel=2;break;case 'A':case 'a':channel=3;break;}
  if(channel<0)return fail(ret,"channel must be R G B A");
  const uint8_t*src=(const uint8_t*)a[0].strptr;
  std::vector<uint8_t> dst(size_t(w*h));
  if(d==3&&channel==3)std::memset(dst.data(),255,dst.size());
  else for(size_t p=0;p<dst.size();p++)dst[p]=src[p*d+size_t(channel)];
  if(!reply(ret,dst.data(),dst.size()))return fail(ret,"channel allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterRGB(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING ret){
  uint64_t w,h,d;if(n!=4||!raster(a,n,w,h,d))return fail(ret,"invalid RGB dimensions");
  if(d==3){if(!reply(ret,a[0].strptr,a[0].strlength))return fail(ret,"RGB allocation");return 0;}
  const uint8_t*src=(const uint8_t*)a[0].strptr;
  std::vector<uint8_t> dst(size_t(w*h*3));
  for(size_t p=0;p<size_t(w*h);p++){
    dst[p*3]=src[p*4];dst[p*3+1]=src[p*4+1];dst[p*3+2]=src[p*4+2];
  }
  if(!reply(ret,dst.data(),dst.size()))return fail(ret,"RGB allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterRGBA(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING ret){
  uint64_t w,h,d;if(n!=4||!raster(a,n,w,h,d))return fail(ret,"invalid RGBA dimensions");
  if(d==4){if(!reply(ret,a[0].strptr,a[0].strlength))return fail(ret,"RGBA allocation");return 0;}
  const uint8_t*src=(const uint8_t*)a[0].strptr;
  std::vector<uint8_t> dst(size_t(w*h*4));
  for(size_t p=0;p<size_t(w*h);p++){
    dst[p*4]=src[p*3];dst[p*4+1]=src[p*3+1];dst[p*4+2]=src[p*3+2];dst[p*4+3]=255;
  }
  if(!reply(ret,dst.data(),dst.size()))return fail(ret,"RGBA allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterLuma(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING ret){
  uint64_t w,h,d;if(n!=4||!raster(a,n,w,h,d))return fail(ret,"invalid luma dimensions");
  const uint8_t*src=(const uint8_t*)a[0].strptr;
  std::vector<uint8_t> dst(size_t(w*h));
  for(size_t p=0;p<dst.size();p++){
    const uint8_t *rgb=src+p*d;
    dst[p]=uint8_t((54U*rgb[0]+183U*rgb[1]+19U*rgb[2]+128U)>>8);
  }
  if(!reply(ret,dst.data(),dst.size()))return fail(ret,"luma allocation");
  return 0;
}
static RexxRoutineEntry moa_raster_routines[]={
  REXX_CLASSIC_ROUTINE(MOARasterPlane,MOARasterPlane),
  REXX_CLASSIC_ROUTINE(MOARasterRGB,MOARasterRGB),
  REXX_CLASSIC_ROUTINE(MOARasterRGBA,MOARasterRGBA),
  REXX_CLASSIC_ROUTINE(MOARasterLuma,MOARasterLuma),
  REXX_LAST_ROUTINE()
};
static RexxPackageEntry moa_raster_package_entry={
  STANDARD_PACKAGE_HEADER
  REXX_INTERPRETER_5_0_0,"Alchemy Shared RGB/RGBA Pixel Planes","0.1",nullptr,nullptr,
  moa_raster_routines,nullptr
};
OOREXX_GET_PACKAGE(moa_raster);