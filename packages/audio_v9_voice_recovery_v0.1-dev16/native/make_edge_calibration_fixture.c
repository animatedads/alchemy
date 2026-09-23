#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.141592653589793238462643383279502884
#endif
static double bank(long i,int sr,double f0,double step,int count,double modRate,double phaseBase){
  double t,sum=0;
  if(i<0) return 0;
  t=(double)i/(double)sr;
  for(int k=0;k<count;k++){
    double f=f0+step*(double)k+0.37*sin((double)(k+1));
    double amp=(0.055/(double)count)*(1.0+0.25*sin(2*M_PI*(modRate+0.009*(double)k)*t+0.23*(double)k));
    double phase=2*M_PI*f*t+phaseBase*(double)(k+1)+1.7*sin(2*M_PI*(0.071+0.003*(double)k)*t+0.17*(double)k);
    sum+=amp*sin(phase);
  }
  return sum;
}
static double source1(long i,int sr){return bank(i,sr,205.0,27.31,23,.41,.619);}
static double source2(long i,int sr){return bank(i,sr,1175.0,61.73,23,.29,.947);}
int main(int argc,char**argv){
  const char*ap; const char*bp; int sr,sec; size_t n,edge; FILE*a; FILE*b;
  if(argc!=5){fprintf(stderr,"usage: %s FC.f32 FD.f32 SR SECONDS\n",argv[0]);return 2;}
  ap=argv[1];bp=argv[2];sr=atoi(argv[3]);sec=atoi(argv[4]);if(sr<1000||sec<8)return 2;
  n=(size_t)sr*(size_t)sec;edge=n/2;a=fopen(ap,"wb");b=fopen(bp,"wb");if(!a||!b){if(a)fclose(a);if(b)fclose(b);return 3;}
  for(size_t j=0;j<n;j++){
    float av=(float)(source1((long)j,sr)+source2((long)j,sr));
    int lag=j<edge?10:7; long k=(long)j-(long)lag;
    float bv=(float)(source1(k,sr)+source2(k,sr));
    if(fwrite(&av,sizeof(av),1,a)!=1||fwrite(&bv,sizeof(bv),1,b)!=1){fclose(a);fclose(b);return 4;}
  }
  fclose(a);fclose(b);return 0;
}
