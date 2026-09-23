#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdarg.h>
#include <string.h>
#include <math.h>

static _Thread_local char g_error[512];
static _Thread_local char *g_text=NULL;
static _Thread_local size_t g_text_cap=0;

static void seterr(const char *msg){snprintf(g_error,sizeof(g_error),"%s",msg?msg:"unknown error");}
static void seterr2(const char *msg,const char *path){snprintf(g_error,sizeof(g_error),"%s: %s",msg?msg:"error",path?path:"");}
const char *av9_spatial_last_error(void){return g_error;}

static int ensure_text(size_t n){
  if(g_text_cap>=n) return 1;
  size_t cap=g_text_cap?g_text_cap:4096;
  while(cap<n) cap*=2;
  char*p=(char*)realloc(g_text,cap);if(!p){seterr("allocation failed");return 0;}g_text=p;g_text_cap=cap;return 1;
}
static int appendf(size_t *used,const char *fmt,...){
  for(;;){
    if(!ensure_text(*used+2048))return 0;
    va_list ap;va_start(ap,fmt);int n=vsnprintf(g_text+*used,g_text_cap-*used,fmt,ap);va_end(ap);
    if(n<0){seterr("formatting failed");return 0;}
    if((size_t)n<g_text_cap-*used){*used+=(size_t)n;return 1;}
    if(!ensure_text(*used+(size_t)n+1))return 0;
  }
}
static float *read_f32(const char *path,size_t *count){
  *count=0;FILE*f=fopen(path,"rb");if(!f){seterr2("cannot open f32",path);return NULL;}
  if(fseek(f,0,SEEK_END)!=0){fclose(f);seterr2("cannot seek f32",path);return NULL;}long bytes=ftell(f);
  if(bytes<0||(bytes%4)!=0){fclose(f);seterr2("invalid f32 byte size",path);return NULL;}
  if(fseek(f,0,SEEK_SET)!=0){fclose(f);seterr2("cannot rewind f32",path);return NULL;}size_t n=(size_t)bytes/4;
  if(n==0){fclose(f);seterr2("empty f32",path);return NULL;}float*x=(float*)malloc(n*sizeof(float));
  if(!x){fclose(f);seterr("allocation failed");return NULL;}if(fread(x,sizeof(float),n,f)!=n){free(x);fclose(f);seterr2("cannot read f32",path);return NULL;}
  fclose(f);*count=n;return x;
}
static double rms_of(const float*x,size_t n){long double ss=0;for(size_t i=0;i<n;++i){long double v=x[i];ss+=v*v;}return sqrt((double)(ss/n));}
static double peak_of(const float*x,size_t n){double p=0;for(size_t i=0;i<n;++i){double v=fabs((double)x[i]);if(v>p)p=v;}return p;}

/* A[i] with B[i+lag]. Positive lag => B appears later than A. */
static double corr_stride(const float*a,const float*b,size_t n,int lag,int stride){
  long start=lag<0?-(long)lag:0,end=lag>0?(long)n-lag:(long)n;if(end-start<8)return -2;
  long double sa=0,sb=0,saa=0,sbb=0,sab=0;size_t c=0;
  for(long i=start;i<end;i+=stride){long j=i+lag;long double x=a[i],y=b[j];sa+=x;sb+=y;saa+=x*x;sbb+=y*y;sab+=x*y;++c;}
  if(c<8) return -2;
  long double cov=sab-sa*sb/c,va=saa-sa*sa/c,vb=sbb-sb*sb/c;
  if(va<=1e-30L||vb<=1e-30L) return 0;
  return (double)(cov/sqrt((double)(va*vb)));
}
static int better(double score,int lag,double best,int bestlag){const double eps=1e-12;if(score>best+eps)return 1;if(fabs(score-best)<=eps){int a=lag<0?-lag:lag,b=bestlag<0?-bestlag:bestlag;if(a<b)return 1;if(a==b&&lag<bestlag)return 1;}return 0;}

static int build_env(const float*x,size_t n,uint32_t sr,double **out,size_t*outn,size_t*binSamples){
  size_t bin=sr/100;if(bin<1)bin=1;size_t m=n/bin;if(m<8){seterr("measurement requires at least 80 ms");return 0;}
  double*e=(double*)calloc(m,sizeof(double));if(!e){seterr("allocation failed");return 0;}
  for(size_t k=0;k<m;++k){long double s=0;size_t base=k*bin;for(size_t j=0;j<bin;++j)s+=fabs((double)x[base+j]);e[k]=(double)(s/bin);}
  *out=e;*outn=m;*binSamples=bin;return 1;
}
static double env_corr(const double*a,const double*b,size_t n,int lag){
  long start=lag<0?-(long)lag:0,end=lag>0?(long)n-lag:(long)n;if(end-start<8)return -2;
  long double sa=0,sb=0,saa=0,sbb=0,sab=0;size_t c=0;for(long i=start;i<end;++i){long j=i+lag;long double x=a[i],y=b[j];sa+=x;sb+=y;saa+=x*x;sbb+=y*y;sab+=x*y;++c;}
  long double cov=sab-sa*sb/c,va=saa-sa*sa/c,vb=sbb-sb*sb/c;if(va<=1e-30L||vb<=1e-30L)return 0;return(double)(cov/sqrt((double)(va*vb)));
}
static void best_wave_lag(const float*a,const float*b,size_t n,int center,int radius,uint32_t sr,int*outLag,double*outScore){
  int stride=(int)(sr/1000);if(stride<1)stride=1;int limit=(int)n-16;int lo=center-radius,hi=center+radius;if(lo<-limit)lo=-limit;if(hi>limit)hi=limit;
  double best=-3;int bestlag=center;if(bestlag<lo)bestlag=lo;if(bestlag>hi)bestlag=hi;
  for(int lag=lo;lag<=hi;lag+=stride){double sc=corr_stride(a,b,n,lag,stride);if(better(sc,lag,best,bestlag)){best=sc;bestlag=lag;}}
  int rlo=bestlag-stride,rhi=bestlag+stride;if(rlo<lo)rlo=lo;if(rhi>hi)rhi=hi;
  for(int lag=rlo;lag<=rhi;++lag){double sc=corr_stride(a,b,n,lag,stride);if(better(sc,lag,best,bestlag)){best=sc;bestlag=lag;}}
  *outLag=bestlag;*outScore=best;
}
static double local_coherence(const float*a,const float*b,size_t n,int lag,uint32_t sr){
  size_t frame=sr/50;if(frame<8)frame=8;long start=lag<0?-(long)lag:0,end=lag>0?(long)n-lag:(long)n;if(end-start<(long)frame)return 0;
  long double total=0;size_t frames=0;for(long base=start;base+(long)frame<=end;base+=(long)frame){long double xy=0,xx=0,yy=0;for(size_t k=0;k<frame;++k){long i=base+(long)k,j=i+lag;long double x=a[i],y=b[j];xy+=x*y;xx+=x*x;yy+=y*y;}if(xx>1e-30L&&yy>1e-30L){total+=fabs((double)(xy/sqrt((double)(xx*yy))));++frames;}}
  return frames?(double)(total/frames):0;
}

typedef struct {
  double rmsA,rmsB,peakA,peakB,crestA,crestB,ratioDb;
  int envLag,directLag,refinedLag;
  double envLagMs,directLagMs,refinedLagMs,envScore,directScore,refinedScore,directCoh,refinedCoh;
} measure_t;

static int compute_measure(const float*a,const float*b,size_t n,uint32_t sr,uint32_t max_env_ms,uint32_t max_direct_ms,measure_t*m){
  m->rmsA=rms_of(a,n);m->rmsB=rms_of(b,n);m->peakA=peak_of(a,n);m->peakB=peak_of(b,n);m->crestA=m->rmsA>1e-30?m->peakA/m->rmsA:0;m->crestB=m->rmsB>1e-30?m->peakB/m->rmsB:0;m->ratioDb=20*log10((m->rmsA+1e-30)/(m->rmsB+1e-30));
  double*ea=NULL,*eb=NULL;size_t en=0,enb=0,bin=0,binb=0;if(!build_env(a,n,sr,&ea,&en,&bin)||!build_env(b,n,sr,&eb,&enb,&binb)){free(ea);free(eb);return 0;}if(en!=enb||bin!=binb){free(ea);free(eb);seterr("envelope geometry mismatch");return 0;}
  int maxbins=(int)llround((double)max_env_ms/10.0);if(maxbins>(int)en-8)maxbins=(int)en-8;double best=-3;int bestlag=0;
  for(int lag=-maxbins;lag<=maxbins;++lag){double sc=env_corr(ea,eb,en,lag);if(better(sc,lag,best,bestlag)){best=sc;bestlag=lag;}}
  m->envLag=bestlag*(int)bin;m->envScore=best;m->envLagMs=1000.0*m->envLag/sr;free(ea);free(eb);
  int radius=(int)llround((double)sr*max_direct_ms/1000.0);
  best_wave_lag(a,b,n,0,radius,sr,&m->directLag,&m->directScore);
  best_wave_lag(a,b,n,m->envLag,radius,sr,&m->refinedLag,&m->refinedScore);
  m->directLagMs=1000.0*m->directLag/sr;m->refinedLagMs=1000.0*m->refinedLag/sr;
  m->directCoh=local_coherence(a,b,n,m->directLag,sr);m->refinedCoh=local_coherence(a,b,n,m->refinedLag,sr);return 1;
}

