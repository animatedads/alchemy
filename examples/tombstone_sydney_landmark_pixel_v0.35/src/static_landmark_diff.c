/* Sydney Harbour V5V/Power SLAM v0.35: source-pixel, same-site
 * static landmark alignment and candidate occlusion measurement.
 * Two unmodified video streams must be decoded independently to exactly
 * seven 640x360 RGB24 frames by the reproducible runner. No OpenCV.
 * The normal-traffic reference was captured ~28m35s later, so output is
 * RETROSPECTIVE_IMAGE_DIAGNOSTIC, never a causal recognition result.
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <limits.h>
#define W 640
#define H 360
#define PIX ((size_t)W*H*3)
#define SAMPLES 7
static const int frames[SAMPLES]={150,450,750,900,1050,1350,1650};
typedef struct{const char*id;int x0,y0,x1,y1;} Region;
static const Region stable[]={
 {"BRIDGE_LEFT_TOWER",30,115,67,173},
 {"BRIDGE_ARCH_CROWN",124,76,224,116},
 {"RIGHT_CITY_BACKGROUND",551,131,621,174}
};
static const Region candidates[]={
 {"BRIDGE_RIGHT_TOWER",304,127,340,194},
 {"OCCLUDED_WATERFRONT",374,150,500,194},
 {"SHIP_CHANNEL_PATCH",265,170,506,251}
};
static void fail(const char*s){fprintf(stderr,"PIXEL_ANCHOR_FAIL: %s\n",s);exit(3);}
static int lum(const uint8_t *p,int x,int y){size_t t=((size_t)y*W+(size_t)x)*3;return (54*p[t]+183*p[t+1]+19*p[t+2]+128)>>8;}
static long regionSad(const uint8_t*a,const uint8_t*b,Region r,int dx,int dy){
 long sad=0;
 for(int y=r.y0;y<r.y1;y++)for(int x=r.x0;x<r.x1;x++){
  int bx=x+dx,by=y+dy;
  if(bx<0||bx>=W||by<0||by>=H)fail("anchor shifted beyond frame");
  int d=lum(a,x,y)-lum(b,bx,by); sad+=(d<0?-d:d);
 }
 return sad;
}
static void stats(const uint8_t*a,const uint8_t*b,Region r,int dx,int dy,double*mean,double*above){
 long sad=0,large=0;long n=(r.x1-r.x0)*(r.y1-r.y0);
 for(int y=r.y0;y<r.y1;y++)for(int x=r.x0;x<r.x1;x++){
  int d=lum(a,x,y)-lum(b,x+dx,y+dy);if(d<0)d=-d;
  sad+=d;if(d>35)large++;
 }
 *mean=(double)sad/n;*above=(double)large/n;
}
static FILE*openInput(const char*path){FILE*f=fopen(path,"rb");if(!f)fail("cannot open RGB input");if(fseek(f,0,SEEK_END))fail("seek input");long n=ftell(f);if(n!=(long)(SAMPLES*PIX))fail("not exactly seven 640x360 RGB frames");rewind(f);return f;}
static void hexSha(const char*s){if(strlen(s)!=64)fail("SHA length");for(int i=0;i<64;i++){char c=s[i];if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')))fail("SHA characters");}}
int main(int argc,char**argv){
 if(argc!=5){fprintf(stderr,"Usage: static_landmark_diff cruise.rgb baseline.rgb cruiseSHA baselineSHA\n");return 2;}
 hexSha(argv[3]);hexSha(argv[4]);if(!strcmp(argv[3],argv[4]))fail("same source SHA");
 FILE*fa=openInput(argv[1]),*fb=openInput(argv[2]);
 uint8_t *a=malloc(PIX),*b=malloc(PIX);if(!a||!b)fail("alloc");
 printf("frame|cruise_sha256|baseline_sha256|shift_x_px|shift_y_px|stable_mean_abs_luma|stable_frac_diff_gt35|right_pylon_mean_abs_luma|right_pylon_frac_diff_gt35|waterfront_frac_diff_gt35|channel_frac_diff_gt35|method|evidence_state\n");
 for(int i=0;i<SAMPLES;i++){
  if(fread(a,1,PIX,fa)!=PIX||fread(b,1,PIX,fb)!=PIX)fail("truncated RGB stack");
  long best=LONG_MAX;int dx0=0,dy0=0;
  for(int dy=-3;dy<=3;dy++)for(int dx=-3;dx<=3;dx++){
   long s=0;for(size_t j=0;j<sizeof(stable)/sizeof(stable[0]);j++)s+=regionSad(a,b,stable[j],dx,dy);
   if(s<best){best=s;dx0=dx;dy0=dy;}
  }
  long nstable=0;for(size_t j=0;j<sizeof(stable)/sizeof(stable[0]);j++)nstable+=(stable[j].x1-stable[j].x0)*(stable[j].y1-stable[j].y0);
  long change=0;
  for(size_t j=0;j<sizeof(stable)/sizeof(stable[0]);j++){
   Region r=stable[j];for(int y=r.y0;y<r.y1;y++)for(int x=r.x0;x<r.x1;x++){
    int d=lum(a,x,y)-lum(b,x+dx0,y+dy0);if(d<0)d=-d;if(d>35)change++;
   }
  }
  double m,rc,wm,wp,cm,cp;
  stats(a,b,candidates[0],dx0,dy0,&m,&rc);
  stats(a,b,candidates[1],dx0,dy0,&wm,&wp);
  stats(a,b,candidates[2],dx0,dy0,&cm,&cp);
  printf("%d|%s|%s|%d|%d|%.6f|%.6f|%.6f|%.6f|%.6f|%.6f|RETROSPECTIVE_IMAGE_DIFFERENCE_NOT_CAUSAL|OBSERVED_UNTESTED\n",
    frames[i],argv[3],argv[4],dx0,dy0,(double)best/nstable,(double)change/nstable,m,rc,wp,cp);
 }
 if(fgetc(fa)!=EOF||fgetc(fb)!=EOF)fail("unexpected trailing frames");
 fclose(fa);fclose(fb);free(a);free(b);return 0;
}
