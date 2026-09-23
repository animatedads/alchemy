/*
 * Live Vision encoder test-bed.
 *
 * Acquisition stays in libvision_ffmpeg.  This layer converts each complete
 * 55x73 RGB24 transaction into a deterministic 26-value surface and packs the
 * 0..25 indices as a contiguous 5-bit stream (MSB first).
 *
 * dev2 uses a deterministic fixed 26-level neutral curve so we can qualify the
 * live codec transaction itself.  Adaptive three-curve palette selection stays
 * a Vision policy and can replace make_palette() without changing framing.
 */
#include "vision_ffmpeg.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define VALUES 26

static uint32_t fnv1a(const unsigned char *p,size_t n){
    uint32_t h=2166136261u; while(n--){h^=*p++;h*=16777619u;} return h;
}
static void make_palette(uint8_t pal[VALUES][3]){
    for(int i=0;i<VALUES;i++){
        int v=(i*255 + (VALUES-2)/2)/(VALUES-1);
        pal[i][0]=pal[i][1]=pal[i][2]=(uint8_t)v;
    }
}
static uint8_t nearest(const uint8_t pal[VALUES][3],uint8_t r,uint8_t g,uint8_t b){
    unsigned best=~0u; uint8_t bi=0;
    for(uint8_t i=0;i<VALUES;i++){
        int dr=(int)r-pal[i][0], dg=(int)g-pal[i][1], db=(int)b-pal[i][2];
        unsigned d=(unsigned)(dr*dr+dg*dg+db*db);
        if(d<best){best=d;bi=i;}
    }
    return bi;
}
static size_t pack5(const uint8_t *idx,size_t count,uint8_t *out){
    memset(out,0,(count*5+7)/8);
    size_t bit=0;
    for(size_t i=0;i<count;i++){
        unsigned v=idx[i]&31u;
        for(int k=4;k>=0;k--,bit++)
            if(v&(1u<<k)) out[bit>>3]|=(uint8_t)(1u<<(7-(bit&7)));
    }
    return (count*5+7)/8;
}
int main(int argc,char **argv){
    if(argc<2){fprintf(stderr,"usage: vision_live_probe URL [W H FPS]\n");return 64;}
    int w=argc>2?atoi(argv[2]):55, h=argc>3?atoi(argv[3]):73;
    double fps=argc>4?atof(argv[4]):5;
    size_t pixels=(size_t)w*h, rgbn=pixels*3, packedn=(pixels*5+7)/8;
    unsigned char *rgb=malloc(rgbn), *idx=malloc(pixels), *packed=malloc(packedn);
    uint8_t pal[VALUES][3]; make_palette(pal);
    char err[256]={0}; VisionFfmpeg *v=vision_ffmpeg_open(argv[1],w,h,fps,err,sizeof err);
    if(!v){fprintf(stderr,"%s\n",err);return 65;}
    long seq=0; double ts=0;
    while(1){
        int rc=vision_ffmpeg_next_rgb24(v,rgb,rgbn,&ts,err,sizeof err);
        if(rc==0)break;
        if(rc<0){fprintf(stderr,"%s\n",err);return 66;}
        for(size_t i=0;i<pixels;i++)
            idx[i]=nearest(pal,rgb[i*3],rgb[i*3+1],rgb[i*3+2]);
        size_t got=pack5(idx,pixels,packed);
        printf("VISION\t%ld\t%.6f\t%d\t%d\t%zu\t%zu\t%08x\t%08x\n",
               ++seq,ts,w,h,rgbn,got,fnv1a(rgb,rgbn),fnv1a(packed,got));
        fflush(stdout);
    }
    vision_ffmpeg_close(v); free(rgb);free(idx);free(packed);return 0;
}