static int append_measure_fields(size_t*used,const measure_t*m){
  return appendf(used,"\tRMS_A=%.17g\tRMS_B=%.17g\tPEAK_A=%.17g\tPEAK_B=%.17g\tCREST_A=%.17g\tCREST_B=%.17g\tRATIO_DB=%.17g\tENV_LAG_SAMPLES=%d\tENV_LAG_MS=%.17g\tENV_SCORE=%.17g\tDIRECT_LAG_SAMPLES=%d\tDIRECT_LAG_MS=%.17g\tDIRECT_SCORE=%.17g\tDIRECT_COHERENCE=%.17g\tREFINED_LAG_SAMPLES=%d\tREFINED_LAG_MS=%.17g\tREFINED_SCORE=%.17g\tREFINED_COHERENCE=%.17g",
    m->rmsA,m->rmsB,m->peakA,m->peakB,m->crestA,m->crestB,m->ratioDb,m->envLag,m->envLagMs,m->envScore,m->directLag,m->directLagMs,m->directScore,m->directCoh,m->refinedLag,m->refinedLagMs,m->refinedScore,m->refinedCoh);
}

const char *av9_spatial_measure_tsv(const char*a_path,const char*b_path,uint32_t sr,uint32_t max_env_ms,uint32_t max_direct_ms){
  g_error[0]='\0';if(!a_path||!b_path||sr<1000||max_env_ms<10||max_direct_ms<1){seterr("invalid measurement arguments");return NULL;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a)return NULL;float*b=read_f32(b_path,&nb);if(!b){free(a);return NULL;}if(na!=nb){free(a);free(b);seterr("paired f32 sample counts differ");return NULL;}
  measure_t m;if(!compute_measure(a,b,na,sr,max_env_ms,max_direct_ms,&m)){free(a);free(b);return NULL;}free(a);free(b);size_t used=0;if(!ensure_text(4096))return NULL;g_text[0]='\0';
  if(!appendf(&used,"AUDIO_V9_SPATIAL/2\tSAMPLES=%zu\tSR=%u",na,sr)||!append_measure_fields(&used,&m)) return NULL;
  return g_text;
}

const char *av9_spatial_scan_tsv(const char*a_path,const char*b_path,uint32_t sr,uint32_t window_ms,uint32_t step_ms,uint32_t max_env_ms,uint32_t max_direct_ms){
  g_error[0]='\0';if(!a_path||!b_path||sr<1000||window_ms<80||step_ms<10){seterr("invalid scan arguments");return NULL;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a)return NULL;float*b=read_f32(b_path,&nb);if(!b){free(a);return NULL;}if(na!=nb){free(a);free(b);seterr("paired f32 sample counts differ");return NULL;}
  uint64_t win64=(uint64_t)sr*window_ms/1000,step64=(uint64_t)sr*step_ms/1000;if(win64<1||step64<1||win64>na){free(a);free(b);seterr("scan window exceeds paired audio");return NULL;}size_t win=(size_t)win64,step=(size_t)step64;
  size_t windows=1+(na-win)/step,used=0;if(!ensure_text(4096+windows*640)){free(a);free(b);return NULL;}g_text[0]='\0';
  if(!appendf(&used,"AUDIO_V9_SPATIAL_SCAN/1\tSAMPLES=%zu\tSR=%u\tWINDOW_MS=%u\tSTEP_MS=%u\tWINDOWS=%zu\n",na,sr,window_ms,step_ms,windows)){free(a);free(b);return NULL;}
  for(size_t w=0,pos=0;w<windows;++w,pos+=step){measure_t m;if(!compute_measure(a+pos,b+pos,win,sr,max_env_ms,max_direct_ms,&m)){free(a);free(b);return NULL;}
    if(!appendf(&used,"W\t%zu\t%zu\t%.17g\tSAMPLES=%zu\tSR=%u",w+1,pos,1000.0*pos/sr,win,sr)||!append_measure_fields(&used,&m)){free(a);free(b);return NULL;}if(!appendf(&used,"\n")){free(a);free(b);return NULL;}}
  free(a);free(b);return g_text;
}


/* dev11 loud-event echo survey.
 *
 * This is diagnostic-only.  It uses large, sharp transients as naturally
 * occurring acoustic probes.  The first onset is the template; only the next
 * 80 ms is searched for same-feed replicas around physically interesting room
 * delays.  No audio samples are modified and no event label is asserted from
 * amplitude alone.
 */
typedef struct {
  size_t sample;
  double peak;
  double base_a;
  double base_b;
  double ratio;
  int leader; /* 0 = A/FC, 1 = B/FD */
} loud_candidate_t;

typedef struct {
  const char *name;
  double delay_ms;
} echo_hyp_t;

static const echo_hyp_t g_echo_hyp[] = {
  {"BOX_CENTER_8_75",8.75},
  {"BOX_WALL_17_50",17.50},
  {"CONCRETE_INITIAL_22_09",22.09},
  {"DIVIDER_RETURN_23_32",23.32},
  {"BOX_CORNER_24_74",24.74},
  {"THROUGH_WALL_26_04",26.04},
  {"STAIRWELL_LONG_58_30",58.30}
};

static double rms_range(const float*x,size_t n,size_t a,size_t b){
  if(a>n) a=n;
  if(b>n) b=n;
  if(b<=a) return 0;
  long double ss=0;for(size_t i=a;i<b;++i){long double v=x[i];ss+=v*v;}
  return sqrt((double)(ss/(b-a)));
}
static double peak_range(const float*x,size_t n,size_t center,size_t radius){
  size_t a=center>radius?center-radius:0,b=center+radius+1;if(b>n)b=n;
  double p=0;for(size_t i=a;i<b;++i){double v=fabs((double)x[i]);if(v>p)p=v;}return p;
}
/* Absolute zero-mean normalized correlation of equal-length segments. */
static double segment_corr_abs(const float*x,size_t n,long a,long b,size_t len){
  if(a<0||b<0||(uint64_t)a+len>n||(uint64_t)b+len>n||len<8)return 0;
  long double sa=0,sb=0,saa=0,sbb=0,sab=0;
  for(size_t i=0;i<len;++i){long double u=x[a+(long)i],v=x[b+(long)i];sa+=u;sb+=v;saa+=u*u;sbb+=v*v;sab+=u*v;}
  long double c=(long double)len,cov=sab-sa*sb/c,va=saa-sa*sa/c,vb=sbb-sb*sb/c;
  if(va<=1e-30L||vb<=1e-30L)return 0;
  double r=(double)(cov/sqrt((double)(va*vb)));return fabs(r);
}
static double segment_cross_corr_abs(const float*templ,size_t nt,long ta,const float*other,size_t no,long ob,size_t len){
  if(ta<0||ob<0||(uint64_t)ta+len>nt||(uint64_t)ob+len>no||len<8)return 0;
  long double sa=0,sb=0,saa=0,sbb=0,sab=0;
  for(size_t i=0;i<len;++i){long double u=templ[ta+(long)i],v=other[ob+(long)i];sa+=u;sb+=v;saa+=u*u;sbb+=v*v;sab+=u*v;}
  long double c=(long double)len,cov=sab-sa*sb/c,va=saa-sa*sa/c,vb=sbb-sb*sb/c;
  if(va<=1e-30L||vb<=1e-30L)return 0;
  double r=(double)(cov/sqrt((double)(va*vb)));return fabs(r);
}
static void best_echo_at(const float*x,size_t n,long onset,size_t templ,int center,int radius,int*best_lag,double*best_score){
  long pre=(long)(templ/4),t0=onset-pre;double best=-1;int bl=center;
  for(int lag=center-radius;lag<=center+radius;++lag){
    double sc=segment_corr_abs(x,n,t0,t0+lag,templ);
    if(sc>best){best=sc;bl=lag;}
  }
  *best_lag=bl;*best_score=best<0?0:best;
}
static int append_candidate(loud_candidate_t**v,size_t*n,size_t*cap,loud_candidate_t c){
  if(*n==*cap){size_t nc=*cap?(*cap*2):64;loud_candidate_t*t=(loud_candidate_t*)realloc(*v,nc*sizeof(**v));if(!t){seterr("allocation failed");return 0;}*v=t;*cap=nc;}
  (*v)[(*n)++]=c;return 1;
}

