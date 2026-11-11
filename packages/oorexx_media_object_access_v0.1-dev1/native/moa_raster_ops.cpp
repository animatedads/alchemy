/* Alchemy Media Object Access: bounded, codec-independent raster transforms.
 * ooRexx owns image, layer, temporal and source semantics; this library
 * only transforms caller-provided byte buffers, no IO, decoder, or Python.
 * Signed subtraction uses interleaved signed-16 BIG-ENDIAN samples.
 */
#include <rexx.h>
#include <oorexxapi.h>
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>
#include <string>
#include <vector>
namespace {
constexpr uint64_t MAX_PIXEL_COUNT=12000000ULL;
constexpr size_t MAX_OUTPUT=96ULL*1024*1024;
bool emit(PRXSTRING r,const void *v,size_t count) {
  if(count>MAX_OUTPUT)return false;
  char* result=static_cast<char*>(RexxAllocateMemory(count+1));
  if(!result)return false;
  if(count)std::memcpy(result,v,count);
  result[count]=0;r->strptr=result;r->strlength=count;return true;
}
size_t fail(PRXSTRING r,const std::string&cause){
  const auto text="ERROR "+cause;
  emit(r,text.data(),text.size());
  return 0;
}
bool number(const CONSTRXSTRING&a,int64_t&n,bool allowNegative=false){
  if(!a.strptr||a.strlength<1||a.strlength>14)return false;
  size_t i=0;bool negative=false;
  if(a.strptr[0]=='-'&&allowNegative){i=1;negative=true;}
  if(i==a.strlength)return false;
  int64_t val=0;
  for(;i<a.strlength;i++){
    const char c=a.strptr[i];if(c<'0'||c>'9')return false;
    val=val*10+c-'0';if(val>1000000000LL)return false;
  }
  n=negative?-val:val;return true;
}
bool raster(PCONSTRXSTRING a,size_t start,uint64_t& w,uint64_t&h,uint64_t&d,bool layer=false){
  int64_t x,y,z;
  if(!number(a[start+1],x)||!number(a[start+2],y)||!number(a[start+3],z))return false;
  if(x<1||y<1||x>8192||y>8192||uint64_t(x)*uint64_t(y)>MAX_PIXEL_COUNT)return false;
  if(z!=3&&z!=4&&!(layer&&z==1))return false;
  w=uint64_t(x);h=uint64_t(y);d=uint64_t(z);
  return a[start].strptr&&a[start].strlength==w*h*d;
}
void signed16(std::vector<uint8_t>&to,size_t off,int difference){
  const uint16_t u=static_cast<uint16_t>(static_cast<int16_t>(difference));
  to[off]=uint8_t(u>>8);to[off+1]=uint8_t(u);
}
int bandValue(const uint8_t*px,size_t depth,char band){
  switch(band){
  case 'R':return px[0];case 'G':return px[1];case 'B':return px[2];
  case 'A':return depth==4?px[3]:255;
  case 'Y':return (54*px[0]+183*px[1]+19*px[2]+128)>>8;
  default:return -1;
  }
}
int value(const uint8_t*px,uint64_t depth,size_t channel){
  return channel==3&&depth==3?255:px[channel];
}
std::vector<uint8_t> difference(uint64_t w,uint64_t h,uint64_t count){
  return std::vector<uint8_t>(size_t(w*h*count*2),0);
}
char upper(const CONSTRXSTRING&x){
  if(x.strlength!=1)return 0;
  char c=x.strptr[0];if(c>='a'&&c<='z')c-=32;return c;
}
}
extern "C" size_t REXXENTRY MOARasterOpCrop(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  uint64_t w,h,d;if(n!=8||!raster(a,0,w,h,d))return fail(r,"invalid crop source");
  int64_t x,y,cw,ch;
  if(!number(a[4],x)||!number(a[5],y)||!number(a[6],cw)||!number(a[7],ch)||
     cw<1||ch<1||x+cw>int64_t(w)||y+ch>int64_t(h)||uint64_t(cw)*uint64_t(ch)>MAX_PIXEL_COUNT)
    return fail(r,"crop rectangle outside source");
  std::vector<uint8_t> out(size_t(cw*ch*d));
  const auto*src=reinterpret_cast<const uint8_t*>(a[0].strptr);
  for(int64_t row=0;row<ch;row++){
    const size_t at=size_t(((y+row)*int64_t(w)+x)*int64_t(d));
    std::memcpy(out.data()+size_t(row*cw*d),src+at,size_t(cw*d));
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"crop output allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpResize(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  uint64_t w,h,d;if(n!=7||!raster(a,0,w,h,d))return fail(r,"invalid resize source");
  int64_t nw,nh;
  if(!number(a[4],nw)||!number(a[5],nh)||nw<1||nh<1||nw>8192||nh>8192||
     uint64_t(nw)*uint64_t(nh)>MAX_PIXEL_COUNT||uint64_t(nw)*uint64_t(nh)*d>MAX_OUTPUT)
    return fail(r,"invalid resize output dimensions");
  const std::string method(a[6].strptr?a[6].strptr:"",a[6].strlength);
  if(method!="NEAREST"&&method!="BILINEAR"&&method!="AREA")return fail(r,"resize method must be NEAREST BILINEAR AREA");
  if(method=="AREA"&&(nw>int64_t(w)||nh>int64_t(h)))return fail(r,"AREA is downsample only");
  const uint8_t*in=reinterpret_cast<const uint8_t*>(a[0].strptr);
  std::vector<uint8_t> out(size_t(nw*nh*int64_t(d)));
  auto compose=[&](int64_t x,int64_t y,size_t channel)->double{
    return in[(size_t(y)*size_t(w)+size_t(x))*size_t(d)+channel];
  };
  for(int64_t ty=0;ty<nh;ty++)for(int64_t tx=0;tx<nw;tx++){
    double accum[4]={},total=0;
    if(method=="NEAREST"){
      int64_t sx=std::min<int64_t>(w-1,(tx*int64_t(w))/nw),sy=std::min<int64_t>(h-1,(ty*int64_t(h))/nh);
      for(size_t c=0;c<d;c++)accum[c]=compose(sx,sy,c);
      total=1;
    } else if(method=="BILINEAR"){
      const double fx=(double(tx)+.5)*double(w)/double(nw)-.5;
      const double fy=(double(ty)+.5)*double(h)/double(nh)-.5;
      const int64_t x0=std::max<int64_t>(0,std::min<int64_t>(w-1,int64_t(std::floor(fx))));
      const int64_t x1=std::max<int64_t>(0,std::min<int64_t>(w-1,int64_t(std::floor(fx))+1));
      const int64_t y0=std::max<int64_t>(0,std::min<int64_t>(h-1,int64_t(std::floor(fy))));
      const int64_t y1=std::max<int64_t>(0,std::min<int64_t>(h-1,int64_t(std::floor(fy))+1));
      const double ax=std::clamp(fx-std::floor(fx),0.,1.),ay=std::clamp(fy-std::floor(fy),0.,1.);
      for(size_t c=0;c<d;c++)
        accum[c]=(1-ax)*(1-ay)*compose(x0,y0,c)+ax*(1-ay)*compose(x1,y0,c)+
                 (1-ax)*ay*compose(x0,y1,c)+ax*ay*compose(x1,y1,c);
      total=1;
    } else { // exact coverage area average, not pixel-dropping decimation
      const double xlo=double(tx)*double(w)/double(nw), xhi=double(tx+1)*double(w)/double(nw);
      const double ylo=double(ty)*double(h)/double(nh), yhi=double(ty+1)*double(h)/double(nh);
      for(int64_t sy=int64_t(ylo);sy<int64_t(std::ceil(yhi));sy++){
        const double wy=std::max(0.,std::min(yhi,double(sy+1))-std::max(ylo,double(sy)));
        if(!wy)continue;
        for(int64_t sx=int64_t(xlo);sx<int64_t(std::ceil(xhi));sx++){
          const double wx=std::max(0.,std::min(xhi,double(sx+1))-std::max(xlo,double(sx)));
          const double weight=wy*wx;
          if(!weight)continue;
          for(size_t c=0;c<d;c++)accum[c]+=weight*compose(sx,sy,c);
          total+=weight;
        }
      }
    }
    if(total==0)return fail(r,"resize zero-weight coverage");
    auto *dst=out.data()+(size_t(ty)*size_t(nw)+size_t(tx))*size_t(d);
    // Scientific resampling: channels are independent, including straight alpha.
    // This is NOT an alpha-compositing operation.
    for(size_t c=0;c<d;c++)dst[c]=uint8_t(std::clamp(std::llround(accum[c]/total),0LL,255LL));
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"resize output allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpSubtractFrame(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  uint64_t w,h,d,rw,rh,rd;
  if(n!=9||!raster(a,0,w,h,d)||!raster(a,4,rw,rh,rd)||w!=rw||h!=rh)
    return fail(r,"frame subtraction requires exactly matching dimensions");
  int64_t withAlpha;if(!number(a[8],withAlpha)||withAlpha>1)return fail(r,"invalid alpha policy");
  if(withAlpha&&(d!=4||rd!=4))return fail(r,"alpha difference requires two RGBA sources");
  const size_t nch=withAlpha?4:3;
  const auto*s=reinterpret_cast<const uint8_t*>(a[0].strptr),*b=reinterpret_cast<const uint8_t*>(a[4].strptr);
  auto out=difference(w,h,nch);
  for(size_t p=0;p<size_t(w*h);p++)for(size_t c=0;c<nch;c++)
    signed16(out,(p*nch+c)*2,value(s+p*d,d,c)-value(b+p*rd,rd,c));
  if(!emit(r,out.data(),out.size()))return fail(r,"frame difference output budget");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpSubtractLayer(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  uint64_t w,h,d,lw,lh,ld;
  if(n!=12||!raster(a,0,w,h,d)||!raster(a,4,lw,lh,ld,true))
    return fail(r,"invalid image or subtract layer");
  int64_t ox,oy,withAlpha;
  if(!number(a[8],ox,true)||!number(a[9],oy,true)||!number(a[11],withAlpha)||withAlpha>1)
    return fail(r,"invalid layer origin/alpha policy");
  const char band=upper(a[10]);
  if(ld==1&&band!='R'&&band!='G'&&band!='B'&&band!='A'&&band!='Y')
    return fail(r,"single-channel layer must select R/G/B/A/Y target");
  if(ld==1&&withAlpha)return fail(r,"single-channel layer does not support includeAlpha");
  if(ld!=1&&withAlpha&&(ld!=4||d!=4))return fail(r,"alpha difference requires RGBA layer and source");
  if(ld!=1&&band!='X')return fail(r,"multichannel layer band marker must be X");
  const size_t channels=ld==1?1:(withAlpha?4:3);
  auto out=difference(w,h,channels);
  const auto*image=reinterpret_cast<const uint8_t*>(a[0].strptr);
  const auto*layer=reinterpret_cast<const uint8_t*>(a[4].strptr);
  for(uint64_t ly=0;ly<lh;ly++){
    const int64_t dy=int64_t(ly)+oy;if(dy<0||dy>=int64_t(h))continue;
    for(uint64_t lx=0;lx<lw;lx++){
      const int64_t dx=int64_t(lx)+ox;if(dx<0||dx>=int64_t(w))continue;
      const size_t dest=size_t(dy)*size_t(w)+size_t(dx), lp=size_t(ly*lw+lx);
      const auto *base=image+dest*d,*source=layer+lp*ld;
      if(ld==1){
        signed16(out,dest*2,bandValue(base,d,band)-source[0]);
      } else for(size_t c=0;c<channels;c++)
        signed16(out,(dest*channels+c)*2,value(base,d,c)-value(source,ld,c));
    }
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"layer difference output budget");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpMagnitude(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  int64_t w,h,d;
  if(n!=4||!number(a[1],w)||!number(a[2],h)||!number(a[3],d)||
     w<1||h<1||w>8192||h>8192||w*h>int64_t(MAX_PIXEL_COUNT)||d<1||d>4||
     !a[0].strptr||a[0].strlength!=size_t(w*h*d*2))
    return fail(r,"invalid signed raster magnitude dimensions");
  const auto*s=reinterpret_cast<const uint8_t*>(a[0].strptr);
  std::vector<uint8_t>out(size_t(w*h));
  for(size_t p=0;p<out.size();p++){
    int highest=0;
    for(int c=0;c<d;c++){
      auto at=(p*size_t(d)+size_t(c))*2;
      const uint16_t bits=uint16_t(s[at])<<8|s[at+1];
      const int v=static_cast<int16_t>(bits);
      highest=std::max(highest,std::abs(v));
    }
    out[p]=uint8_t(std::min(highest,255));
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"magnitude output budget");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpEstimateTranslation(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpValidity(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpNormalizeLuma(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpBuildTemporal(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpScoreTemporal(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpTranslate(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpEstimateSimilarity(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpScoreSimilarity(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpWarpSimilarity(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
extern "C" size_t REXXENTRY MOARasterOpValiditySimilarity(const char*,size_t,PCONSTRXSTRING,const char*,PRXSTRING);
static RexxRoutineEntry routines[]={
  REXX_CLASSIC_ROUTINE(MOARasterOpCrop,MOARasterOpCrop),
  REXX_CLASSIC_ROUTINE(MOARasterOpResize,MOARasterOpResize),
  REXX_CLASSIC_ROUTINE(MOARasterOpSubtractFrame,MOARasterOpSubtractFrame),
  REXX_CLASSIC_ROUTINE(MOARasterOpSubtractLayer,MOARasterOpSubtractLayer),
  REXX_CLASSIC_ROUTINE(MOARasterOpMagnitude,MOARasterOpMagnitude),
  REXX_CLASSIC_ROUTINE(MOARasterOpEstimateTranslation,MOARasterOpEstimateTranslation),
  REXX_CLASSIC_ROUTINE(MOARasterOpValidity,MOARasterOpValidity),
  REXX_CLASSIC_ROUTINE(MOARasterOpNormalizeLuma,MOARasterOpNormalizeLuma),
  REXX_CLASSIC_ROUTINE(MOARasterOpBuildTemporal,MOARasterOpBuildTemporal),
  REXX_CLASSIC_ROUTINE(MOARasterOpScoreTemporal,MOARasterOpScoreTemporal),
  REXX_CLASSIC_ROUTINE(MOARasterOpTranslate,MOARasterOpTranslate),
  REXX_CLASSIC_ROUTINE(MOARasterOpEstimateSimilarity,MOARasterOpEstimateSimilarity),
  REXX_CLASSIC_ROUTINE(MOARasterOpScoreSimilarity,MOARasterOpScoreSimilarity),
  REXX_CLASSIC_ROUTINE(MOARasterOpWarpSimilarity,MOARasterOpWarpSimilarity),
  REXX_CLASSIC_ROUTINE(MOARasterOpValiditySimilarity,MOARasterOpValiditySimilarity),
  REXX_LAST_ROUTINE()
};
static RexxPackageEntry moa_raster_ops_package_entry={
  STANDARD_PACKAGE_HEADER
  REXX_INTERPRETER_5_0_0,"Alchemy Media Raster Geometry and Delta","0.1",nullptr,nullptr,
  routines,nullptr
};
OOREXX_GET_PACKAGE(moa_raster_ops);

/* Photometric alignment uses robust median of valid mid-tone pixels.
 * Invariant: gain maps the new frame back to the first frame's luminance,
 * not the other way round. Candidate star pixels have negligible weight. */
extern "C" size_t REXXENTRY MOARasterOpNormalizeLuma(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  int64_t w,h;
  if(n!=4||!number(a[2],w)||!number(a[3],h)||w<1||h<1||
     uint64_t(w)*uint64_t(h)>MAX_PIXEL_COUNT||!a[0].strptr||!a[1].strptr||
     a[0].strlength!=size_t(w*h)||a[1].strlength!=size_t(w*h))return fail(r,"invalid photometric source/reference");
  const auto*current=reinterpret_cast<const uint8_t*>(a[0].strptr);
  const auto*reference=reinterpret_cast<const uint8_t*>(a[1].strptr);
  const size_t count=size_t(w*h), stride=std::max<size_t>(1,count/16384);
  std::vector<double> ratios;ratios.reserve(count/stride+1);
  for(size_t i=0;i<count;i+=stride){
    if(reference[i]>=20&&reference[i]<=235&&current[i]>=12&&current[i]<=250)
      ratios.push_back(double(reference[i])/double(current[i]));
  }
  if(ratios.size()<4)return fail(r,"too few stable illuminated samples to estimate global gain");
  const size_t mid=ratios.size()/2;
  std::nth_element(ratios.begin(),ratios.begin()+mid,ratios.end());
  double gain=ratios[mid];
  if(gain<0.5||gain>2.0||!std::isfinite(gain))return fail(r,"photometric gain outside safe range");
  const uint32_t scaled=uint32_t(std::llround(gain*1000000));
  std::vector<uint8_t>result(count+8);
  result[0]='M';result[1]='N';result[2]='L';result[3]='1';
  result[4]=uint8_t(scaled>>24);result[5]=uint8_t(scaled>>16);
  result[6]=uint8_t(scaled>>8);result[7]=uint8_t(scaled);
  for(size_t i=0;i<count;i++)result[i+8]=uint8_t(std::clamp(std::llround(current[i]*gain),0LL,255LL));
  if(!emit(r,result.data(),result.size()))return fail(r,"photometric result allocation");
  return 0;
}
/* Model is reconstructed from ALL registered, photometrically-aligned frames.
 * Lower median prevents a star that traverses a pixel in one frame from
 * polluting the static background. Robust absolute deviation is learned
 * separately and cannot absorb a one-frame bright outlier.
 * Output MTM1 || background || temporal-noise || local-threshold; plane length P.
 */
extern "C" size_t REXXENTRY MOARasterOpBuildTemporal(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  int64_t w,h,frames,pct,minDiff,referenceFloor,noiseFactor;
  if(n!=9||!number(a[2],w)||!number(a[3],h)||!number(a[4],frames)||
      !number(a[5],pct)||!number(a[6],minDiff)||!number(a[7],referenceFloor)||
      !number(a[8],noiseFactor)||w<1||h<1||frames<2||frames>16||
      w*h>2000000||pct<1||pct>100||minDiff<1||minDiff>255||
      referenceFloor<1||referenceFloor>255||noiseFactor>12||
      !a[0].strptr||!a[1].strptr||a[0].strlength!=size_t(w*h*frames)||
      a[1].strlength!=size_t(w*h*frames))
    return fail(r,"invalid temporal mask dimensions or thresholds");
  const size_t pixels=size_t(w*h),N=size_t(frames);
  const uint8_t*src=reinterpret_cast<const uint8_t*>(a[0].strptr);
  const uint8_t*valid=reinterpret_cast<const uint8_t*>(a[1].strptr);
  std::vector<uint8_t>out(4+3*pixels);out[0]='M';out[1]='T';out[2]='M';out[3]='1';
  for(size_t p=0;p<pixels;p++){
    uint8_t samples[16];size_t observed=0;
    for(size_t i=0;i<N;i++)if(valid[i*pixels+p])samples[observed++]=src[i*pixels+p];
    if(observed<2){out[4+p]=0;out[4+pixels+p]=0;out[4+2*pixels+p]=255;continue;}
    std::sort(samples,samples+observed);
    const int base=samples[(observed-1)/2];
    uint8_t dev[16];for(size_t i=0;i<observed;i++)dev[i]=uint8_t(std::abs(int(samples[i])-base));
    std::sort(dev,dev+observed);
    const int noise=dev[(observed-1)/2];
    const int tolerance=std::clamp(std::max({int(minDiff),
       int(std::ceil(double(pct)*double(std::max(base,int(referenceFloor)))/100.)),
       int(noiseFactor)*noise}),1,255);
    out[4+p]=uint8_t(base);out[4+pixels+p]=uint8_t(noise);
    out[4+2*pixels+p]=uint8_t(tolerance);
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"temporal model output allocation");
  return 0;
}
/* Output MTS1 || abs(delta) || accepted mask || positive mask || negative mask.
 * Each plane is 8-bit P pixels; no sign is thrown away until requested.
 */
extern "C" size_t REXXENTRY MOARasterOpScoreTemporal(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  int64_t w,h;
  if(n!=6||!number(a[4],w)||!number(a[5],h)||w<1||h<1||w*h>2000000||
     !a[0].strptr||!a[1].strptr||!a[2].strptr||!a[3].strptr||
     a[0].strlength!=size_t(w*h)||a[1].strlength!=size_t(w*h)||
     a[2].strlength!=size_t(w*h)||a[3].strlength!=size_t(w*h))return fail(r,"invalid scored temporal frame");
  size_t pixels=size_t(w*h);
  const auto*src=reinterpret_cast<const uint8_t*>(a[0].strptr);
  const auto*valid=reinterpret_cast<const uint8_t*>(a[1].strptr);
  const auto*bg=reinterpret_cast<const uint8_t*>(a[2].strptr);
  const auto*th=reinterpret_cast<const uint8_t*>(a[3].strptr);
  std::vector<uint8_t>out(4+4*pixels);out[0]='M';out[1]='T';out[2]='S';out[3]='1';
  for(size_t p=0;p<pixels;p++){
    int delta=int(src[p])-int(bg[p]),absolute=std::abs(delta);
    bool detected=valid[p]&&absolute>int(th[p]);
    out[4+p]=valid[p]?uint8_t(absolute):0;
    out[4+pixels+p]=detected?255:0;
    out[4+2*pixels+p]=(detected&&delta>0)?255:0;
    out[4+3*pixels+p]=(detected&&delta<0)?255:0;
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"score output allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpTranslate(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  uint64_t w,h,d;if(n!=6||!raster(a,0,w,h,d))return fail(r,"bad translation image");
  int64_t dx,dy;if(!number(a[4],dx,true)||!number(a[5],dy,true)||
     std::abs(dx)>=int64_t(w)||std::abs(dy)>=int64_t(h))return fail(r,"bad translation shift");
  const auto*src=reinterpret_cast<const uint8_t*>(a[0].strptr);
  std::vector<uint8_t>out(size_t(w*h*d),0);
  for(int64_t y=0;y<int64_t(h);y++){
    int64_t sy=y-dy;if(sy<0||sy>=int64_t(h))continue;
    for(int64_t x=0;x<int64_t(w);x++){
      int64_t sx=x-dx;if(sx<0||sx>=int64_t(w))continue;
      std::memcpy(out.data()+size_t((y*int64_t(w)+x)*int64_t(d)),
          src+size_t((sy*int64_t(w)+sx)*int64_t(d)),size_t(d));
    }
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"translate output allocation");
  return 0;
}

/* Estimate integer translation from caller-selected stable-landmark ROI.
 * Uses signed, normalised local gradients to reduce sensitivity to global
 * photometric gain. This is NOT a parallax/affine camera-motion solution.
 * The returned shift is the transform to APPLY TO target to align reference.
 */
extern "C" size_t REXXENTRY MOARasterOpEstimateTranslation(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  uint64_t w,h,d,tw,th,td;
  if(n!=13||!raster(a,0,w,h,d)||!raster(a,4,tw,th,td)||w!=tw||h!=th)
    return fail(r,"registration sources must have matching dimensions");
  int64_t left,top,rw,rh,range;
  if(!number(a[8],left)||!number(a[9],top)||!number(a[10],rw)||
     !number(a[11],rh)||!number(a[12],range)||range>16||
     left<0||top<0||rw<1||rh<1||left+rw>int64_t(w)||top+rh>int64_t(h))
    return fail(r,"registration ROI invalid");
  const auto *ref=reinterpret_cast<const uint8_t*>(a[0].strptr);
  const auto *target=reinterpret_cast<const uint8_t*>(a[4].strptr);
  auto L=[&](const uint8_t*data,int64_t x,int64_t y,size_t depth)->double{
    const auto*px=data+(size_t(y)*w+size_t(x))*depth;
    return double((54*int(px[0])+183*int(px[1])+19*int(px[2])+128)>>8);
  };
  const int64_t xlo=std::max<int64_t>(left+range+2,range+2);
  const int64_t xhi=std::min<int64_t>(left+rw-range-2,int64_t(w)-range-2);
  const int64_t ylo=std::max<int64_t>(top+range+2,range+2);
  const int64_t yhi=std::min<int64_t>(top+rh-range-2,int64_t(h)-range-2);
  if(xhi<=xlo||yhi<=ylo)return fail(r,"landmark ROI too small for proposed shift");
  auto edge=[&](const uint8_t*data,int64_t x,int64_t y,size_t depth)->std::pair<double,double>{
    const double l=L(data,x-1,y,depth),rr=L(data,x+1,y,depth);
    const double up=L(data,x,y-1,depth),down=L(data,x,y+1,depth);
    return {(rr-l)/(rr+l+32.),(down-up)/(down+up+32.)};
  };
  double best=std::numeric_limits<double>::infinity(),second=best;
  int64_t bestX=0,bestY=0,bestSamples=0;
  for(int64_t dy=-range;dy<=range;dy++)for(int64_t dx=-range;dx<=range;dx++){
    double total=0;int64_t used=0;
    for(int64_t y=ylo;y<yhi;y+=3)for(int64_t x=xlo;x<xhi;x+=3){
      const auto a0=edge(ref,x,y,d),a1=edge(target,x-dx,y-dy,td);
      const double strength=std::abs(a0.first)+std::abs(a0.second);
      if(strength<0.032)continue;
      total+=std::abs(a0.first-a1.first)+std::abs(a0.second-a1.second);
      used++;
    }
    if(used<12)continue;
    const double score=total/double(used);
    if(score<best){second=best;best=score;bestX=dx;bestY=dy;bestSamples=used;}
    else if(score<second)second=score;
  }
  if(!std::isfinite(best)||best>0.22||second-best<0.002)
    return fail(r,"landmark registration ambiguous/unqualified; do not subtract without external calibration");
  const std::string answer=std::to_string(bestX)+" "+std::to_string(bestY)+" "+
      std::to_string(int64_t(std::llround(best*1000000.)))+" "+std::to_string(bestSamples);
  if(!emit(r,answer.data(),answer.size()))return fail(r,"registration result allocation");
  return 0;
}

/* Valid overlap of a translated image. Out-of-frame pixels are NOT data. */
extern "C" size_t REXXENTRY MOARasterOpValidity(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  int64_t w,h,dx,dy;
  if(n!=4||!number(a[0],w)||!number(a[1],h)||
     !number(a[2],dx,true)||!number(a[3],dy,true)||w<1||h<1||
     w*h>2000000||std::abs(dx)>=w||std::abs(dy)>=h)
    return fail(r,"invalid registration validity envelope");
  std::vector<uint8_t>out(size_t(w*h),0);
  for(int64_t y=0;y<h;y++)for(int64_t x=0;x<w;x++){
    const int64_t sx=x-dx,sy=y-dy;
    if(sx>=0&&sx<w&&sy>=0&&sy<h)out[size_t(y*w+x)]=255;
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"invalid registration validity allocation");
  return 0;
}

/* Dev7: similarity registration is a bounded pixel-space primitive.
 * ooRexx owns landmark selection, provenance, thresholds, and approval.
 * Scale is positive and uniform; this is NOT projective/parallax alignment.
 * Reference-domain x,y maps to target-domain:
 *   source = centre + (reference - centre - shift) / scale.
 */
namespace {
struct Similarity {
  double shiftX = 0, shiftY = 0, scale = 1;
};
struct SimilarityScore { double error = std::numeric_limits<double>::infinity(); int count = 0; };
struct LandmarkPoint { int x=0,y=0; double gx=0,gy=0; };
static std::vector<uint8_t> grayPlane(const uint8_t*rgb,int64_t w,int64_t h,int64_t depth) {
  std::vector<uint8_t> gray(size_t(w*h));
  for(int64_t i=0;i<w*h;i++){
    const auto* p=rgb+size_t(i*depth);
    gray[size_t(i)]=uint8_t((54*int(p[0])+183*int(p[1])+19*int(p[2])+128)>>8);
  }
  return gray;
}
static inline bool mapped(double x,double y,int64_t w,int64_t h,const Similarity&s,double&sx,double&sy) {
  const double cx=(w-1)*0.5,cy=(h-1)*0.5;
  sx=cx+(x-cx-s.shiftX)/s.scale;
  sy=cy+(y-cy-s.shiftY)/s.scale;
  return sx>=0&&sy>=0&&sx<=double(w-1)&&sy<=double(h-1);
}
static double bilinearGray(const uint8_t*img,int64_t w,int64_t h,double x,double y) {
  if(x<0||y<0||x>double(w-1)||y>double(h-1))return -1.;
  const auto xa=int64_t(x),ya=int64_t(y),xb=std::min<int64_t>(xa+1,w-1),yb=std::min<int64_t>(ya+1,h-1);
  const double a=x-double(xa),b=y-double(ya);
  const double top=(1-a)*double(img[size_t(ya*w+xa)])+a*double(img[size_t(ya*w+xb)]);
  const double bottom=(1-a)*double(img[size_t(yb*w+xa)])+a*double(img[size_t(yb*w+xb)]);
  return (1-b)*top+b*bottom;
}
static std::vector<LandmarkPoint> selectLandmark(const uint8_t*ref,int64_t w,int64_t h,
                                                int64_t left,int64_t top,int64_t rw,int64_t rh,int step=3){
  std::vector<LandmarkPoint> obs;
  for(int64_t y=std::max<int64_t>(top+2,2);y<top+rh-2;y+=step)
    for(int64_t x=std::max<int64_t>(left+2,2);x<left+rw-2;x+=step){
      if(x>=w-2||y>=h-2)continue;
      const double L=ref[size_t(y*w+x-1)],R=ref[size_t(y*w+x+1)];
      const double U=ref[size_t((y-1)*w+x)],D=ref[size_t((y+1)*w+x)];
      const double gx=(R-L)/(R+L+32.),gy=(D-U)/(D+U+32.);
      if(std::abs(gx)+std::abs(gy)<0.044)continue;
      obs.push_back(LandmarkPoint{int(x),int(y),gx,gy});
    }
  return obs;
}
static SimilarityScore scoreLandmark(const uint8_t*target,int64_t w,int64_t h,
                                   const std::vector<LandmarkPoint>&obs,const Similarity&s){
  double total=0.;int used=0;
  for(const auto&p:obs){
    double sx,sy;
    if(!mapped(double(p.x),double(p.y),w,h,s,sx,sy) ||
       sx<1.001||sy<1.001||sx>double(w-2.001)||sy>double(h-2.001))continue;
    const double L=bilinearGray(target,w,h,sx-1.,sy);
    const double R=bilinearGray(target,w,h,sx+1.,sy);
    const double U=bilinearGray(target,w,h,sx,sy-1.);
    const double D=bilinearGray(target,w,h,sx,sy+1.);
    const double gx=(R-L)/(R+L+32.),gy=(D-U)/(D+U+32.);
    /* Clamp cost of transient lights, not their geometry, to retain stable buildings. */
    total+=std::min(0.7,std::abs(p.gx-gx)+std::abs(p.gy-gy));used++;
  }
  return SimilarityScore{used>=18?total/double(used):std::numeric_limits<double>::infinity(),used};
}
static bool parseGeometry(PCONSTRXSTRING a,size_t n,int64_t&w,int64_t&h,int64_t&d,
                         int64_t&l,int64_t&t,int64_t&rw,int64_t&rh){
  uint64_t uw,uh,ud,tw,th,td;
  if(n<12||!raster(a,0,uw,uh,ud)||!raster(a,4,tw,th,td)||uw!=tw||uh!=th||
     !number(a[8],l)||!number(a[9],t)||!number(a[10],rw)||!number(a[11],rh))return false;
  w=int64_t(uw);h=int64_t(uh);d=int64_t(ud);
  return rw>=18&&rh>=18&&l>=0&&t>=0&&l+rw<=w&&t+rh<=h;
}
static bool parseSimilarity(const CONSTRXSTRING&dx,const CONSTRXSTRING&dy,const CONSTRXSTRING&scale,
                            Similarity&s){
  int64_t x,y,z;
  if(!number(dx,x,true)||!number(dy,y,true)||!number(scale,z)||
     z<800000||z>1200000)return false;
  s.shiftX=double(x)/1000.;s.shiftY=double(y)/1000.;s.scale=double(z)/1000000.;
  return std::isfinite(s.scale)&&s.scale>0.;
}
}
extern "C" size_t REXXENTRY MOARasterOpEstimateSimilarity(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  int64_t w,h,d,l,t,rw,rh,maxShift,maxScalePerMille,stepPerMille;
  if(n!=15||!parseGeometry(a,n,w,h,d,l,t,rw,rh)||
     !number(a[12],maxShift)||!number(a[13],maxScalePerMille)||
     !number(a[14],stepPerMille)||maxShift>12||maxScalePerMille>100||
     maxScalePerMille<0||stepPerMille<1||stepPerMille>20)
    return fail(r,"similarity registration invalid geometry or bounds");
  const auto* ref=reinterpret_cast<const uint8_t*>(a[0].strptr);
  const auto* trg=reinterpret_cast<const uint8_t*>(a[4].strptr);
  const auto rg=grayPlane(ref,w,h,d);
  const auto tg=grayPlane(trg,w,h,int64_t(a[4].strlength/(w*h)));
  const auto obs=selectLandmark(rg.data(),w,h,l,t,rw,rh,3);
  if(obs.size()<36)return fail(r,"similarity landmark has insufficient texture");
  Similarity best,second;SimilarityScore bscore,sscore;
  for(int64_t per=-maxScalePerMille;per<=maxScalePerMille;per+=stepPerMille){
    Similarity trial;trial.scale=1.+double(per)/1000.;
    for(int64_t dy=-maxShift;dy<=maxShift;dy++)for(int64_t dx=-maxShift;dx<=maxShift;dx++){
      trial.shiftX=double(dx);trial.shiftY=double(dy);
      const auto score=scoreLandmark(tg.data(),w,h,obs,trial);
      if(score.error<bscore.error){second=best;sscore=bscore;best=trial;bscore=score;}
      else if(score.error<sscore.error){second=trial;sscore=score;}
    }
  }
  if(!std::isfinite(bscore.error)||bscore.count<36)return fail(r,"similarity landmark fit was not measurable");
  // Refine subpixel translation and 0.1 percent scale locally; deterministic bounds.
  const Similarity first=best;
  for(int zi=-3;zi<=3;zi++)for(int yi=-4;yi<=4;yi++)for(int xi=-4;xi<=4;xi++){
    Similarity s=first;
    s.scale+=double(zi)*0.001;
    s.shiftX+=double(xi)*0.25;s.shiftY+=double(yi)*0.25;
    if(std::abs(s.scale-1.)>double(maxScalePerMille)/1000.+0.00001||
       std::abs(s.shiftX)>double(maxShift)+0.00001||std::abs(s.shiftY)>double(maxShift)+0.00001)continue;
    const auto score=scoreLandmark(tg.data(),w,h,obs,s);
    if(score.error<bscore.error){best=s;bscore=score;}
  }
  /* Runner-up must be genuinely independent, not an adjacent subpixel fit. */
  double runner=std::numeric_limits<double>::infinity();
  for(int64_t per=-maxScalePerMille;per<=maxScalePerMille;per+=stepPerMille){
    Similarity trial;trial.scale=1.+double(per)/1000.;
    for(int64_t dy=-maxShift;dy<=maxShift;dy++)for(int64_t dx=-maxShift;dx<=maxShift;dx++){
      trial.shiftX=double(dx);trial.shiftY=double(dy);
      if(std::abs(trial.shiftX-best.shiftX)<1.1&&std::abs(trial.shiftY-best.shiftY)<1.1&&
         std::abs(trial.scale-best.scale)<0.006)continue;
      const auto score=scoreLandmark(tg.data(),w,h,obs,trial);
      runner=std::min(runner,score.error);
    }
  }
  if(!std::isfinite(runner))runner=1.;
  const std::string answer=std::to_string(std::llround(best.shiftX*1000.))+" "+
     std::to_string(std::llround(best.shiftY*1000.))+" "+
     std::to_string(std::llround(best.scale*1000000.))+" "+
     std::to_string(std::llround(bscore.error*1000000.))+" "+
     std::to_string(bscore.count)+" "+std::to_string(std::llround(runner*1000000.));
  if(!emit(r,answer.data(),answer.size()))return fail(r,"similarity output allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpScoreSimilarity(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  int64_t w,h,d,l,t,rw,rh;
  if(n!=15||!parseGeometry(a,n,w,h,d,l,t,rw,rh))return fail(r,"invalid independent registration ROI");
  Similarity s;
  if(!parseSimilarity(a[12],a[13],a[14],s))return fail(r,"invalid independent registration transform");
  const auto ref=grayPlane(reinterpret_cast<const uint8_t*>(a[0].strptr),w,h,d);
  const auto trg=grayPlane(reinterpret_cast<const uint8_t*>(a[4].strptr),w,h,int64_t(a[4].strlength/(w*h)));
  const auto obs=selectLandmark(ref.data(),w,h,l,t,rw,rh,3);
  const auto score=scoreLandmark(trg.data(),w,h,obs,s);
  if(!std::isfinite(score.error)||score.count<25)return fail(r,"independent landmark area has insufficient evidence");
  const std::string answer=std::to_string(std::llround(score.error*1000000.))+" "+std::to_string(score.count);
  if(!emit(r,answer.data(),answer.size()))return fail(r,"independent score allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpWarpSimilarity(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  uint64_t w,h,d;if(n!=7||!raster(a,0,w,h,d))return fail(r,"invalid similarity source");
  Similarity s;if(!parseSimilarity(a[4],a[5],a[6],s))return fail(r,"invalid similarity transform");
  if(std::abs(s.shiftX)>128||std::abs(s.shiftY)>128)return fail(r,"similarity shift outside bound");
  const auto*src=reinterpret_cast<const uint8_t*>(a[0].strptr);
  std::vector<uint8_t>out(size_t(w*h*d),0);
  for(int64_t y=0;y<int64_t(h);y++)for(int64_t x=0;x<int64_t(w);x++){
    double sx,sy;if(!mapped(double(x),double(y),int64_t(w),int64_t(h),s,sx,sy))continue;
    const auto x0=int64_t(sx),y0=int64_t(sy),x1=std::min<int64_t>(x0+1,int64_t(w)-1),y1=std::min<int64_t>(y0+1,int64_t(h)-1);
    const double u=sx-double(x0),v=sy-double(y0);
    for(uint64_t c=0;c<d;c++){
      const auto a0=src[size_t((y0*int64_t(w)+x0)*int64_t(d)+int64_t(c))];
      const auto b0=src[size_t((y0*int64_t(w)+x1)*int64_t(d)+int64_t(c))];
      const auto c0=src[size_t((y1*int64_t(w)+x0)*int64_t(d)+int64_t(c))];
      const auto d0=src[size_t((y1*int64_t(w)+x1)*int64_t(d)+int64_t(c))];
      out[size_t((y*int64_t(w)+x)*int64_t(d)+int64_t(c))]=uint8_t(std::clamp(std::llround(
             (1-v)*((1-u)*a0+u*b0)+v*((1-u)*c0+u*d0)),0LL,255LL));
    }
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"warp output allocation");
  return 0;
}
extern "C" size_t REXXENTRY MOARasterOpValiditySimilarity(const char*,size_t n,PCONSTRXSTRING a,const char*,PRXSTRING r){
  int64_t w,h;
  if(n!=5||!number(a[0],w)||!number(a[1],h)||w<1||h<1||w*h>2000000)
    return fail(r,"invalid similarity validity dimensions");
  Similarity s;if(!parseSimilarity(a[2],a[3],a[4],s))return fail(r,"invalid similarity validity transform");
  if(std::abs(s.shiftX)>128||std::abs(s.shiftY)>128)return fail(r,"similarity shift outside bound");
  std::vector<uint8_t>out(size_t(w*h),0);
  for(int64_t y=0;y<h;y++)for(int64_t x=0;x<w;x++){
    double sx,sy;if(mapped(double(x),double(y),w,h,s,sx,sy))out[size_t(y*w+x)]=255;
  }
  if(!emit(r,out.data(),out.size()))return fail(r,"similarity validity allocation");
  return 0;
}