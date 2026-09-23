#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.141592653589793238462643383279502884
#endif

static uint32_t state=0x9e3779b9u;
static double rnd(void){state^=state<<13;state^=state>>17;state^=state<<5;return ((state&0xffffu)/32768.0)-1.0;}

int main(int argc,char**argv){
  if(argc!=6){fprintf(stderr,"usage: %s A.f32 B.f32 sample_rate seconds lag_samples\n",argv[0]);return 2;}
  const char*aPath=argv[1],*bPath=argv[2];int sr=atoi(argv[3]),sec=atoi(argv[4]),lag=atoi(argv[5]);
  if(sr<1000||sec<1){fprintf(stderr,"invalid fixture geometry\n");return 2;}size_t n=(size_t)sr*sec;
  float*a=(float*)calloc(n,sizeof(float)),*b=(float*)calloc(n,sizeof(float));if(!a||!b)return 3;
  double lp=0;
  for(size_t i=0;i<n;++i){
    double t=(double)i/sr;
    double gate=0.18+0.82*(0.5+0.5*sin(2*M_PI*3.7*t+0.35*sin(2*M_PI*0.41*t)));
    lp=0.86*lp+0.14*rnd();
    double carrier=0.34*sin(2*M_PI*173.0*t)+0.19*sin(2*M_PI*317.0*t+0.2)+0.11*sin(2*M_PI*521.0*t+0.8);
    double impulse=((i%(size_t)(sr*1.37))<3)?0.65:0.0;
    a[i]=(float)(0.19*gate*lp+0.07*gate*carrier+impulse);
  }
  for(size_t j=0;j<n;++j){long src=(long)j-lag;double v=(src>=0&&src<(long)n)?a[src]:0.0;b[j]=(float)(0.78*v+0.005*rnd());}
  FILE*fa=fopen(aPath,"wb"),*fb=fopen(bPath,"wb");if(!fa||!fb){perror("fopen");return 4;}
  if(fwrite(a,sizeof(float),n,fa)!=n||fwrite(b,sizeof(float),n,fb)!=n){perror("fwrite");return 5;}
  fclose(fa);fclose(fb);free(a);free(b);return 0;
}