int32_t av9_spatial_loud_echo_scan_tsv(const char*a_path,const char*b_path,const char*out_path,uint32_t sr,double min_peak,double min_ratio,uint32_t refractory_ms,uint32_t template_ms,uint32_t radius_ms,double start_serial){
  g_error[0]='\0';
  if(!a_path||!b_path||!out_path||sr<1000||!isfinite(min_peak)||min_peak<=0||!isfinite(min_ratio)||min_ratio<=1||refractory_ms<80||template_ms<2||template_ms>12||radius_ms<1||radius_ms>5||!isfinite(start_serial)||start_serial<0){seterr("invalid loud echo scan arguments");return -1;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a)return -1;float*b=read_f32(b_path,&nb);if(!b){free(a);return -1;}if(na!=nb){free(a);free(b);seterr("paired f32 sample counts differ");return -1;}
  size_t n=na,frame=sr/200;if(frame<8)frame=8; /* 5 ms */
  size_t baseline_guard=(size_t)((uint64_t)sr*50/1000),baseline_span=sr; /* prior 1 s, excluding last 50 ms */
  size_t refractory=(size_t)((uint64_t)sr*refractory_ms/1000),templ=(size_t)((uint64_t)sr*template_ms/1000);if(templ<8)templ=8;
  int radius=(int)((uint64_t)sr*radius_ms/1000);if(radius<1)radius=1;
  loud_candidate_t*raw=NULL;size_t rn=0,rcap=0;
  for(size_t base=0;base<n;base+=frame){
    size_t end=base+frame;if(end>n)end=n;double p=0;size_t ps=base;int leader=0;
    for(size_t i=base;i<end;++i){double pa=fabs((double)a[i]),pb=fabs((double)b[i]);if(pa>p){p=pa;ps=i;leader=0;}if(pb>p){p=pb;ps=i;leader=1;}}
    if(p<min_peak||ps<=baseline_guard+templ)continue;
    size_t bb=ps-baseline_guard,ba=bb>baseline_span?bb-baseline_span:0;
    double ra=rms_range(a,n,ba,bb),rb=rms_range(b,n,ba,bb),baseline=ra>rb?ra:rb;
    double ratio=p/(baseline+1e-12);if(ratio<min_ratio)continue;
    loud_candidate_t c={ps,p,ra,rb,ratio,leader};if(!append_candidate(&raw,&rn,&rcap,c)){free(raw);free(a);free(b);return -1;}
  }
  /* Cluster frame candidates into physical events.  Keep the largest onset in
     each refractory interval; modeled echoes (<80 ms) therefore cannot become
     separate events. */
  loud_candidate_t*ev=NULL;size_t en=0,ecap=0;
  for(size_t i=0;i<rn;++i){
    if(en&&raw[i].sample-ev[en-1].sample<refractory){if(raw[i].peak>ev[en-1].peak)ev[en-1]=raw[i];continue;}
    if(!append_candidate(&ev,&en,&ecap,raw[i])){free(raw);free(ev);free(a);free(b);return -1;}
  }
  free(raw);
  FILE*out=fopen(out_path,"w");if(!out){free(ev);free(a);free(b);seterr2("cannot create loud echo TSV",out_path);return -1;}
  fprintf(out,"event_index\tlocal_sample\tlocal_ms\tabsolute_serial_ms\tleader\tregion_hint\tpeak_fc\tpeak_fd\tbaseline_fc\tbaseline_fd\tpeak_to_baseline\tfd_minus_fc_samples\tfd_minus_fc_ms\tcross_score\tbest_echo_family\tbest_echo_delay_ms\tbest_echo_score\techo_match\tpattern_hint");
  for(size_t h=0;h<sizeof(g_echo_hyp)/sizeof(g_echo_hyp[0]);++h)fprintf(out,"\tfc_%s\tfd_%s",g_echo_hyp[h].name,g_echo_hyp[h].name);
  fputc('\n',out);
  size_t emitted=0;
  for(size_t e=0;e<en;++e){
    size_t t=ev[e].sample;long pre=(long)(templ/4);if(t<(size_t)pre||t+sr/10+templ>=n)continue;
    const float*lead=ev[e].leader?b:a;const float*other=ev[e].leader?a:b;
    int cross_radius=(int)((uint64_t)sr*35/1000),bestOther=0;double cross=-1;long lt=(long)t-pre;
    for(int lag=-cross_radius;lag<=cross_radius;++lag){double sc=segment_cross_corr_abs(lead,n,lt,other,n,lt+lag,templ);if(sc>cross){cross=sc;bestOther=lag;}}
    int fd_minus_fc=ev[e].leader? -bestOther:bestOther;
    long onsetA=ev[e].leader?((long)t+bestOther):(long)t;
    long onsetB=ev[e].leader?(long)t:((long)t+bestOther);
    size_t pr=sr/200;double peakA=(onsetA>=0&&onsetA<(long)n)?peak_range(a,n,(size_t)onsetA,pr):0,peakB=(onsetB>=0&&onsetB<(long)n)?peak_range(b,n,(size_t)onsetB,pr):0;
    const char*region="UNCONSTRAINED";if(cross>=0.35){if(peakA>peakB*1.35)region="FC_SIDE_CANDIDATE";else if(peakB>peakA*1.35)region="FD_SIDE_CANDIDATE";}
    double scoresA[7]={0},scoresB[7]={0};int lagsA[7]={0},lagsB[7]={0};double bestScore=-1,bestDelay=0;const char*bestName="NONE";
    for(size_t h=0;h<7;++h){int center=(int)llround(g_echo_hyp[h].delay_ms*sr/1000.0);best_echo_at(a,n,onsetA,templ,center,radius,&lagsA[h],&scoresA[h]);best_echo_at(b,n,onsetB,templ,center,radius,&lagsB[h],&scoresB[h]);double sc=scoresA[h]>scoresB[h]?scoresA[h]:scoresB[h];if(sc>bestScore){bestScore=sc;bestName=g_echo_hyp[h].name;bestDelay=1000.0*(scoresA[h]>=scoresB[h]?lagsA[h]:lagsB[h])/sr;}}
    const char*echoMatch=bestScore>=0.70?"STRONG":"WEAK_OR_UNMODELED";
    const char*pattern="UNRESOLVED_PATTERN";
    if(bestScore>=0.70){
      if(strcmp(region,"FD_SIDE_CANDIDATE")==0 && (scoresB[3]>=0.70 || scoresB[6]>=0.70)) pattern="FD_STAIRWELL_PATTERN";
      else if(strcmp(region,"FC_SIDE_CANDIDATE")==0 && scoresA[1]>=0.70) pattern="FC_ROAD_SIDE_PATTERN";
      else pattern="MODELED_ROOM_PATTERN";
    }
    fprintf(out,"%zu\t%zu\t%.9f\t%.9f\t%s\t%s\t%.9g\t%.9g\t%.9g\t%.9g\t%.9g\t%d\t%.9f\t%.9g\t%s\t%.9f\t%.9g\t%s\t%s",emitted+1,t,1000.0*t/sr,start_serial*1000.0+1000.0*t/sr,ev[e].leader?"FD":"FC",region,peakA,peakB,ev[e].base_a,ev[e].base_b,ev[e].ratio,fd_minus_fc,1000.0*fd_minus_fc/sr,cross,bestName,bestDelay,bestScore,echoMatch,pattern);
    for(size_t h=0;h<7;++h) fprintf(out,"\t%.9g\t%.9g",scoresA[h],scoresB[h]);
    fputc('\n',out);
    ++emitted;
  }
  if(ferror(out)){fclose(out);free(ev);free(a);free(b);seterr2("cannot write loud echo TSV",out_path);return -1;}
  fclose(out);free(ev);free(a);free(b);return 0;
}


