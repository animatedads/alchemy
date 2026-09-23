#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.141592653589793238462643383279502884
#endif
int main(int argc,char**argv){
  if(argc!=4){fprintf(stderr,"usage: %s IN.f32 SR HZ\n",argv[0]);return 2;}
  const char*path=argv[1];int sr=atoi(argv[2]);double hz=atof(argv[3]);FILE*f=fopen(path,"rb");if(!f)return 3;
  double s=0,c=0;size_t i=0;float x;while(fread(&x,sizeof(x),1,f)==1){double a=2*M_PI*hz*(double)i/(double)sr;s+=x*sin(a);c+=x*cos(a);i++;}fclose(f);if(i<1)return 4;double amp=2*sqrt(s*s+c*c)/(double)i;printf("%.12g\n",amp);return 0;
}
