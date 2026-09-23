#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#define SR 8000
#define SECONDS 12
#define N (SR*SECONDS)

static uint32_t rng_state=0x31415926u;
static float noise_sample(void){
  rng_state=rng_state*1664525u+1013904223u;
  return (float)(((int32_t)(rng_state>>8))/8388608.0)*0.004f;
}
static void add_probe(float*x,size_t at,float amp){
  /* 48-sample deterministic broadband transient with a unique asymmetric shape. */
  static const int8_t p[48]={
    3,-7,12,-19,27,-35,44,-52,61,-69,76,-82,87,-91,94,-96,
    93,-88,81,-73,64,-55,46,-38,31,-25,20,-16,13,-10,8,-6,
    5,-4,3,-2,2,-1,1,0,-1,1,-1,1,0,0,0,0
  };
  for(size_t i=0;i<48&&at+i<N;++i)x[at+i]+=amp*(float)p[i]/96.0f;
}
static int write_f32(const char*path,const float*x){
  FILE*f=fopen(path,"wb");if(!f)return 0;
  int ok=fwrite(x,sizeof(float),N,f)==N;fclose(f);return ok;
}
int main(int argc,char**argv){
  if(argc!=3){fprintf(stderr,"usage: %s FC.f32 FD.f32\n",argv[0]);return 2;}
  float*fc=calloc(N,sizeof(float)),*fd=calloc(N,sizeof(float));if(!fc||!fd)return 3;
  for(size_t i=0;i<N;++i){fc[i]=noise_sample();fd[i]=noise_sample();}
  /* Event 1: FD-side door/stairwell probe. FD leads FC by 177 samples
     (~22.125 ms).  FD has strong ~23.32 ms and ~58.30 ms replicas. */
  size_t d1=2*SR;add_probe(fd,d1,0.95f);add_probe(fc,d1+177,0.62f);
  add_probe(fd,d1+187,0.44f);add_probe(fd,d1+466,0.30f);
  add_probe(fc,d1+177+208,0.20f);
  /* Event 2: FC/road-side probe. FC leads FD by 140 samples (17.50 ms)
     and has a local 17.50 ms replica. */
  size_t d2=5*SR;add_probe(fc,d2,0.92f);add_probe(fd,d2+140,0.55f);
  add_probe(fc,d2+140,0.34f);
  /* Event 3: mobile/unconstrained probe with no modeled room echo. */
  size_t d3=8*SR;add_probe(fc,d3,0.78f);add_probe(fd,d3+24,0.75f);
  add_probe(fc,d3+280,0.22f);add_probe(fd,d3+280+24,0.21f); /* 35 ms */
  /* Event 4: low-gain FD-side probe.  Both direct peaks are below the dev11
     absolute 0.50 admission floor, but are very large relative to their own
     local baselines.  The 58.30-ms family is placed at the +4 ms v2 search
     boundary to qualify explicit clipping evidence. */
  size_t d4=10*SR;add_probe(fd,d4,0.18f);add_probe(fc,d4+96,0.09f);
  add_probe(fd,d4+498,0.11f); /* 62.25 ms ~= 58.30 + 4 ms boundary */
  /* Event 5: low-gain paired probe whose cross-feed arrival sits exactly
     on the existing +/-35 ms calibration boundary.  V3 must flag this as
     censored rather than treating 35 ms as an unconstrained measurement. */
  size_t d5=11*SR;add_probe(fc,d5,0.24f);add_probe(fd,d5+280,0.22f);
  int ok=write_f32(argv[1],fc)&&write_f32(argv[2],fd);free(fc);free(fd);return ok?0:4;
}