/* dev12 loud-event echo survey v2.
 *
 * v1 is retained byte-for-source compatible for reproducibility.  v2 repairs
 * amplitude-scale bias by admitting candidates independently on FC and FD
 * against each feed's own preceding baseline.  Event clustering is still
 * bounded by the refractory interval, but the winning trigger is selected by
 * peak-to-own-baseline ratio rather than absolute amplitude.
 *
 * The search remains diagnostic: every family retains its measured lag,
 * correlation score and search-boundary flag on both feeds.  A wider search
 * therefore exposes ambiguity instead of pretending that the nominal family
 * centre is an identity label.
 */
typedef struct {
  size_t sample;
  double peak;
  double base_a;
  double base_b;
  double ratio;
  int trigger_feed; /* 0 = FC, 1 = FD */
} loud_candidate_v2_t;

static int append_candidate_v2(loud_candidate_v2_t**v,size_t*n,size_t*cap,loud_candidate_v2_t c){
  if(*n==*cap){size_t nc=*cap?(*cap*2):64;loud_candidate_v2_t*t=(loud_candidate_v2_t*)realloc(*v,nc*sizeof(**v));if(!t){seterr("allocation failed");return 0;}*v=t;*cap=nc;}
  (*v)[(*n)++]=c;return 1;
}
static double baseline_before(const float*x,size_t n,long onset,size_t guard,size_t span){
  if(onset<=0)return 0;
  size_t t=(size_t)onset;
  if(t>n)t=n;
  if(t<=guard)return 0;
  size_t end=t-guard,start=end>span?end-span:0;
  return rms_range(x,n,start,end);
}
static void consider_pair(double score,const char*feed,const char*name,int lag,uint32_t sr,int boundary,
                          double*best,double*second,const char**best_feed,const char**best_name,
                          double*best_delay,int*best_boundary){
  if(score>*best){*second=*best;*best=score;*best_feed=feed;*best_name=name;*best_delay=1000.0*lag/sr;*best_boundary=boundary;}
  else if(score>*second){*second=score;}
}

int32_t av9_spatial_loud_echo_scan_v2_tsv(const char*a_path,const char*b_path,const char*out_path,uint32_t sr,double min_abs_peak,double min_ratio,uint32_t refractory_ms,uint32_t template_ms,uint32_t radius_ms,double start_serial,double strong_score){
  g_error[0]='\0';
  if(!a_path||!b_path||!out_path||sr<1000||!isfinite(min_abs_peak)||min_abs_peak<0||!isfinite(min_ratio)||min_ratio<=1||refractory_ms<80||template_ms<2||template_ms>12||radius_ms<1||radius_ms>8||!isfinite(start_serial)||start_serial<0||!isfinite(strong_score)||strong_score<=0||strong_score>1){seterr("invalid loud echo v2 scan arguments");return -1;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a)return -1;float*b=read_f32(b_path,&nb);if(!b){free(a);return -1;}if(na!=nb){free(a);free(b);seterr("paired f32 sample counts differ");return -1;}
  size_t n=na,frame=sr/200;if(frame<8)frame=8; /* 5 ms */
  size_t baseline_guard=(size_t)((uint64_t)sr*50/1000),baseline_span=sr;
  size_t refractory=(size_t)((uint64_t)sr*refractory_ms/1000),templ=(size_t)((uint64_t)sr*template_ms/1000);if(templ<8)templ=8;
  int radius=(int)((uint64_t)sr*radius_ms/1000);if(radius<1)radius=1;
  loud_candidate_v2_t*raw=NULL;size_t rn=0,rcap=0;
  for(size_t base=0;base<n;base+=frame){
    size_t end=base+frame;if(end>n)end=n;double pA=0,pB=0;size_t psA=base,psB=base;
    for(size_t i=base;i<end;++i){double pa=fabs((double)a[i]),pb=fabs((double)b[i]);if(pa>pA){pA=pa;psA=i;}if(pb>pB){pB=pb;psB=i;}}
    loud_candidate_v2_t ca={0},cb={0};int va=0,vb=0;
    if(pA>=min_abs_peak&&psA>baseline_guard+templ){size_t bb=psA-baseline_guard,ba=bb>baseline_span?bb-baseline_span:0;double rA=rms_range(a,n,ba,bb),rB=rms_range(b,n,ba,bb),ratio=pA/(rA+1e-12);if(ratio>=min_ratio){ca=(loud_candidate_v2_t){psA,pA,rA,rB,ratio,0};va=1;}}
    if(pB>=min_abs_peak&&psB>baseline_guard+templ){size_t bb=psB-baseline_guard,ba=bb>baseline_span?bb-baseline_span:0;double rA=rms_range(a,n,ba,bb),rB=rms_range(b,n,ba,bb),ratio=pB/(rB+1e-12);if(ratio>=min_ratio){cb=(loud_candidate_v2_t){psB,pB,rA,rB,ratio,1};vb=1;}}
    if(va&&vb){if(ca.sample<=cb.sample){if(!append_candidate_v2(&raw,&rn,&rcap,ca)||!append_candidate_v2(&raw,&rn,&rcap,cb)){free(raw);free(a);free(b);return -1;}}else{if(!append_candidate_v2(&raw,&rn,&rcap,cb)||!append_candidate_v2(&raw,&rn,&rcap,ca)){free(raw);free(a);free(b);return -1;}}}
    else if(va){if(!append_candidate_v2(&raw,&rn,&rcap,ca)){free(raw);free(a);free(b);return -1;}}
    else if(vb){if(!append_candidate_v2(&raw,&rn,&rcap,cb)){free(raw);free(a);free(b);return -1;}}
  }
  loud_candidate_v2_t*ev=NULL;size_t en=0,ecap=0;
  for(size_t i=0;i<rn;){size_t cluster_start=raw[i].sample,j=i+1; loud_candidate_v2_t winner=raw[i];
    while(j<rn&&raw[j].sample-cluster_start<refractory){if(raw[j].ratio>winner.ratio)winner=raw[j];++j;}
    if(!append_candidate_v2(&ev,&en,&ecap,winner)){free(raw);free(ev);free(a);free(b);return -1;}i=j;
  }
  free(raw);
  FILE*out=fopen(out_path,"w");if(!out){free(ev);free(a);free(b);seterr2("cannot create loud echo v2 TSV",out_path);return -1;}
  fprintf(out,"event_index\tlocal_sample\tlocal_ms\tabsolute_serial_ms\ttrigger_feed\tleader\tregion_hint\tpeak_fc\tpeak_fd\tbaseline_fc\tbaseline_fd\tpeak_to_baseline_fc\tpeak_to_baseline_fd\ttrigger_peak_to_baseline\tfd_minus_fc_samples\tfd_minus_fc_ms\tcross_score\tbest_echo_feed\tbest_echo_family\tbest_echo_delay_ms\tbest_echo_score\tsecond_echo_score\tbest_second_margin\tstrong_family_count\tstrong_feed_hypothesis_count\tboundary_hit_count\tbest_echo_boundary\tsearch_radius_ms\tstrong_score\techo_match\tambiguity_hint\tpattern_hint");
  for(size_t h=0;h<sizeof(g_echo_hyp)/sizeof(g_echo_hyp[0]);++h)fprintf(out,"\tfc_%s_lag_samples\tfc_%s_lag_ms\tfc_%s_score\tfc_%s_boundary\tfd_%s_lag_samples\tfd_%s_lag_ms\tfd_%s_score\tfd_%s_boundary",g_echo_hyp[h].name,g_echo_hyp[h].name,g_echo_hyp[h].name,g_echo_hyp[h].name,g_echo_hyp[h].name,g_echo_hyp[h].name,g_echo_hyp[h].name,g_echo_hyp[h].name);
  fputc('\n',out);
  size_t emitted=0;
  for(size_t e=0;e<en;++e){
    size_t t=ev[e].sample;long pre=(long)(templ/4);if(t<(size_t)pre||t+sr/10+templ>=n)continue;
    const float*trigger=ev[e].trigger_feed?b:a;const float*other=ev[e].trigger_feed?a:b;
    int cross_radius=(int)((uint64_t)sr*35/1000),bestOther=0;double cross=-1;long tt=(long)t-pre;
    for(int lag=-cross_radius;lag<=cross_radius;++lag){double sc=segment_cross_corr_abs(trigger,n,tt,other,n,tt+lag,templ);if(sc>cross){cross=sc;bestOther=lag;}}
    int fd_minus_fc=ev[e].trigger_feed? -bestOther:bestOther;
    long onsetA=ev[e].trigger_feed?((long)t+bestOther):(long)t;
    long onsetB=ev[e].trigger_feed?(long)t:((long)t+bestOther);
    size_t pr=sr/200;double peakA=(onsetA>=0&&onsetA<(long)n)?peak_range(a,n,(size_t)onsetA,pr):0,peakB=(onsetB>=0&&onsetB<(long)n)?peak_range(b,n,(size_t)onsetB,pr):0;
    double baseA=baseline_before(a,n,onsetA,baseline_guard,baseline_span),baseB=baseline_before(b,n,onsetB,baseline_guard,baseline_span);
    double ratioA=peakA/(baseA+1e-12),ratioB=peakB/(baseB+1e-12);
    const char*leader="UNRESOLVED";if(cross>=strong_score){if(fd_minus_fc>0)leader="FC";else if(fd_minus_fc<0)leader="FD";else leader="TIE";}
    const char*region="UNCONSTRAINED";if(cross>=strong_score){if(peakA>peakB*1.35)region="FC_SIDE_CANDIDATE";else if(peakB>peakA*1.35)region="FD_SIDE_CANDIDATE";}
    double scoresA[7]={0},scoresB[7]={0};int lagsA[7]={0},lagsB[7]={0},boundA[7]={0},boundB[7]={0};
    double bestScore=-1,secondScore=-1,bestDelay=0;const char*bestName="NONE",*bestFeed="NONE";int bestBoundary=0,strongFamilies=0,strongPairs=0,boundaryHits=0;
    for(size_t h=0;h<7;++h){int center=(int)llround(g_echo_hyp[h].delay_ms*sr/1000.0);best_echo_at(a,n,onsetA,templ,center,radius,&lagsA[h],&scoresA[h]);best_echo_at(b,n,onsetB,templ,center,radius,&lagsB[h],&scoresB[h]);boundA[h]=(lagsA[h]==center-radius||lagsA[h]==center+radius);boundB[h]=(lagsB[h]==center-radius||lagsB[h]==center+radius);boundaryHits+=boundA[h]+boundB[h];if(scoresA[h]>=strong_score)strongPairs++;if(scoresB[h]>=strong_score)strongPairs++;if((scoresA[h]>scoresB[h]?scoresA[h]:scoresB[h])>=strong_score)strongFamilies++;consider_pair(scoresA[h],"FC",g_echo_hyp[h].name,lagsA[h],sr,boundA[h],&bestScore,&secondScore,&bestFeed,&bestName,&bestDelay,&bestBoundary);consider_pair(scoresB[h],"FD",g_echo_hyp[h].name,lagsB[h],sr,boundB[h],&bestScore,&secondScore,&bestFeed,&bestName,&bestDelay,&bestBoundary);}
    if(secondScore<0)secondScore=0;
    double margin=bestScore-secondScore;
    const char*echoMatch=bestScore>=strong_score?"STRONG":"WEAK_OR_UNMODELED";
    const char*ambiguity=bestScore<strong_score?"WEAK":(strongFamilies>1?"MULTI_FAMILY":"SINGLE_FAMILY");
    const char*pattern="UNRESOLVED_PATTERN";
    if(bestScore>=strong_score&&cross>=strong_score){if(strcmp(region,"FD_SIDE_CANDIDATE")==0&&(scoresB[3]>=strong_score||scoresB[6]>=strong_score))pattern="FD_STAIRWELL_PATTERN";else if(strcmp(region,"FC_SIDE_CANDIDATE")==0&&scoresA[1]>=strong_score)pattern="FC_ROAD_SIDE_PATTERN";else pattern="MODELED_ROOM_PATTERN";}
    fprintf(out,"%zu\t%zu\t%.9f\t%.9f\t%s\t%s\t%s\t%.9g\t%.9g\t%.9g\t%.9g\t%.9g\t%.9g\t%.9g\t%d\t%.9f\t%.9g\t%s\t%s\t%.9f\t%.9g\t%.9g\t%.9g\t%d\t%d\t%d\t%d\t%u\t%.9g\t%s\t%s\t%s",emitted+1,t,1000.0*t/sr,start_serial*1000.0+1000.0*t/sr,ev[e].trigger_feed?"FD":"FC",leader,region,peakA,peakB,baseA,baseB,ratioA,ratioB,ev[e].ratio,fd_minus_fc,1000.0*fd_minus_fc/sr,cross,bestFeed,bestName,bestDelay,bestScore,secondScore,margin,strongFamilies,strongPairs,boundaryHits,bestBoundary,radius_ms,strong_score,echoMatch,ambiguity,pattern);
    for(size_t h=0;h<7;++h)fprintf(out,"\t%d\t%.9f\t%.9g\t%d\t%d\t%.9f\t%.9g\t%d",lagsA[h],1000.0*lagsA[h]/sr,scoresA[h],boundA[h],lagsB[h],1000.0*lagsB[h]/sr,scoresB[h],boundB[h]);
    fputc('\n',out);++emitted;
  }
  if(ferror(out)){fclose(out);free(ev);free(a);free(b);seterr2("cannot write loud echo v2 TSV",out_path);return -1;}
  fclose(out);free(ev);free(a);free(b);return 0;
}

