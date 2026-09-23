#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.141592653589793238462643383279502884
#endif
int main(int argc,char**argv){
  if(argc!=4){fprintf(stderr,"usage: %s OUT.f32 SR SECONDS\n",argv[0]);return 2;}
  const char*path=argv[1];int sr=atoi(argv[2]),sec=atoi(argv[3]);if(sr<1000||sec<1)return 2;
  size_t n=(size_t)sr*(size_t)sec;FILE*f=fopen(path,"wb");if(!f)return 3;
  for(size_t i=0;i<n;i++){double t=(double)i/(double)sr;float x=(float)(0.12*sin(2*M_PI*400*t)+0.12*sin(2*M_PI*2200*t));if(fwrite(&x,sizeof(x),1,f)!=1){fclose(f);return 4;}}
  fclose(f);return 0;
}
