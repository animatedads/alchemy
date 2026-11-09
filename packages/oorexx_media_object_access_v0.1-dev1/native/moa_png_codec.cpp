/* ooRexx Media Object Access native PNG-only decoder.
 * Input compressed PNG bytes, return MPN1-width-height-RGBA8. No file IO.
 */
#include <rexx.h>
#include <oorexxapi.h>
#include <png.h>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>
namespace {
constexpr size_t MAX_PNG_BYTES=32U*1024U*1024U;
constexpr size_t MAX_RESULT=64U*1024U*1024U;
constexpr uint64_t MAX_PIXELS=12000000ULL;
static void be32(uint8_t*p,uint32_t n){p[0]=uint8_t(n>>24);p[1]=uint8_t(n>>16);p[2]=uint8_t(n>>8);p[3]=uint8_t(n);}
static bool reply(PRXSTRING ret,const void*data,size_t n){
  if(n>MAX_RESULT)return false;
  char *out=(char*)RexxAllocateMemory(n+1);if(!out)return false;
  if(n)std::memcpy(out,data,n);
  out[n]=0;ret->strptr=out;ret->strlength=n;return true;
}
static size_t fail(PRXSTRING ret,const std::string&str){
  const std::string message="ERROR "+str;reply(ret,message.data(),message.size());return 0;
}
}
extern "C" size_t REXXENTRY MOAPNGDecode(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING ret){
  if(n!=1||!a[0].strptr||a[0].strlength<33||a[0].strlength>MAX_PNG_BYTES)
    return fail(ret,"invalid PNG compressed byte budget");
  const uint8_t *input=(const uint8_t*)a[0].strptr;
  if(png_sig_cmp(input,0,8))return fail(ret,"not a PNG signature");
  png_image im{};im.version=PNG_IMAGE_VERSION;
  if(!png_image_begin_read_from_memory(&im,input,a[0].strlength)){
    std::string why=im.message;png_image_free(&im);return fail(ret,"PNG metadata "+why);
  }
  if(im.width==0||im.height==0||im.width>8192||im.height>8192||
     uint64_t(im.width)*im.height>MAX_PIXELS){
    png_image_free(&im);return fail(ret,"PNG dimension limit exceeded");
  }
  im.format=PNG_FORMAT_RGBA;
  size_t imageBytes=size_t(im.width)*im.height*4;
  if(imageBytes+12>MAX_RESULT){png_image_free(&im);return fail(ret,"PNG decoded byte limit exceeded");}
  std::vector<uint8_t> out(imageBytes+12);
  std::memcpy(out.data(),"MPN1",4);be32(out.data()+4,im.width);be32(out.data()+8,im.height);
  if(!png_image_finish_read(&im,nullptr,out.data()+12,0,nullptr)){
    std::string why=im.message;png_image_free(&im);return fail(ret,"PNG pixel decode "+why);
  }
  png_image_free(&im);
  if(!reply(ret,out.data(),out.size()))return fail(ret,"PNG Rexx output allocation");
  return 0;
}
static RexxRoutineEntry moa_png_routines[]={
  REXX_CLASSIC_ROUTINE(MOAPNGDecode,MOAPNGDecode),REXX_LAST_ROUTINE()
};
static RexxPackageEntry moa_png_package_entry={
  STANDARD_PACKAGE_HEADER
  REXX_INTERPRETER_5_0_0,"Alchemy Media PNG Decoder","0.1",nullptr,nullptr,
  moa_png_routines,nullptr
};
OOREXX_GET_PACKAGE(moa_png);