/* dev14 loud-event echo survey v3.
 *
 * V2 remains unchanged.  V3 appends calibration evidence that the first real
 * overnight V2 campaign showed we need:
 *   - whether the bounded +/-35 ms cross-feed search ended on its boundary;
 *   - local feed-nonzero and baseline-coverage evidence; and
 *   - four prior-free same-feed recurrence peaks in a bounded 6..80 ms
 *     matched-filter search.  These global peaks do not use g_echo_hyp and
 *     therefore cannot inherit a named room-family centre by construction.
 */
static double baseline_coverage_ms(long onset,size_t guard,size_t span,uint32_t sr){
  if(onset<=0||sr==0)return 0;
  size_t t=(size_t)onset;
  if(t<=guard)return 0;
  size_t available=t-guard;
  if(available>span)available=span;
  return 1000.0*available/sr;
}
static void global_echo_peaks(const float*x,size_t n,long onset,size_t templ,int minlag,int maxlag,int separation,
                              int out_lag[4],double out_score[4],int*complete){
  for(int k=0;k<4;++k){out_lag[k]=0;out_score[k]=0;}
  *complete=0;
  if(!x||n==0||onset<0||templ<8||minlag<1||maxlag<minlag||separation<1)return;
  long pre=(long)(templ/4),t0=onset-pre;
  if(t0<0)return;
  long max_allowed=(long)n-t0-(long)templ;
  if(max_allowed<minlag)return;
  int hi=maxlag;
  if((long)hi>max_allowed)hi=(int)max_allowed;
  if(hi<minlag)return;
  if(hi==maxlag)*complete=1;
  size_t count=(size_t)(hi-minlag+1);
  double*scores=(double*)malloc(count*sizeof(double));
  unsigned char*supp=(unsigned char*)calloc(count,sizeof(unsigned char));
  if(!scores||!supp){free(scores);free(supp);return;}
  for(size_t i=0;i<count;++i){int lag=minlag+(int)i;scores[i]=segment_corr_abs(x,n,t0,t0+lag,templ);}
  for(int k=0;k<4;++k){
    double best=-1;int bestlag=0;size_t besti=0;int found=0;
    for(size_t i=0;i<count;++i){
      if(supp[i])continue;
      double sc=scores[i];int lag=minlag+(int)i;
      if(!found||sc>best+1e-12||(fabs(sc-best)<=1e-12&&lag<bestlag)){best=sc;bestlag=lag;besti=i;found=1;}
    }
    if(!found)break;
    out_lag[k]=bestlag;out_score[k]=best<0?0:best;
    int lo=bestlag-separation,up=bestlag+separation;
    if(lo<minlag)lo=minlag;
    if(up>hi)up=hi;
    for(int lag=lo;lag<=up;++lag)supp[(size_t)(lag-minlag)]=1;
    (void)besti;
  }
  free(scores);free(supp);
}

