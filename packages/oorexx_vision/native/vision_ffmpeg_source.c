#include "vision_ffmpeg.h"
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char **argv){
    if(argc<2){fprintf(stderr,"usage: vision_ffmpeg_source URL [W H FPS [SOURCE_SECONDS]]\n");return 64;}
    int w=argc>2?atoi(argv[2]):55, h=argc>3?atoi(argv[3]):73;
    double fps=argc>4?atof(argv[4]):5, seconds=argc>5?atof(argv[5]):0;
    char err[256]={0}; VisionFfmpeg *v=vision_ffmpeg_open(argv[1],w,h,fps,err,sizeof err);
    if(!v){fprintf(stderr,"%s\n",err);return 65;}
    size_t n=(size_t)w*h*3; unsigned char *buf=malloc(n); double ts=0, first=-1; long frames=0;
    while(1){
      int rc=vision_ffmpeg_next_rgb24(v,buf,n,&ts,err,sizeof err); if(rc==0)break;
      if(rc<0){fprintf(stderr,"%s\n",err);vision_ffmpeg_close(v);free(buf);return 66;}
      if(first<0) first=ts;
      if(seconds>0 && frames>0 && ts-first >= seconds) break;
      if(fwrite(buf,1,n,stdout)!=n)break; fflush(stdout); frames++;
    }
    fprintf(stderr,"vision_ffmpeg_source: frames=%ld source_seconds=%.3f\n",frames,first<0?0:ts-first);
    vision_ffmpeg_close(v); free(buf); return 0;
}
