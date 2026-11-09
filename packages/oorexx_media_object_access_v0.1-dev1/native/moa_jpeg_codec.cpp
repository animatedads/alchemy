/* Media Object Access: in-process JPEG -> RGBA32 provider. No file access.
 * Input: compressed JPEG bytes. Output: MJG1 + width u32be + height u32be
 * + tightly packed row-major 8-bit RGBA pixels (alpha=255, synthetic).
 * Deliberately only a codec provider: ooRexx owns source, transport and I/O.
 */
#include <rexx.h>
#include <oorexxapi.h>
#include <cstdio>
#include <jpeglib.h>
#include <setjmp.h>
#include <cstdint>
#include <cstring>
#include <vector>
#include <string>

namespace {
constexpr size_t MAX_JPEG_INPUT_BYTES=32U*1024U*1024U;
constexpr size_t MAX_OUTPUT=64U*1024U*1024U;
constexpr uint64_t MAX_PIXELS=12000000ULL;
struct CodecError {jpeg_error_mgr standard; jmp_buf target; char message[JMSG_LENGTH_MAX];};
extern "C" void jpegError(j_common_ptr pointer){
  auto* ctx=reinterpret_cast<CodecError*>(pointer->err);
  (*pointer->err->format_message)(pointer,ctx->message);
  longjmp(ctx->target,1);
}
void be32(uint8_t* bytes,uint32_t x){bytes[0]=uint8_t(x>>24);bytes[1]=uint8_t(x>>16);bytes[2]=uint8_t(x>>8);bytes[3]=uint8_t(x);}
bool returnBytes(PRXSTRING out,const void* source,size_t size){
  if(size>MAX_OUTPUT)return false;
  auto* data=static_cast<char*>(RexxAllocateMemory(size+1));
  if(!data)return false;
  if(size)std::memcpy(data,source,size);
  data[size]=0;out->strptr=data;out->strlength=size;
  return true;
}
size_t fail(PRXSTRING out,const std::string& message){
  std::string text="ERROR "+message;
  returnBytes(out,text.data(),text.size());
  return 0;
}
}
extern "C" size_t REXXENTRY MOAJPEGDecode(const char*,size_t argc,PCONSTRXSTRING arg,const char*,PRXSTRING out){
  if(argc!=1 || !arg[0].strptr || arg[0].strlength<4 || arg[0].strlength>MAX_JPEG_INPUT_BYTES)
    return fail(out,"invalid JPEG byte budget");
  const auto* data=reinterpret_cast<const unsigned char*>(arg[0].strptr);
  if(data[0]!=0xFF || data[1]!=0xD8 || data[2]!=0xFF)
    return fail(out,"invalid JPEG SOI");
  jpeg_decompress_struct info{};
  CodecError error{};
  info.err=jpeg_std_error(&error.standard);
  error.standard.error_exit=jpegError;
  std::vector<uint8_t> pixels;
  std::vector<uint8_t> scan;
  bool created=false;
  if(setjmp(error.target)){
    if(created) jpeg_destroy_decompress(&info);
    return fail(out,std::string("JPEG codec error ")+error.message);
  }
  jpeg_create_decompress(&info);
  created=true;
  jpeg_mem_src(&info,data,arg[0].strlength);
  if(jpeg_read_header(&info,TRUE)!=JPEG_HEADER_OK){
    jpeg_destroy_decompress(&info);return fail(out,"JPEG header missing");
  }
  if(info.image_width==0 || info.image_height==0 || info.image_width>8192 || info.image_height>8192 ||
     uint64_t(info.image_width)*info.image_height>MAX_PIXELS){
    jpeg_destroy_decompress(&info);return fail(out,"JPEG image dimensions out of bounds");
  }
  info.out_color_space=JCS_RGB;
  if(!jpeg_start_decompress(&info)){
    jpeg_destroy_decompress(&info);return fail(out,"JPEG start decompress failed");
  }
  const auto width=info.output_width,height=info.output_height;
  if(info.output_components!=3 || uint64_t(width)*height*4+12>MAX_OUTPUT){
    jpeg_destroy_decompress(&info);return fail(out,"JPEG decoded channel/output limit");
  }
  pixels.resize(size_t(width)*height*4+12);
  scan.resize(size_t(width)*3);
  std::memcpy(pixels.data(),"MJG1",4);
  be32(pixels.data()+4,width);be32(pixels.data()+8,height);
  while(info.output_scanline<height){
    JSAMPROW row=scan.data();
    const auto y=info.output_scanline;
    if(jpeg_read_scanlines(&info,&row,1)!=1){
      jpeg_destroy_decompress(&info);return fail(out,"JPEG truncated scanline");
    }
    auto* target=pixels.data()+12+size_t(y)*width*4;
    for(uint32_t x=0;x<width;x++){
      target[x*4+0]=scan[x*3+0];
      target[x*4+1]=scan[x*3+1];
      target[x*4+2]=scan[x*3+2];
      target[x*4+3]=255;
    }
  }
  if(!jpeg_finish_decompress(&info)){
    jpeg_destroy_decompress(&info);return fail(out,"JPEG finish failed");
  }
  jpeg_destroy_decompress(&info);
  if(!returnBytes(out,pixels.data(),pixels.size()))return fail(out,"JPEG result allocation failed");
  return 0;
}
static RexxRoutineEntry routines[]={
  REXX_CLASSIC_ROUTINE(MOAJPEGDecode,MOAJPEGDecode),REXX_LAST_ROUTINE()
};
static RexxPackageEntry moa_jpeg_package_entry={
  STANDARD_PACKAGE_HEADER
  REXX_INTERPRETER_5_0_0,"Alchemy Media JPEG Decoder","0.1",nullptr,nullptr,
  routines,nullptr
};
OOREXX_GET_PACKAGE(moa_jpeg);