int32_t av9_spatial_loud_echo_scan_v3_tsv(const char*a_path,const char*b_path,const char*out_path,uint32_t sr,double min_abs_peak,double min_ratio,uint32_t refractory_ms,uint32_t template_ms,uint32_t radius_ms,double start_serial,double strong_score,uint32_t global_min_ms,uint32_t global_max_ms,uint32_t global_separation_ms){
  g_error[0]='\0';
  if(!a_path||!b_path||!out_path||sr<1000||global_min_ms<2||global_max_ms<=global_min_ms||global_max_ms>120||global_separation_ms<1||global_separation_ms>20){seterr("invalid loud echo v3 scan arguments");return -1;}
  size_t tmpn=strlen(out_path)+16;char*tmp=(char*)malloc(tmpn);if(!tmp){seterr("allocation failed");return -1;}
  snprintf(tmp,tmpn,"%s.v2tmp",out_path);
  int32_t rc=av9_spatial_loud_echo_scan_v2_tsv(a_path,b_path,tmp,sr,min_abs_peak,min_ratio,refractory_ms,template_ms,radius_ms,start_serial,strong_score);
  if(rc!=0){free(tmp);return rc;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a){remove(tmp);free(tmp);return -1;}float*b=read_f32(b_path,&nb);if(!b){free(a);remove(tmp);free(tmp);return -1;}if(na!=nb){free(a);free(b);remove(tmp);free(tmp);seterr("paired f32 sample counts differ");return -1;}
  FILE*in=fopen(tmp,"r");if(!in){seterr2("cannot reopen loud echo v2 TSV",tmp);free(a);free(b);remove(tmp);free(tmp);return -1;}
  FILE*out=fopen(out_path,"w");if(!out){fclose(in);free(a);free(b);remove(tmp);free(tmp);seterr2("cannot create loud echo v3 TSV",out_path);return -1;}
  char*line=NULL;size_t cap=0;ssize_t got=getline(&line,&cap,in);if(got<0){free(line);fclose(in);fclose(out);free(a);free(b);remove(tmp);free(tmp);seterr("empty loud echo v2 TSV");return -1;}
  while(got>0&&(line[got-1]=='\n'||line[got-1]=='\r'))line[--got]='\0';
  fprintf(out,"%s\tcross_boundary\tcross_search_radius_ms\tfc_local_nonzero\tfd_local_nonzero\tfc_baseline_coverage_ms\tfd_baseline_coverage_ms\tfc_global_search_complete\tfd_global_search_complete\tglobal_min_ms\tglobal_max_ms\tglobal_separation_ms",line);
  for(int k=1;k<=4;++k)fprintf(out,"\tfc_global_%d_lag_samples\tfc_global_%d_lag_ms\tfc_global_%d_score\tfd_global_%d_lag_samples\tfd_global_%d_lag_ms\tfd_global_%d_score",k,k,k,k,k,k);
  fputc('\n',out);
  size_t templ=(size_t)((uint64_t)sr*template_ms/1000);if(templ<8)templ=8;
  size_t guard=(size_t)((uint64_t)sr*50/1000),span=sr;
  int cross_radius=(int)((uint64_t)sr*35/1000);
  int gmin=(int)((uint64_t)sr*global_min_ms/1000),gmax=(int)((uint64_t)sr*global_max_ms/1000),gsep=(int)((uint64_t)sr*global_separation_ms/1000);if(gmin<1)gmin=1;if(gsep<1)gsep=1;
  while((got=getline(&line,&cap,in))>=0){
    while(got>0&&(line[got-1]=='\n'||line[got-1]=='\r'))line[--got]='\0';
    if(got==0)continue;
    char*copy=strdup(line);if(!copy){seterr("allocation failed");rc=-1;break;}
    char*fields[128];size_t nf=0;char*save=NULL;char*tok=strtok_r(copy,"\t",&save);while(tok&&nf<128){fields[nf++]=tok;tok=strtok_r(NULL,"\t",&save);}if(nf<32){free(copy);seterr("malformed loud echo v2 row during v3 append");rc=-1;break;}
    size_t t=(size_t)strtoull(fields[1],NULL,10);int trigger_fd=strcmp(fields[4],"FD")==0;int fd_minus_fc=(int)strtol(fields[14],NULL,10);int best_other=trigger_fd?-fd_minus_fc:fd_minus_fc;
    long onsetA=trigger_fd?((long)t+best_other):(long)t;long onsetB=trigger_fd?(long)t:((long)t+best_other);
    double peakA=strtod(fields[7],NULL),peakB=strtod(fields[8],NULL),baseA=strtod(fields[9],NULL),baseB=strtod(fields[10],NULL);
    int cross_boundary=abs(best_other)==cross_radius;int nonzeroA=(fabs(peakA)>1e-15||fabs(baseA)>1e-15),nonzeroB=(fabs(peakB)>1e-15||fabs(baseB)>1e-15);
    double covA=baseline_coverage_ms(onsetA,guard,span,sr),covB=baseline_coverage_ms(onsetB,guard,span,sr);
    int lagA[4],lagB[4],completeA=0,completeB=0;double scoreA[4],scoreB[4];
    global_echo_peaks(a,na,onsetA,templ,gmin,gmax,gsep,lagA,scoreA,&completeA);global_echo_peaks(b,nb,onsetB,templ,gmin,gmax,gsep,lagB,scoreB,&completeB);
    fprintf(out,"%s\t%d\t35\t%d\t%d\t%.9f\t%.9f\t%d\t%d\t%u\t%u\t%u",line,cross_boundary,nonzeroA,nonzeroB,covA,covB,completeA,completeB,global_min_ms,global_max_ms,global_separation_ms);
    for(int k=0;k<4;++k)fprintf(out,"\t%d\t%.9f\t%.9g\t%d\t%.9f\t%.9g",lagA[k],1000.0*lagA[k]/sr,scoreA[k],lagB[k],1000.0*lagB[k]/sr,scoreB[k]);
    fputc('\n',out);free(copy);
  }
  free(line);fclose(in);if(ferror(out)&&rc==0){seterr2("cannot write loud echo v3 TSV",out_path);rc=-1;}fclose(out);free(a);free(b);remove(tmp);free(tmp);return rc;
}

int32_t av9_spatial_render_mix_f32(const char*a_path,const char*b_path,const char*out_path,int32_t lag_b_samples,double weight_a,double weight_b){
  g_error[0]='\0';if(!a_path||!b_path||!out_path||!isfinite(weight_a)||!isfinite(weight_b)){seterr("invalid render arguments");return -1;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a)return -1;float*b=read_f32(b_path,&nb);if(!b){free(a);return -1;}if(na!=nb){free(a);free(b);seterr("paired f32 sample counts differ");return -1;}
  FILE*f=fopen(out_path,"wb");if(!f){free(a);free(b);seterr2("cannot create render f32",out_path);return -1;}float*buf=(float*)malloc(16384*sizeof(float));if(!buf){fclose(f);free(a);free(b);seterr("allocation failed");return -1;}
  for(size_t pos=0;pos<na;){size_t chunk=na-pos;if(chunk>16384)chunk=16384;for(size_t k=0;k<chunk;++k){long i=(long)(pos+k),j=i+lag_b_samples;double bv=(j>=0&&j<(long)nb)?b[j]:0;buf[k]=(float)(weight_a*a[i]+weight_b*bv);}if(fwrite(buf,sizeof(float),chunk,f)!=chunk){free(buf);fclose(f);free(a);free(b);seterr2("cannot write render f32",out_path);return -1;}pos+=chunk;}
  free(buf);fclose(f);free(a);free(b);return 0;
}


typedef struct {size_t start,end;int lag;double wa,wb,gain;} plan_row_t;
static int read_plan(const char*path,plan_row_t**out,size_t*outn){
  FILE*f=fopen(path,"r");if(!f){seterr2("cannot open reconstruction plan",path);return 0;}
  char line[2048];if(!fgets(line,sizeof(line),f)){fclose(f);seterr("empty reconstruction plan");return 0;}
  plan_row_t*rows=NULL;size_t n=0,cap=0;
  while(fgets(line,sizeof(line),f)){
    if(line[0]=='\0'||line[0]=='\n'||line[0]=='#')continue;
    unsigned long long st=0,en=0;int lag=0;double wa=0,wb=0,g=0;
    if(sscanf(line,"%llu\t%llu\t%d\t%lf\t%lf\t%lf",&st,&en,&lag,&wa,&wb,&g)!=6){free(rows);fclose(f);seterr("malformed reconstruction plan row");return 0;}
    if(en<=st||wa<0||wb<0||wa+wb<=0||!isfinite(g)||g<=0){free(rows);fclose(f);seterr("invalid reconstruction plan row");return 0;}
    if(n&&st!=rows[n-1].end){free(rows);fclose(f);seterr("reconstruction plan must be contiguous");return 0;}
    if(n==cap){size_t nc=cap?cap*2:16;plan_row_t*t=realloc(rows,nc*sizeof(*rows));if(!t){free(rows);fclose(f);seterr("allocation failed");return 0;}rows=t;cap=nc;}
    rows[n++]=(plan_row_t){(size_t)st,(size_t)en,lag,wa,wb,g};
  }
  fclose(f);if(!n){free(rows);seterr("reconstruction plan has no rows");return 0;}*out=rows;*outn=n;return 1;
}

int32_t av9_spatial_render_plan_f32(const char*a_path,const char*b_path,const char*plan_path,const char*out_path,uint32_t fade_samples){
  g_error[0]='\0';if(!a_path||!b_path||!plan_path||!out_path){seterr("invalid plan render arguments");return -1;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a)return -1;float*b=read_f32(b_path,&nb);if(!b){free(a);return -1;}if(na!=nb){free(a);free(b);seterr("paired f32 sample counts differ");return -1;}
  plan_row_t*r=NULL;size_t nr=0;if(!read_plan(plan_path,&r,&nr)){free(a);free(b);return -1;}
  if(r[0].start!=0||r[nr-1].end!=na){free(r);free(a);free(b);seterr("reconstruction plan must cover complete input");return -1;}
  FILE*f=fopen(out_path,"wb");if(!f){free(r);free(a);free(b);seterr2("cannot create plan render f32",out_path);return -1;}
  float*buf=malloc(16384*sizeof(float));if(!buf){fclose(f);free(r);free(a);free(b);seterr("allocation failed");return -1;}
  size_t ri=0;
  for(size_t pos=0;pos<na;){
    while(ri+1<nr&&pos>=r[ri].end)ri++;
    size_t chunk=na-pos;if(chunk>16384)chunk=16384;if(pos+chunk>r[ri].end)chunk=r[ri].end-pos;
    for(size_t k=0;k<chunk;k++){
      size_t i=pos+k;plan_row_t cur=r[ri],prev=ri?r[ri-1]:cur;double alpha=1.0;
      if(ri&&fade_samples>0&&i<cur.start+fade_samples){alpha=(double)(i-cur.start)/(double)fade_samples;if(alpha<0)alpha=0;if(alpha>1)alpha=1;}
      long j0=(long)i+prev.lag,j1=(long)i+cur.lag;double bp=(j0>=0&&j0<(long)nb)?b[j0]:0,bc=(j1>=0&&j1<(long)nb)?b[j1]:0;
      double oldv=(prev.wa*a[i]+prev.wb*bp)*prev.gain,newv=(cur.wa*a[i]+cur.wb*bc)*cur.gain;
      buf[k]=(float)((1-alpha)*oldv+alpha*newv);
    }
    if(fwrite(buf,sizeof(float),chunk,f)!=chunk){free(buf);fclose(f);free(r);free(a);free(b);seterr2("cannot write plan render f32",out_path);return -1;}pos+=chunk;
  }
  free(buf);fclose(f);free(r);free(a);free(b);return 0;
}

/* dev5 source-family time-frequency mask renderer.  The mask is applied to an
 * already spatially reconstructed f32 signal.  Voice/uncertain protection is
 * resolved before attenuation: a protected overlapping box prevents a coarse
 * interference family from deleting the same time-frequency evidence. */
#ifndef M_PI
#define M_PI 3.141592653589793238462643383279502884
#endif

typedef struct {size_t start,end;double lo,hi,gain,confidence;int protect;} tf_mask_row_t;
typedef struct {double re,im;} av9_cpx_t;

static int read_tf_mask_plan(const char*path,tf_mask_row_t**out,size_t*outn){
  FILE*f=fopen(path,"r");if(!f){seterr2("cannot open TF mask plan",path);return 0;}
  char line[4096];if(!fgets(line,sizeof(line),f)){fclose(f);seterr("empty TF mask plan");return 0;}
  tf_mask_row_t*rows=NULL;size_t n=0,cap=0;
  while(fgets(line,sizeof(line),f)){
    if(line[0]=='\0'||line[0]=='\n'||line[0]=='#')continue;
    unsigned long long st=0,en=0;double lo=0,hi=0,g=0,conf=0;int protect=0;
    if(sscanf(line,"%llu\t%llu\t%lf\t%lf\t%lf\t%d\t%lf",&st,&en,&lo,&hi,&g,&protect,&conf)!=7){free(rows);fclose(f);seterr("malformed TF mask plan row");return 0;}
    if(en<=st||lo<0||hi<=lo||!isfinite(g)||g<=0||!isfinite(conf)||conf<0||conf>1){free(rows);fclose(f);seterr("invalid TF mask plan row");return 0;}
    if(n==cap){size_t nc=cap?cap*2:64;tf_mask_row_t*t=realloc(rows,nc*sizeof(*rows));if(!t){free(rows);fclose(f);seterr("allocation failed");return 0;}rows=t;cap=nc;}
    rows[n++]=(tf_mask_row_t){(size_t)st,(size_t)en,lo,hi,g,conf,protect?1:0};
  }
  fclose(f);*out=rows;*outn=n;return 1;
}

static int is_pow2_u32(uint32_t x){return x>=2 && (x&(x-1u))==0;}
static void av9_fft(av9_cpx_t*a,size_t n,int inverse){
  for(size_t i=1,j=0;i<n;i++){
    size_t bit=n>>1;for(;j&bit;bit>>=1)j^=bit;j^=bit;
    if(i<j){av9_cpx_t t=a[i];a[i]=a[j];a[j]=t;}
  }
  for(size_t len=2;len<=n;len<<=1){
    double ang=(inverse?2.0:-2.0)*M_PI/(double)len;double wlr=cos(ang),wli=sin(ang);
    for(size_t i=0;i<n;i+=len){double wr=1,wi=0;for(size_t j=0;j<len/2;j++){
      av9_cpx_t u=a[i+j],v=a[i+j+len/2];double vr=v.re*wr-v.im*wi,vi=v.re*wi+v.im*wr;
      a[i+j].re=u.re+vr;a[i+j].im=u.im+vi;a[i+j+len/2].re=u.re-vr;a[i+j+len/2].im=u.im-vi;
      double nwr=wr*wlr-wi*wli;wi=wr*wli+wi*wlr;wr=nwr;
    }}
  }
  if(inverse){double inv=1.0/(double)n;for(size_t i=0;i<n;i++){a[i].re*=inv;a[i].im*=inv;}}
}

static double tf_edge_weight(const tf_mask_row_t*r,double hz){
  if(hz<r->lo||hz>r->hi)return 0;
  double width=r->hi-r->lo,taper=60.0;if(taper>width*0.25)taper=width*0.25;if(taper<1)return 1;
  double x=1;if(hz<r->lo+taper)x=(hz-r->lo)/taper;else if(hz>r->hi-taper)x=(r->hi-hz)/taper;
  if(x<0)x=0;
  if(x>1)x=1;
  return 0.5-0.5*cos(M_PI*x);
}

static double tf_mask_gain(const tf_mask_row_t*rows,size_t nr,size_t sample,double hz){
  double pw=0,pg=0,aw=0,ag=0;
  for(size_t i=0;i<nr;i++){
    const tf_mask_row_t*r=&rows[i];if(sample<r->start||sample>=r->end)continue;
    double ew=tf_edge_weight(r,hz);if(ew<=0)continue;double w=r->confidence*ew;if(w<=0)continue;
    if(r->protect){pw+=w;pg+=w*r->gain;}else{aw+=w;ag+=w*r->gain;}
  }
  if(pw>0){double g=pg/pw;if(g<1)g=1;if(g>1.30)g=1.30;return g;}
  if(aw>0){double g=ag/aw;if(g<0.20)g=0.20;if(g>1.30)g=1.30;return g;}
  return 1.0;
}

int32_t av9_spatial_render_mask_f32(const char*input_path,const char*mask_path,const char*out_path,uint32_t sr,uint32_t fft_size,uint32_t hop_samples){
  g_error[0]='\0';if(!input_path||!mask_path||!out_path||sr<1000||!is_pow2_u32(fft_size)||fft_size<128||fft_size>2048||hop_samples<1||hop_samples>fft_size){seterr("invalid TF mask render arguments");return -1;}
  size_t n=0;float*x=read_f32(input_path,&n);if(!x)return -1;
  tf_mask_row_t*rows=NULL;size_t nr=0;if(!read_tf_mask_plan(mask_path,&rows,&nr)){free(x);return -1;}
  double*acc=calloc(n,sizeof(double)),*norm=calloc(n,sizeof(double)),*win=malloc((size_t)fft_size*sizeof(double));av9_cpx_t*buf=malloc((size_t)fft_size*sizeof(av9_cpx_t));
  if(!acc||!norm||!win||!buf){free(buf);free(win);free(norm);free(acc);free(rows);free(x);seterr("allocation failed");return -1;}
  for(uint32_t k=0;k<fft_size;k++){double h=0.5-0.5*cos(2.0*M_PI*(double)k/(double)(fft_size-1));if(h<0)h=0;win[k]=sqrt(h);}
  long lead=(long)fft_size-(long)hop_samples;
  for(long start=-lead;start<(long)n;start+=(long)hop_samples){
    for(uint32_t k=0;k<fft_size;k++){long idx=start+(long)k;double v=(idx>=0&&idx<(long)n)?x[idx]:0.0;buf[k].re=v*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);long center=start+(long)fft_size/2;if(center<0)center=0;if(center>=(long)n)center=(long)n-1;
    for(uint32_t k=0;k<=fft_size/2;k++){
      double hz=(double)sr*(double)k/(double)fft_size,g=tf_mask_gain(rows,nr,(size_t)center,hz);buf[k].re*=g;buf[k].im*=g;
      if(k>0&&k<fft_size/2){size_t j=fft_size-k;buf[j].re*=g;buf[j].im*=g;}
    }
    av9_fft(buf,fft_size,1);
    for(uint32_t k=0;k<fft_size;k++){long idx=start+(long)k;if(idx<0||idx>=(long)n)continue;double w=win[k];acc[idx]+=buf[k].re*w;norm[idx]+=w*w;}
  }
  FILE*f=fopen(out_path,"wb");if(!f){free(buf);free(win);free(norm);free(acc);free(rows);free(x);seterr2("cannot create TF mask output",out_path);return -1;}
  float*out=malloc(16384*sizeof(float));if(!out){fclose(f);free(buf);free(win);free(norm);free(acc);free(rows);free(x);seterr("allocation failed");return -1;}
  for(size_t pos=0;pos<n;){size_t count=n-pos;if(count>16384)count=16384;for(size_t k=0;k<count;k++){size_t i=pos+k;double y=norm[i]>1e-12?acc[i]/norm[i]:x[i];out[k]=(float)y;}if(fwrite(out,sizeof(float),count,f)!=count){free(out);fclose(f);free(buf);free(win);free(norm);free(acc);free(rows);free(x);seterr2("cannot write TF mask output",out_path);return -1;}pos+=count;}
  free(out);fclose(f);free(buf);free(win);free(norm);free(acc);free(rows);free(x);return 0;
}


/* dev7 source-conditioned calibration selector.  Unlike the quality mask,
 * this is an evidence isolator: bins outside the supplied source-family boxes
 * are zero, and selected bins are admitted with the row weight.  It must not
 * be used as final listening reconstruction authority. */
typedef struct {size_t start,end;double lo,hi,weight;} select_mask_row_t;
static int read_select_mask(const char*path,select_mask_row_t**out,size_t*outn){
  FILE*f=fopen(path,"r");if(!f){seterr2("cannot open selection mask",path);return 0;}
  char line[4096];if(!fgets(line,sizeof(line),f)){fclose(f);seterr("empty selection mask");return 0;}
  select_mask_row_t*rows=NULL;size_t n=0,cap=0;
  while(fgets(line,sizeof(line),f)){
    if(line[0]=='\0'||line[0]=='\n'||line[0]=='#')continue;
    unsigned long long st=0,en=0;double lo=0,hi=0,w=0;
    if(sscanf(line,"%llu\t%llu\t%lf\t%lf\t%lf",&st,&en,&lo,&hi,&w)!=5){free(rows);fclose(f);seterr("malformed selection mask row");return 0;}
    if(en<=st||lo<0||hi<=lo||!isfinite(w)||w<=0||w>1){free(rows);fclose(f);seterr("invalid selection mask row");return 0;}
    if(n==cap){size_t nc=cap?cap*2:64;select_mask_row_t*t=realloc(rows,nc*sizeof(*rows));if(!t){free(rows);fclose(f);seterr("allocation failed");return 0;}rows=t;cap=nc;}
    rows[n++]=(select_mask_row_t){(size_t)st,(size_t)en,lo,hi,w};
  }
  fclose(f);if(n==0){free(rows);seterr("selection mask has no rows");return 0;}*out=rows;*outn=n;return 1;
}
static double select_mask_gain(const select_mask_row_t*rows,size_t nr,size_t sample,double hz){
  double best=0;
  for(size_t i=0;i<nr;i++){
    const select_mask_row_t*r=&rows[i];if(sample<r->start||sample>=r->end)continue;
    double ew;
    if(hz<r->lo||hz>r->hi)continue;
    double width=r->hi-r->lo,taper=60.0;if(taper>width*0.25)taper=width*0.25;
    if(taper<1)ew=1;else{double x=1;if(hz<r->lo+taper)x=(hz-r->lo)/taper;else if(hz>r->hi-taper)x=(r->hi-hz)/taper;if(x<0)x=0;if(x>1)x=1;ew=0.5-0.5*cos(M_PI*x);}
    double g=r->weight*ew;if(g>best)best=g;
  }
  return best;
}
int32_t av9_spatial_render_select_f32(const char*input_path,const char*mask_path,const char*out_path,uint32_t sr,uint32_t fft_size,uint32_t hop_samples){
  g_error[0]='\0';if(!input_path||!mask_path||!out_path||sr<1000||!is_pow2_u32(fft_size)||fft_size<128||fft_size>2048||hop_samples<1||hop_samples>fft_size){seterr("invalid selection render arguments");return -1;}
  size_t n=0;float*x=read_f32(input_path,&n);if(!x)return -1;
  select_mask_row_t*rows=NULL;size_t nr=0;if(!read_select_mask(mask_path,&rows,&nr)){free(x);return -1;}
  double*acc=calloc(n,sizeof(double)),*norm=calloc(n,sizeof(double)),*win=malloc((size_t)fft_size*sizeof(double));av9_cpx_t*buf=malloc((size_t)fft_size*sizeof(av9_cpx_t));
  if(!acc||!norm||!win||!buf){free(buf);free(win);free(norm);free(acc);free(rows);free(x);seterr("allocation failed");return -1;}
  for(uint32_t k=0;k<fft_size;k++){double h=0.5-0.5*cos(2.0*M_PI*(double)k/(double)(fft_size-1));if(h<0)h=0;win[k]=sqrt(h);}
  long lead=(long)fft_size-(long)hop_samples;
  for(long start=-lead;start<(long)n;start+=(long)hop_samples){
    for(uint32_t k=0;k<fft_size;k++){long idx=start+(long)k;double v=(idx>=0&&idx<(long)n)?x[idx]:0.0;buf[k].re=v*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);long center=start+(long)fft_size/2;if(center<0)center=0;if(center>=(long)n)center=(long)n-1;
    for(uint32_t k=0;k<=fft_size/2;k++){
      double hz=(double)sr*(double)k/(double)fft_size,g=select_mask_gain(rows,nr,(size_t)center,hz);buf[k].re*=g;buf[k].im*=g;
      if(k>0&&k<fft_size/2){size_t j=fft_size-k;buf[j].re*=g;buf[j].im*=g;}
    }
    av9_fft(buf,fft_size,1);
    for(uint32_t k=0;k<fft_size;k++){long idx=start+(long)k;if(idx<0||idx>=(long)n)continue;double w=win[k];acc[idx]+=buf[k].re*w;norm[idx]+=w*w;}
  }
  FILE*f=fopen(out_path,"wb");if(!f){free(buf);free(win);free(norm);free(acc);free(rows);free(x);seterr2("cannot create selection output",out_path);return -1;}
  float*outbuf=malloc(16384*sizeof(float));if(!outbuf){fclose(f);free(buf);free(win);free(norm);free(acc);free(rows);free(x);seterr("allocation failed");return -1;}
  for(size_t pos=0;pos<n;){size_t count=n-pos;if(count>16384)count=16384;for(size_t k=0;k<count;k++){size_t i=pos+k;outbuf[k]=(float)(norm[i]>1e-12?acc[i]/norm[i]:0.0);}if(fwrite(outbuf,sizeof(float),count,f)!=count){free(outbuf);fclose(f);free(buf);free(win);free(norm);free(acc);free(rows);free(x);seterr2("cannot write selection output",out_path);return -1;}pos+=count;}
  free(outbuf);fclose(f);free(buf);free(win);free(norm);free(acc);free(rows);free(x);return 0;
}
