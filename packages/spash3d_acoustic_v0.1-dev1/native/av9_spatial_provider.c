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

/* ---- SPASH 3D additions (proposed patch to Audio V9 dev16) ----
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.
 * Two measurement primitives the provider lacked:
 *  av9_spatial_envelope_f32: block envelope (mean |x| per bin), optionally log (dB) and
 *    detrended by a centred moving average, so slow level drift does not dominate correlation.
 *  av9_spatial_xcorr_tsv: the full normalised correlation curve over a lag range, using the
 *    provider's own corr_stride (positive lag => B later than A), so callers can read the
 *    correlation at any physically predicted lag rather than only at the global best lag. */
int32_t av9_spatial_envelope_f32(const char*in_path,const char*out_path,uint32_t bin_samples,int32_t log_db,uint32_t detrend_bins){
  g_error[0]='\0';if(!in_path||!out_path||bin_samples<1){seterr("invalid envelope arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;size_t m=n/bin_samples;if(m<1){free(x);seterr("input shorter than one envelope bin");return -1;}
  double*e=(double*)malloc(m*sizeof(double));if(!e){free(x);seterr("allocation failed");return -1;}
  for(size_t k=0;k<m;++k){long double s=0;size_t b=k*bin_samples;for(size_t j=0;j<bin_samples;++j)s+=fabs((double)x[b+j]);double v=(double)(s/bin_samples);e[k]=log_db?20.0*log10(v+1e-9):v;}
  free(x);
  float*o=(float*)malloc(m*sizeof(float));if(!o){free(e);seterr("allocation failed");return -1;}
  if(detrend_bins>1){size_t h=detrend_bins/2;long double run=0;size_t lo=0,hi=0; /* window [lo,hi) */
    for(size_t k=0;k<m;++k){size_t wl=k>h?k-h:0,wh=k+h+1<m?k+h+1:m;while(hi<wh){run+=e[hi];++hi;}while(lo<wl){run-=e[lo];++lo;}o[k]=(float)(e[k]-(double)(run/(hi-lo)));}}
  else for(size_t k=0;k<m;++k)o[k]=(float)e[k];
  free(e);FILE*f=fopen(out_path,"wb");if(!f){free(o);seterr2("cannot create envelope f32",out_path);return -1;}
  if(fwrite(o,sizeof(float),m,f)!=m){fclose(f);free(o);seterr2("cannot write envelope f32",out_path);return -1;}
  fclose(f);free(o);return (int32_t)(m>0x7fffffff?0x7fffffff:m);
}
const char *av9_spatial_xcorr_tsv(const char*a_path,const char*b_path,int32_t min_lag,int32_t max_lag,uint32_t lag_step,uint32_t stride){
  g_error[0]='\0';if(!a_path||!b_path||max_lag<min_lag||lag_step<1||stride<1){seterr("invalid xcorr arguments");return NULL;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a)return NULL;float*b=read_f32(b_path,&nb);if(!b){free(a);return NULL;}
  if(na!=nb){free(a);free(b);seterr("paired f32 sample counts differ");return NULL;}
  size_t rows=(size_t)((max_lag-min_lag)/(int32_t)lag_step)+1,used=0;if(!ensure_text(256+rows*48)){free(a);free(b);return NULL;}g_text[0]='\0';
  if(!appendf(&used,"AUDIO_V9_XCORR/1\tSAMPLES=%zu\tMIN_LAG=%d\tMAX_LAG=%d\tLAG_STEP=%u\tSTRIDE=%u\n",na,min_lag,max_lag,lag_step,stride)){free(a);free(b);return NULL;}
  for(int32_t lag=min_lag;lag<=max_lag;lag+=(int32_t)lag_step){double sc=corr_stride(a,b,na,lag,(int)stride);if(!appendf(&used,"%d\t%.9f\n",lag,sc)){free(a);free(b);return NULL;}}
  free(a);free(b);return g_text;
}
/* av9_spatial_band_blocks_tsv: SPASH spectral fingerprint as a native provider primitive.
 * Same definition as SPASH's reference tool (Hann-windowed frames, power spectrum, mean power in
 * nbands log-spaced bands fmin..fmax, averaged over block_frames frames), so SpashObservation/
 * SpashExampleSearch can run in ooRexx.  Rows: block, start_sample, rms, band powers. */
const char *av9_spatial_band_blocks_tsv(const char*in_path,uint32_t sr,uint32_t frame,uint32_t hop,uint32_t block_frames,uint32_t nbands,double fmin,double fmax){
  g_error[0]='\0';if(!in_path||sr<1000||!is_pow2_u32(frame)||frame<64||frame>4096||hop<1||hop>frame||block_frames<1||nbands<1||nbands>512||!(fmin>0)||!(fmax>fmin)){seterr("invalid band block arguments");return NULL;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return NULL;if(n<frame){free(x);seterr("input shorter than one frame");return NULL;}
  size_t frames=1+(n-frame)/hop,blocks=frames/block_frames;if(blocks<1){free(x);seterr("input shorter than one block");return NULL;}
  av9_cpx_t*buf=malloc(frame*sizeof(av9_cpx_t));double*win=malloc(frame*sizeof(double));double*acc=calloc(nbands,sizeof(double));int*lo=malloc(nbands*sizeof(int)),*hi=malloc(nbands*sizeof(int));
  if(!buf||!win||!acc||!lo||!hi){free(buf);free(win);free(acc);free(lo);free(hi);free(x);seterr("allocation failed");return NULL;}
  for(uint32_t k=0;k<frame;k++)win[k]=0.5-0.5*cos(2.0*M_PI*(double)k/(double)(frame-1));
  for(uint32_t b=0;b<nbands;b++){double e0=fmin*pow(fmax/fmin,(double)b/nbands),e1=fmin*pow(fmax/fmin,(double)(b+1)/nbands);int l=-1,h=-1;
    for(uint32_t k=0;k<=frame/2;k++){double hz=(double)sr*k/frame;if(hz>=e0&&hz<e1){if(l<0)l=(int)k;h=(int)k;}}
    if(l<0){double c=sqrt(e0*e1);int best=0;double bd=1e30;for(uint32_t k=0;k<=frame/2;k++){double d=fabs((double)sr*k/frame-c);if(d<bd){bd=d;best=(int)k;}}l=h=best;}
    lo[b]=l;hi[b]=h;}
  size_t used=0;if(!ensure_text(256+blocks*(32+nbands*20))){free(buf);free(win);free(acc);free(lo);free(hi);free(x);return NULL;}g_text[0]='\0';
  if(!appendf(&used,"AUDIO_V9_BAND_BLOCKS/1\tSAMPLES=%zu\tSR=%u\tFRAME=%u\tHOP=%u\tBLOCK_FRAMES=%u\tBANDS=%u\tFMIN=%.6g\tFMAX=%.6g\tBLOCKS=%zu\n",n,sr,frame,hop,block_frames,nbands,fmin,fmax,blocks)){free(buf);free(win);free(acc);free(lo);free(hi);free(x);return NULL;}
  for(size_t bl=0;bl<blocks;bl++){
    long double rsum=0;
    for(uint32_t b=0;b<nbands;b++)acc[b]=0;
    for(uint32_t fi=0;fi<block_frames;fi++){size_t st=(bl*block_frames+fi)*hop;long double ss=0;
      for(uint32_t k=0;k<frame;k++){double v=x[st+k];ss+=v*v;buf[k].re=v*win[k];buf[k].im=0;}
      rsum+=sqrtl(ss/frame);av9_fft(buf,frame,0);
      for(uint32_t b=0;b<nbands;b++){double s=0;for(int k=lo[b];k<=hi[b];k++)s+=buf[k].re*buf[k].re+buf[k].im*buf[k].im;acc[b]+=s/(hi[b]-lo[b]+1);}}
    if(!appendf(&used,"%zu\t%zu\t%.9g",bl,bl*block_frames*hop,(double)(rsum/block_frames))){free(buf);free(win);free(acc);free(lo);free(hi);free(x);return NULL;}
    for(uint32_t b=0;b<nbands;b++)if(!appendf(&used,"\t%.9g",acc[b]/block_frames)){free(buf);free(win);free(acc);free(lo);free(hi);free(x);return NULL;}
    if(!appendf(&used,"\n")){free(buf);free(win);free(acc);free(lo);free(hi);free(x);return NULL;}
  }
  free(buf);free(win);free(acc);free(lo);free(hi);free(x);return g_text;
}
/* av9_spatial_stationary_suppress_f32: remove what is steady in each frequency bin (klaxon, hum, whine),
 * keep what fluctuates (speech).  STFT (sqrt-Hann, overlap-add as the provider's mask renderers); per bin the
 * stationary power N(k) = given percentile of |X(k,t)|^2 over the whole input; gain = max(floor, 1 - over*N/|X|^2),
 * then speech-band limits lo..hi Hz.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026. */
static int cmp_dbl(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}
int32_t av9_spatial_stationary_suppress_f32(const char*in_path,const char*out_path,uint32_t sr,uint32_t fft_size,uint32_t hop,double percentile,double over,double floor_gain,double lo_hz,double hi_hz){
  g_error[0]='\0';if(!in_path||!out_path||sr<1000||!is_pow2_u32(fft_size)||fft_size<128||fft_size>4096||hop<1||hop>fft_size||!(percentile>=0&&percentile<=100)||!(over>0)||!(floor_gain>=0&&floor_gain<=1)||!(hi_hz>lo_hz)){seterr("invalid stationary suppress arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  long lead=(long)fft_size-(long)hop;size_t frames=0;for(long st=-lead;st<(long)n;st+=(long)hop)frames++;
  size_t nb=fft_size/2+1;double*mag2=malloc(frames*nb*sizeof(double));double*win=malloc(fft_size*sizeof(double));av9_cpx_t*buf=malloc(fft_size*sizeof(av9_cpx_t));
  double*acc=calloc(n,sizeof(double)),*norm=calloc(n,sizeof(double)),*noise=malloc(nb*sizeof(double)),*col=malloc(frames*sizeof(double));
  if(!mag2||!win||!buf||!acc||!norm||!noise||!col){free(mag2);free(win);free(buf);free(acc);free(norm);free(noise);free(col);free(x);seterr("allocation failed");return -1;}
  for(uint32_t k=0;k<fft_size;k++){double h=0.5-0.5*cos(2.0*M_PI*(double)k/(double)(fft_size-1));win[k]=sqrt(h<0?0:h);}
  size_t f=0;for(long st=-lead;st<(long)n;st+=(long)hop,f++){for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;double v=(i>=0&&i<(long)n)?x[i]:0;buf[k].re=v*win[k];buf[k].im=0;}av9_fft(buf,fft_size,0);for(size_t k=0;k<nb;k++)mag2[f*nb+k]=buf[k].re*buf[k].re+buf[k].im*buf[k].im;}
  for(size_t k=0;k<nb;k++){for(size_t t=0;t<frames;t++)col[t]=mag2[t*nb+k];qsort(col,frames,sizeof(double),cmp_dbl);size_t idx=(size_t)((percentile/100.0)*(double)(frames-1)+0.5);noise[k]=col[idx];}
  f=0;for(long st=-lead;st<(long)n;st+=(long)hop,f++){
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;double v=(i>=0&&i<(long)n)?x[i]:0;buf[k].re=v*win[k];buf[k].im=0;}av9_fft(buf,fft_size,0);
    for(size_t k=0;k<nb;k++){double hz=(double)sr*k/fft_size,p=mag2[f*nb+k],g;if(hz<lo_hz||hz>hi_hz)g=0;else{g=p>1e-30?1.0-over*noise[k]/p:0;if(g<floor_gain)g=floor_gain;if(g>1)g=1;}
      buf[k].re*=g;buf[k].im*=g;if(k>0&&k<fft_size/2){size_t j=fft_size-k;buf[j].re*=g;buf[j].im*=g;}}
    av9_fft(buf,fft_size,1);for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;if(i<0||i>=(long)n)continue;acc[i]+=buf[k].re*win[k];norm[i]+=win[k]*win[k];}
  }
  FILE*fo=fopen(out_path,"wb");if(!fo){free(mag2);free(win);free(buf);free(acc);free(norm);free(noise);free(col);free(x);seterr2("cannot create suppress output",out_path);return -1;}
  for(size_t i=0;i<n;i++){float v=(float)(norm[i]>1e-12?acc[i]/norm[i]:0.0);if(fwrite(&v,sizeof(float),1,fo)!=1){fclose(fo);free(mag2);free(win);free(buf);free(acc);free(norm);free(noise);free(col);free(x);seterr2("cannot write suppress output",out_path);return -1;}}
  fclose(fo);free(mag2);free(win);free(buf);free(acc);free(norm);free(noise);free(col);free(x);return 0;
}
/* av9_spatial_template_scan_tsv: slide a short template over a long signal, Pearson correlation at every
 * offset (step), return the top_k non-overlapping offsets.  Used to place V7 Tier A clips on the FD/FC
 * timelines from their envelopes.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026. */
const char *av9_spatial_template_scan_tsv(const char*long_path,const char*templ_path,uint32_t step,uint32_t top_k){
  g_error[0]='\0';if(!long_path||!templ_path||step<1||top_k<1||top_k>100){seterr("invalid template scan arguments");return NULL;}
  size_t n=0,m=0;float*x=read_f32(long_path,&n);if(!x)return NULL;float*t=read_f32(templ_path,&m);if(!t){free(x);return NULL;}
  if(m<8||m>n){free(x);free(t);seterr("template must be shorter than signal");return NULL;}
  long double st=0,stt=0;for(size_t i=0;i<m;i++){st+=t[i];stt+=(long double)t[i]*t[i];}long double vt=stt-st*st/m;
  if(vt<=1e-30L){free(x);free(t);seterr("template has no variance");return NULL;}
  size_t cnt=(n-m)/step+1;double*sc=malloc(cnt*sizeof(double));if(!sc){free(x);free(t);seterr("allocation failed");return NULL;}
  for(size_t c=0;c<cnt;c++){size_t o=c*step;long double sx=0,sxx=0,sxt=0;for(size_t i=0;i<m;i++){long double v=x[o+i];sx+=v;sxx+=v*v;sxt+=v*t[i];}
    long double vx=sxx-sx*sx/m,cov=sxt-sx*st/m;sc[c]=(vx>1e-30L)?(double)(cov/sqrtl(vx*vt)):0;}
  size_t used=0;if(!ensure_text(256+top_k*64)){free(sc);free(x);free(t);return NULL;}g_text[0]='\0';
  long double s1=0,s2=0;for(size_t c=0;c<cnt;c++){s1+=sc[c];s2+=sc[c]*sc[c];}double mu=(double)(s1/cnt),sd=sqrt((double)(s2/cnt)-mu*mu);if(sd<1e-12)sd=1e-12;
  if(!appendf(&used,"AUDIO_V9_TEMPLATE_SCAN/1\tLONG=%zu\tTEMPLATE=%zu\tSTEP=%u\tOFFSETS=%zu\tMEAN=%.6f\tSD=%.6f\n",n,m,step,cnt,mu,sd)){free(sc);free(x);free(t);return NULL;}
  for(uint32_t k=0;k<top_k;k++){size_t bi=0;double b=-9;for(size_t c=0;c<cnt;c++)if(sc[c]>b){b=sc[c];bi=c;}if(b<=-9)break;
    if(!appendf(&used,"%zu\t%.6f\t%.2f\n",bi*step,b,(b-mu)/sd)){free(sc);free(x);free(t);return NULL;}
    size_t ex=m/step+1;size_t lo=bi>ex?bi-ex:0,hi=bi+ex<cnt?bi+ex:cnt-1;for(size_t c=lo;c<=hi;c++)sc[c]=-10;}
  free(sc);free(x);free(t);return g_text;
}
/* av9_spatial_gccphat_tsv: GCC-PHAT delay between two equal-length windows, band-limited lo..hi Hz.
 * Positive lag => B later than A (provider convention).  Returns the top 3 peaks within +-max_lag samples with
 * a peak-to-RMS sharpness.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026. */
const char *av9_spatial_gccphat_tsv(const char*a_path,const char*b_path,uint32_t sr,int32_t max_lag,double lo_hz,double hi_hz){
  g_error[0]='\0';if(!a_path||!b_path||sr<1000||max_lag<1||!(hi_hz>lo_hz)){seterr("invalid gcc-phat arguments");return NULL;}
  size_t na=0,nb=0;float*a=read_f32(a_path,&na);if(!a)return NULL;float*b=read_f32(b_path,&nb);if(!b){free(a);return NULL;}
  if(na!=nb){free(a);free(b);seterr("paired f32 sample counts differ");return NULL;}
  size_t n=1;while(n<2*na)n<<=1;av9_cpx_t*A=calloc(n,sizeof(av9_cpx_t)),*B=calloc(n,sizeof(av9_cpx_t));double*cc=malloc(n*sizeof(double));
  if(!A||!B||!cc){free(A);free(B);free(cc);free(a);free(b);seterr("allocation failed");return NULL;}
  for(size_t i=0;i<na;i++){double w=0.5-0.5*cos(2.0*M_PI*(double)i/(double)(na>1?na-1:1));A[i].re=a[i]*w;B[i].re=b[i]*w;}
  av9_fft(A,n,0);av9_fft(B,n,0);
  for(size_t k=0;k<n;k++){size_t kk=k<=n/2?k:n-k;double hz=(double)sr*kk/n;
    /* cross spectrum conj(A)*B -> peak at +lag when B is later */
    double re=A[k].re*B[k].re+A[k].im*B[k].im,im=A[k].re*B[k].im-A[k].im*B[k].re,m=sqrt(re*re+im*im);
    if(hz<lo_hz||hz>hi_hz||m<1e-20){A[k].re=0;A[k].im=0;}else{A[k].re=re/m;A[k].im=im/m;}}
  av9_fft(A,n,1);
  for(size_t i=0;i<n;i++)cc[i]=A[i].re;
  long L=max_lag;if((size_t)L>=n/2)L=(long)(n/2-1);long double s2=0;size_t cnt=0;
  for(long l=-L;l<=L;l++){size_t i=(size_t)((l+(long)n)%(long)n);s2+=cc[i]*cc[i];cnt++;}
  double rms=sqrt((double)(s2/cnt));if(rms<1e-30)rms=1e-30;
  size_t used=0;if(!ensure_text(512)){free(A);free(B);free(cc);free(a);free(b);return NULL;}g_text[0]='\0';
  if(!appendf(&used,"AUDIO_V9_GCCPHAT/1\tSAMPLES=%zu\tMAX_LAG=%ld\tLO=%.1f\tHI=%.1f\n",na,L,lo_hz,hi_hz)){free(A);free(B);free(cc);free(a);free(b);return NULL;}
  for(int p=0;p<3;p++){double best=-1e30;long bl=0;for(long l=-L;l<=L;l++){size_t i=(size_t)((l+(long)n)%(long)n);if(cc[i]>best){best=cc[i];bl=l;}}
    /* sub-sample parabolic refinement */
    double frac=0;{size_t i0=(size_t)((bl-1+(long)n)%(long)n),i1=(size_t)((bl+(long)n)%(long)n),i2=(size_t)((bl+1+(long)n)%(long)n);double y0=cc[i0],y1=cc[i1],y2=cc[i2],den=y0-2*y1+y2;if(fabs(den)>1e-30)frac=0.5*(y0-y2)/den;if(frac>0.5)frac=0.5;if(frac<-0.5)frac=-0.5;}
    if(!appendf(&used,"%.3f\t%.6f\t%.2f\n",(double)bl+frac,best,best/rms)){free(A);free(B);free(cc);free(a);free(b);return NULL;}
    for(long l=bl-8;l<=bl+8;l++){size_t i=(size_t)((l+(long)n)%(long)n);cc[i]=-1e30;}}
  free(A);free(B);free(cc);free(a);free(b);return g_text;
}
/* av9_spatial_enhance_f32: adaptive single-channel speech enhancer for noisy CCTV audio.
 * Architecture: Tom Dyer (direction 31 Oct 2026: "get the audio quality up").  Coding: Claude (Opus 5.5).
 * Method (published, standard): STFT with sqrt-Hann analysis/synthesis, overlap-add.
 *  1. Noise PSD per bin by minimum statistics (Martin 2001, simplified): smoothed periodogram
 *     P = 0.85*P + 0.15*|Y|^2; minimum over the last noise_win_s seconds (U=8 sub-windows), times a bias.
 *     Unlike stationary_suppress (one percentile per bin for the whole file) this follows traffic, wind,
 *     klaxon level and room tone as they change.
 *  2. A priori SNR by the decision-directed rule (Ephraim-Malah 1984), alpha = alpha_dd; floor xi_min.
 *  3. Gain: MMSE log-spectral amplitude (Ephraim-Malah 1985), G = xi/(1+xi)*exp(E1(v)/2), v = xi*gamma/(1+xi).
 *     Gain floor gmin (linear); bins outside lo_hz..hi_hz get 0.
 *  over: noise over-estimate factor (1 = none).  Returns 0 or -1.  */
static double av9_e1(double x){ /* exponential integral E1, x>0 (Abramowitz-Stegun 5.1.53/5.1.56) */
  if(x<=0)return 30.0;
  if(x<=1.0){return -log(x)-0.57721566+x*(0.99999193+x*(-0.24991055+x*(0.05519968+x*(-0.00976004+x*0.00107857))));}
  return exp(-x)/x*(x*x+2.334733*x+0.250621)/(x*x+3.330657*x+1.681534);
}
int32_t av9_spatial_enhance_f32(const char*in_path,const char*out_path,uint32_t sr,uint32_t fft_size,uint32_t hop,
    double noise_win_s,double alpha_dd,double over,double gmin,double lo_hz,double hi_hz){
  g_error[0]='\0';
  if(!in_path||!out_path||sr<1000||!is_pow2_u32(fft_size)||fft_size<64||fft_size>4096||hop<1||hop>fft_size/2||
     !(noise_win_s>0.1&&noise_win_s<30)||!(alpha_dd>=0&&alpha_dd<1)||!(over>0)||!(gmin>=0&&gmin<=1)||!(hi_hz>lo_hz)){seterr("invalid enhance arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  size_t nb=fft_size/2+1;const int U=8;
  int D=(int)(noise_win_s*sr/hop+0.5);if(D<U)D=U;int V=(D+U-1)/U; /* sub-window length in frames */
  double*win=malloc(fft_size*sizeof(double));av9_cpx_t*buf=malloc(fft_size*sizeof(av9_cpx_t));
  double*acc=calloc(n+fft_size,sizeof(double)),*norm=calloc(n+fft_size,sizeof(double));
  double*P=calloc(nb,sizeof(double)),*sub=malloc(U*nb*sizeof(double)),*cur=malloc(nb*sizeof(double)),*noise=malloc(nb*sizeof(double));
  double*gprev=malloc(nb*sizeof(double)),*gamprev=malloc(nb*sizeof(double));
  if(!win||!buf||!acc||!norm||!P||!sub||!cur||!noise||!gprev||!gamprev){free(win);free(buf);free(acc);free(norm);free(P);free(sub);free(cur);free(noise);free(gprev);free(gamprev);free(x);seterr("allocation failed");return -1;}
  for(uint32_t k=0;k<fft_size;k++){double h=0.5-0.5*cos(2.0*M_PI*(double)k/(double)fft_size);win[k]=sqrt(h<0?0:h);}
  const double as=0.85,bias=1.5,ximin=pow(10.0,-25.0/10.0);
  for(size_t k=0;k<nb;k++){gprev[k]=1;gamprev[k]=1;cur[k]=1e300;for(int u=0;u<U;u++)sub[u*nb+k]=1e300;}
  long lead=(long)fft_size-(long)hop;long f=0;int sidx=0,scount=0;
  for(long st=-lead;st<(long)n;st+=(long)hop,f++){
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;double v=(i>=0&&i<(long)n)?x[i]:0;buf[k].re=v*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);
    for(size_t k=0;k<nb;k++){
      double y2=buf[k].re*buf[k].re+buf[k].im*buf[k].im;
      P[k]=(f==0)?y2:as*P[k]+(1-as)*y2;
      if(P[k]<cur[k])cur[k]=P[k];
      double m=cur[k];for(int u=0;u<U;u++)if(sub[u*nb+k]<m)m=sub[u*nb+k];
      noise[k]=bias*m*over;if(noise[k]<1e-20)noise[k]=1e-20;
    }
    if(++scount>=V){for(size_t k=0;k<nb;k++){sub[sidx*nb+k]=cur[k];cur[k]=1e300;}sidx=(sidx+1)%U;scount=0;}
    for(size_t k=0;k<nb;k++){
      double hz=(double)sr*k/fft_size,g;
      if(hz<lo_hz||hz>hi_hz)g=0;
      else{
        double y2=buf[k].re*buf[k].re+buf[k].im*buf[k].im,gam=y2/noise[k];if(gam>1e4)gam=1e4;
        double xi=alpha_dd*gprev[k]*gprev[k]*gamprev[k]+(1-alpha_dd)*(gam-1>0?gam-1:0);if(xi<ximin)xi=ximin;
        double v=xi*gam/(1+xi);g=xi/(1+xi)*exp(0.5*av9_e1(v));if(g>1)g=1;
        gamprev[k]=gam;gprev[k]=g;if(g<gmin)g=gmin;
      }
      buf[k].re*=g;buf[k].im*=g;if(k>0&&k<fft_size/2){size_t j=fft_size-k;buf[j].re*=g;buf[j].im*=g;}
    }
    av9_fft(buf,fft_size,1);
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;if(i<0||i>=(long)n)continue;acc[i]+=buf[k].re*win[k];norm[i]+=win[k]*win[k];}
  }
  FILE*fo=fopen(out_path,"wb");
  if(!fo){free(win);free(buf);free(acc);free(norm);free(P);free(sub);free(cur);free(noise);free(gprev);free(gamprev);free(x);seterr2("cannot create enhance output",out_path);return -1;}
  int bad=0;for(size_t i=0;i<n;i++){float v=(float)(norm[i]>1e-12?acc[i]/norm[i]:0.0);if(fwrite(&v,sizeof(float),1,fo)!=1){bad=1;break;}}
  fclose(fo);free(win);free(buf);free(acc);free(norm);free(P);free(sub);free(cur);free(noise);free(gprev);free(gamprev);free(x);
  if(bad){seterr2("cannot write enhance output",out_path);return -1;}
  return 0;
}
/* av9_spatial_compare_tsv: score a processed signal against a clean reference (same length, same alignment).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), 31 Oct 2026.  Used to tune the enhancer on a clean
 * phone-call voice mixed with real recording noise.  Measures (standard definitions):
 *   SNR_DB      10log10(sum ref^2 / sum (ref-test)^2), after the least-squares gain on test (level-independent)
 *   SEGSNR_DB   mean over frames of the same, frames clamped to [-10,35] dB, only frames where ref is active
 *               (ref frame energy within 40 dB of its loudest frame)
 *   LSD_DB      log-spectral distance, mean over active frames of sqrt(mean_k (10log10 Pr/Pt)^2), bins lo..hi Hz
 *   ACTIVE      number of active frames */
const char *av9_spatial_compare_tsv(const char*ref_path,const char*test_path,uint32_t sr,uint32_t frame,double lo_hz,double hi_hz){
  g_error[0]='\0';if(!ref_path||!test_path||sr<1000||!is_pow2_u32(frame)||frame<64||frame>4096||!(hi_hz>lo_hz)){seterr("invalid compare arguments");return NULL;}
  size_t n=0,m=0;float*r=read_f32(ref_path,&n);if(!r)return NULL;float*t=read_f32(test_path,&m);if(!t){free(r);return NULL;}
  if(n!=m||n<frame){free(r);free(t);seterr("reference and test differ in length or are too short");return NULL;}
  long double rt=0,tt=0;for(size_t i=0;i<n;i++){rt+=(long double)r[i]*t[i];tt+=(long double)t[i]*t[i];}
  double a=tt>0?(double)(rt/tt):0;
  long double sr2=0,se2=0;for(size_t i=0;i<n;i++){double e=r[i]-a*t[i];sr2+=(long double)r[i]*r[i];se2+=e*e;}
  double snr=se2>0?10*log10((double)(sr2/se2)):99;
  size_t nf=n/frame;double*fe=malloc(nf*sizeof(double));av9_cpx_t*br=malloc(frame*sizeof(av9_cpx_t)),*bt=malloc(frame*sizeof(av9_cpx_t));double*win=malloc(frame*sizeof(double));
  if(!fe||!br||!bt||!win){free(fe);free(br);free(bt);free(win);free(r);free(t);seterr("allocation failed");return NULL;}
  double fmax=0;for(size_t f=0;f<nf;f++){long double s=0;for(size_t i=0;i<frame;i++){double v=r[f*frame+i];s+=v*v;}fe[f]=(double)s;if(fe[f]>fmax)fmax=fe[f];}
  for(uint32_t k=0;k<frame;k++)win[k]=0.5-0.5*cos(2.0*M_PI*(double)k/(double)frame);
  double segsum=0,lsdsum=0;size_t act=0;
  for(size_t f=0;f<nf;f++){
    if(!(fe[f]>fmax*1e-4)||fe[f]<=0)continue;
    long double e2=0;for(size_t i=0;i<frame;i++){double e=r[f*frame+i]-a*t[f*frame+i];e2+=e*e;}
    double s=e2>0?10*log10(fe[f]/(double)e2):35;if(s<-10)s=-10;if(s>35)s=35;segsum+=s;
    for(uint32_t k=0;k<frame;k++){br[k].re=r[f*frame+k]*win[k];br[k].im=0;bt[k].re=a*t[f*frame+k]*win[k];bt[k].im=0;}
    av9_fft(br,frame,0);av9_fft(bt,frame,0);
    double d=0;int c=0;for(uint32_t k=0;k<=frame/2;k++){double hz=(double)sr*k/frame;if(hz<lo_hz||hz>hi_hz)continue;
      double pr=br[k].re*br[k].re+br[k].im*br[k].im+1e-12,pt=bt[k].re*bt[k].re+bt[k].im*bt[k].im+1e-12,q=10*log10(pr/pt);d+=q*q;c++;}
    if(c>0)lsdsum+=sqrt(d/c);
    act++;
  }
  free(fe);free(br);free(bt);free(win);free(r);free(t);
  size_t used=0;if(!ensure_text(256))return NULL;g_text[0]='\0';
  if(!appendf(&used,"AUDIO_V9_COMPARE/1\tSAMPLES=%zu\nSNR_DB\t%.3f\nSEGSNR_DB\t%.3f\nLSD_DB\t%.3f\nACTIVE\t%zu\nGAIN\t%.6f\n",n,snr,act?segsum/act:0,act?lsdsum/act:0,act,a))return NULL;
  return g_text;
}
/* av9_spatial_speech_agc_f32: aggressive speech level control for weak voices in loud backgrounds.
 * Architecture: Tom Dyer (direction 5 Nov 2026: "more aggressive", weak female voice).  Coding: Claude (Opus 5.5).
 * Level detector: speech-band (300-3400 Hz, 2nd-order band-pass pair) RMS over 20 ms frames, in dBFS.
 * Gate: frames below (floor_db = 20th percentile of frame levels over the file) + gate_db get no extra gain
 *   beyond the gain already reached (so silence/background is not pumped up between words).
 * Gain: target_db - level, clamped to [0, max_gain_db]; smoothed per sample with attack_ms (gain falling)
 *   and release_ms (gain rising).  Limiter: look-ahead (5 ms) peak limiter at limit_db, instant attack,
 *   50 ms release.  Output is the full-band input times the gain (band-limit beforehand if wanted).
 * Returns 0 or -1. */
int32_t av9_spatial_speech_agc_f32(const char*in_path,const char*out_path,uint32_t sr,double target_db,double max_gain_db,
    double attack_ms,double release_ms,double gate_db,double limit_db){
  g_error[0]='\0';
  if(!in_path||!out_path||sr<4000||!(max_gain_db>=0&&max_gain_db<=60)||!(attack_ms>0)||!(release_ms>0)||!(limit_db<=0)){seterr("invalid agc arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  size_t fl=(size_t)(sr/50);if(fl<16)fl=16;size_t nf=(n+fl-1)/fl;
  double*lv=malloc(nf*sizeof(double)),*srt=malloc(nf*sizeof(double));float*y=malloc(n*sizeof(float));
  if(!lv||!srt||!y){free(lv);free(srt);free(y);free(x);seterr("allocation failed");return -1;}
  /* band-pass 300-3400 via biquad high-pass 300 + low-pass 3400 (RBJ, Q=0.707) */
  double b0h,b1h,b2h,a1h,a2h,b0l,b1l,b2l,a1l,a2l;
  { double w=2*M_PI*300.0/sr,c=cos(w),s=sin(w),al=s/(2*0.7071),a0=1+al;b0h=(1+c)/2/a0;b1h=-(1+c)/a0;b2h=(1+c)/2/a0;a1h=-2*c/a0;a2h=(1-al)/a0; }
  { double fc=3400.0;if(fc>0.45*sr)fc=0.45*sr;double w=2*M_PI*fc/sr,c=cos(w),s=sin(w),al=s/(2*0.7071),a0=1+al;b0l=(1-c)/2/a0;b1l=(1-c)/a0;b2l=(1-c)/2/a0;a1l=-2*c/a0;a2l=(1-al)/a0; }
  double h1=0,h2=0,g1=0,g2=0,hx1=0,hx2=0,lx1=0,lx2=0;
  for(size_t f=0;f<nf;f++){long double ss=0;size_t c=0;
    for(size_t i=f*fl;i<(f+1)*fl&&i<n;i++){double v=x[i];
      double hp=b0h*v+b1h*hx1+b2h*hx2-a1h*h1-a2h*h2;hx2=hx1;hx1=v;h2=h1;h1=hp;
      double lp=b0l*hp+b1l*lx1+b2l*lx2-a1l*g1-a2l*g2;lx2=lx1;lx1=hp;g2=g1;g1=lp;
      ss+=lp*lp;c++;}
    lv[f]=10*log10((double)(ss/(c?c:1))+1e-20);srt[f]=lv[f];}
  /* 20th percentile floor (simple sort) */
  for(size_t i=1;i<nf;i++){double v=srt[i];size_t j=i;while(j>0&&srt[j-1]>v){srt[j]=srt[j-1];j--;}srt[j]=v;}
  double floor_db=srt[(size_t)(nf*0.2)];free(srt);
  double ka=exp(-1.0/(attack_ms*1e-3*sr)),kr=exp(-1.0/(release_ms*1e-3*sr));
  double g=0;/* dB */
  for(size_t i=0;i<n;i++){
    size_t f=i/fl;double want;
    if(lv[f]<floor_db+gate_db)want=g; /* hold: do not raise gain on background */
    else{want=target_db-lv[f];if(want<0)want=0;if(want>max_gain_db)want=max_gain_db;}
    if(want<g)g=ka*g+(1-ka)*want;else g=kr*g+(1-kr)*want;
    y[i]=(float)(x[i]*pow(10.0,g/20.0));
  }
  free(lv);free(x);
  /* look-ahead peak limiter */
  double lim=pow(10.0,limit_db/20.0);size_t la=(size_t)(0.005*sr);if(la<1)la=1;
  double rel=exp(-1.0/(0.050*sr)),gl=1.0;
  float*z=malloc(n*sizeof(float));if(!z){free(y);seterr("allocation failed");return -1;}
  /* running max over the next la samples via simple deque-free scan (la small) */
  for(size_t i=0;i<n;i++){
    double pk=0;for(size_t k=i;k<i+la&&k<n;k++){double a=fabs(y[k]);if(a>pk)pk=a;}
    double need=pk>lim?lim/pk:1.0;
    if(need<gl)gl=need;else gl=rel*gl+(1-rel)*need;
    double v=y[i]*gl;if(v>lim)v=lim;if(v<-lim)v=-lim;z[i]=(float)v;
  }
  free(y);
  FILE*fo=fopen(out_path,"wb");if(!fo){free(z);seterr2("cannot create agc output",out_path);return -1;}
  size_t w=fwrite(z,sizeof(float),n,fo);fclose(fo);free(z);
  if(w!=n){seterr2("cannot write agc output",out_path);return -1;}
  return 0;
}
/* av9_spatial_pitch_f32: lower (or raise) pitch by `semitones` keeping duration, for intelligibility
 * of high voices.  Architecture: Tom Dyer (lower-pitch companion version, 5 Nov 2026).  Coding: Claude (Opus 5.5).
 * Method: WSOLA time-scale change to length n*p, p = 2^(semitones/12) (frames 30 ms, hop 15 ms, search +-7.5 ms by
 * normalised cross-correlation within +-tol_ms (local timing wander is bounded by it), Hann overlap-add), then resampling by 1/p (cubic interpolation), so
 * duration returns to the original and pitch (and formants) move by p.  semitones < 0 lowers.  */
int32_t av9_spatial_pitch_f32(const char*in_path,const char*out_path,uint32_t sr,double semitones,double tol_ms){
  g_error[0]='\0';
  if(!in_path||!out_path||sr<4000||!(semitones>=-12&&semitones<=12)||!(tol_ms>=0.5&&tol_ms<=15)){seterr("invalid pitch arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  double p=pow(2.0,semitones/12.0);
  size_t N=(size_t)(0.030*sr),Hs=N/2,tol=(size_t)(tol_ms*1e-3*sr+0.5);if(N<32){free(x);seterr("sample rate too low");return -1;}
  /* WSOLA: output hop Hs, input hop Ha = Hs/p, so the intermediate s is n*p long (p<1: shorter, same pitch);
     reading s at rate p then restores length n and moves pitch by p.  (Fixed 5 Nov 2026: was Hs*p, which
     played the content at speed p^2.) */
  double Ha=(double)Hs/p;size_t nout=(size_t)((double)n*p)+N+2;
  double*acc=calloc(nout+N,sizeof(double)),*wsum=calloc(nout+N,sizeof(double)),*win=malloc(N*sizeof(double));
  if(!acc||!wsum||!win){free(acc);free(wsum);free(win);free(x);seterr("allocation failed");return -1;}
  for(size_t k=0;k<N;k++)win[k]=0.5-0.5*cos(2*M_PI*(double)k/(double)N);
  long prev=0;size_t m=0;size_t outlen=0;
  for(;;m++){
    double nominal=m*Ha;long cand=(long)(nominal+0.5);
    if(cand+(long)N+(long)tol>=(long)n)break;
    long best=cand;
    if(m>0){ /* match the natural continuation of the previous frame: x[prev+Hs .. ] */
      long nat=prev+(long)Hs;double bs=-2;
      for(long d=-(long)tol;d<=(long)tol;d++){long c=cand+d;if(c<0||c+(long)N>=(long)n)continue;
        double num=0,ea=0,eb=0;for(size_t k=0;k<N;k+=2){long ia=nat+(long)k;if(ia>=(long)n)ia=(long)n-1;double a=x[ia],b=x[c+(long)k];num+=a*b;ea+=a*a;eb+=b*b;}
        double sc=num/sqrt(ea*eb+1e-20);if(sc>bs){bs=sc;best=c;}}
    }
    size_t o=m*Hs;for(size_t k=0;k<N;k++){acc[o+k]+=x[best+k]*win[k];wsum[o+k]+=win[k];}
    prev=best;outlen=o+N;
  }
  free(x);
  size_t sl=outlen;float*s=malloc((sl?sl:1)*sizeof(float));if(!s){free(acc);free(wsum);free(win);seterr("allocation failed");return -1;}
  for(size_t i=0;i<sl;i++)s[i]=(float)(wsum[i]>1e-6?acc[i]/wsum[i]:0);
  free(acc);free(wsum);free(win);
  /* resample: output sample j reads stretched signal at position j*p (cubic), length n */
  float*z=malloc(n*sizeof(float));if(!z){free(s);seterr("allocation failed");return -1;}
  /* frame-centre compensation: s(tau) holds input time tau/p - (N/2)(1/p-1), so read at j*p + (N/2)(1-p) */
  double c0=0.5*(double)N*(1.0-p);
  for(size_t j=0;j<n;j++){double pos=j*p+c0;long i=(long)pos;double t=pos-i;
    double y0=(i-1>=0&&i-1<(long)sl)?s[i-1]:0,y1=(i>=0&&i<(long)sl)?s[i]:0,y2=(i+1<(long)sl)?s[i+1]:0,y3=(i+2<(long)sl)?s[i+2]:0;
    z[j]=(float)(y1+0.5*t*(y2-y0+t*(2*y0-5*y1+4*y2-y3+t*(3*(y1-y2)+y3-y0))));}
  free(s);
  FILE*fo=fopen(out_path,"wb");if(!fo){free(z);seterr2("cannot create pitch output",out_path);return -1;}
  size_t w=fwrite(z,sizeof(float),n,fo);fclose(fo);free(z);
  if(w!=n){seterr2("cannot write pitch output",out_path);return -1;}
  return 0;
}
/* av9_spatial_rake_f32: reflection ("rake") combiner for one microphone.
 * Architecture: Tom Dyer (use reflective paths from the 3D model, 5 Nov 2026).  Coding: Claude (Opus 5.5).
 * taps_tsv lines: advance_samples<TAB>weight  (header optional; '#' comments).  advance = (arrival delay of
 * the path) - (delay of the reference/direct path), from the Physics World scene, in samples (fractional).
 * y[t] = sum_k w_k * x[t + advance_k] / sum_k |w_k|  (cubic interpolation for fractional advances).
 * Each path's copy of a source's sound is moved back onto the direct arrival, so a source at the modelled
 * position adds coherently while sound from elsewhere and noise do not.  Returns 0 or -1. */
int32_t av9_spatial_rake_f32(const char*in_path,const char*out_path,const char*taps_tsv){
  g_error[0]='\0';if(!in_path||!out_path||!taps_tsv){seterr("invalid rake arguments");return -1;}
  FILE*ft=fopen(taps_tsv,"r");if(!ft){seterr2("cannot open taps",taps_tsv);return -1;}
  double adv[256],w[256];int K=0;char line[512];
  while(fgets(line,sizeof line,ft)&&K<256){if(line[0]=='#')continue;double a,b;if(sscanf(line,"%lf\t%lf",&a,&b)==2&&isfinite(a)&&isfinite(b)&&fabs(a)<1e7){adv[K]=a;w[K]=b;K++;}}
  fclose(ft);if(K<1){seterr("no taps");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  float*y=malloc((n?n:1)*sizeof(float));if(!y){free(x);seterr("allocation failed");return -1;}
  double ws=0;for(int k=0;k<K;k++)ws+=fabs(w[k]);if(ws<=0)ws=1;
  for(size_t t=0;t<n;t++){double s=0;
    for(int k=0;k<K;k++){double pos=(double)t+adv[k];long i=(long)floor(pos);double u=pos-i;
      double y0=(i-1>=0&&i-1<(long)n)?x[i-1]:0,y1=(i>=0&&i<(long)n)?x[i]:0,y2=(i+1>=0&&i+1<(long)n)?x[i+1]:0,y3=(i+2>=0&&i+2<(long)n)?x[i+2]:0;
      s+=w[k]*(y1+0.5*u*(y2-y0+u*(2*y0-5*y1+4*y2-y3+u*(3*(y1-y2)+y3-y0))));}
    y[t]=(float)(s/ws);}
  free(x);
  FILE*fo=fopen(out_path,"wb");if(!fo){free(y);seterr2("cannot create rake output",out_path);return -1;}
  size_t wr=fwrite(y,sizeof(float),n,fo);fclose(fo);free(y);
  if(wr!=n){seterr2("cannot write rake output",out_path);return -1;}
  return 0;
}
/* av9_spatial_yin_f0: frame-wise fundamental frequency by YIN (de Cheveigne & Kawahara 2002).
 * Architecture: Tom Dyer (pitch profiling in small buckets, male/female, 5 Nov 2026).  Coding: Claude (Opus 5.5).
 * Per frame (window `frame` samples, step `hop`): difference function over lags fmin..fmax, cumulative-mean
 * normalisation, first dip below `thresh` (then its local minimum), parabolic interpolation.
 * Output TSV: time_s  f0_hz (0 = unvoiced)  aperiodicity (CMNDF at the chosen lag; lower = more periodic)  rms_db.
 * Signal is band-limited to 60-1000 Hz first (2nd-order sections) so formants do not pull the estimate. */
int32_t av9_spatial_yin_f0(const char*in_path,const char*out_tsv,uint32_t sr,uint32_t frame,uint32_t hop,double fmin,double fmax,double thresh){
  g_error[0]='\0';
  if(!in_path||!out_tsv||sr<4000||frame<64||frame>8192||hop<1||!(fmin>=30&&fmax>fmin&&fmax<=sr/4.0)||!(thresh>0&&thresh<1)){seterr("invalid yin arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  /* band-limit 60-1000 Hz */
  double*y=malloc(n*sizeof(double));if(!y){free(x);seterr("allocation failed");return -1;}
  { double w=2*M_PI*60.0/sr,c=cos(w),s=sin(w),al=s/(2*0.7071),a0=1+al,b0=(1+c)/2/a0,b1=-(1+c)/a0,b2=(1+c)/2/a0,a1=-2*c/a0,a2=(1-al)/a0;
    double x1=0,x2=0,y1=0,y2=0;for(size_t i=0;i<n;i++){double v=x[i],o=b0*v+b1*x1+b2*x2-a1*y1-a2*y2;x2=x1;x1=v;y2=y1;y1=o;y[i]=o;} }
  { double fc=1000.0;if(fc>0.45*sr)fc=0.45*sr;double w=2*M_PI*fc/sr,c=cos(w),s=sin(w),al=s/(2*0.7071),a0=1+al,b0=(1-c)/2/a0,b1=(1-c)/a0,b2=(1-c)/2/a0,a1=-2*c/a0,a2=(1-al)/a0;
    double x1=0,x2=0,y1=0,y2=0;for(size_t i=0;i<n;i++){double v=y[i],o=b0*v+b1*x1+b2*x2-a1*y1-a2*y2;x2=x1;x1=v;y2=y1;y1=o;y[i]=o;} }
  size_t tmin=(size_t)floor(sr/fmax),tmax=(size_t)ceil(sr/fmin);if(tmax>=frame){free(x);free(y);seterr("frame too short for fmin");return -1;}
  size_t W=frame-tmax;double*d=malloc((tmax+2)*sizeof(double));
  FILE*fo=fopen(out_tsv,"w");if(!d||!fo){free(x);free(y);free(d);if(fo)fclose(fo);seterr2("cannot create yin output",out_tsv);return -1;}
  fprintf(fo,"time_s\tf0_hz\taperiodicity\trms_db\n");
  for(size_t st=0;st+frame<=n;st+=hop){
    double e=0;for(size_t j=0;j<frame;j++)e+=(double)x[st+j]*x[st+j];double rdb=10*log10(e/frame+1e-20);
    d[0]=0;for(size_t t=1;t<=tmax;t++){double s=0;for(size_t j=0;j<W;j++){double q=y[st+j]-y[st+j+t];s+=q*q;}d[t]=s;}
    double cum=0;size_t best=0;double bv=1e9;
    for(size_t t=1;t<=tmax;t++){cum+=d[t];d[t]=cum>0?d[t]*t/cum:1;}
    for(size_t t=tmin;t<=tmax;t++){ if(d[t]<thresh){ while(t+1<=tmax&&d[t+1]<d[t])t++; best=t;bv=d[t];break; } }
    if(!best){for(size_t t=tmin;t<=tmax;t++)if(d[t]<bv){bv=d[t];best=t;}}
    double f0=0;
    if(best&&bv<thresh){double tau=best;if(best>tmin&&best<tmax){double a=d[best-1],b=d[best],c=d[best+1],den=a-2*b+c;if(den>0)tau=best+0.5*(a-c)/den;}f0=sr/tau;}
    fprintf(fo,"%.4f\t%.2f\t%.4f\t%.2f\n",(st+frame/2.0)/sr,f0,bv,rdb);
  }
  fclose(fo);free(x);free(y);free(d);return 0;
}
/* av9_spatial_tonal_burst_suppress_f32: remove short tonal bursts (bird screech) from a band, keep speech.
 * Architecture: Tom Dyer (5 Nov 2026: screech of consistent length/pitch stops volume enhancement).
 * Coding: Claude (Opus 5.5).
 * Detect (per STFT frame): band (lo..hi) energy over core speech band (300..1800 Hz) >= ratio_db AND
 *   spectral flatness of the band <= flat_max (tonal).  Flagged frames joined across 1-frame gaps; runs
 *   kept only if min_ms <= length <= max_ms; widened by guard_ms each side.
 * Suppress (flagged frames only, bins lo..hi): every bin more than peak_db above its floor is pulled down to
 *   floor + peak_db; floor = the smaller of the local median magnitude within +-150 Hz and the bin's own average over
 *   out-of-burst frames; the rest of the band is untouched, so noise-like
 *   speech consonants survive.  Frames outside bursts pass unchanged.  sqrt-Hann STFT, overlap-add.
 * events_tsv: start_s end_s length_ms peak_ratio_db dominant_hz.  Returns number of bursts or -1. */
int32_t av9_spatial_tonal_burst_suppress_f32(const char*in_path,const char*out_path,const char*events_tsv,uint32_t sr,uint32_t fft_size,uint32_t hop,
    double lo_hz,double hi_hz,double ratio_db,double flat_max,double min_ms,double max_ms,double guard_ms,double peak_db){
  g_error[0]='\0';
  if(!in_path||!out_path||!events_tsv||sr<4000||!is_pow2_u32(fft_size)||fft_size<128||fft_size>4096||hop<1||hop>fft_size/2||!(hi_hz>lo_hz)||!(max_ms>min_ms)){seterr("invalid tonal burst arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  size_t nb=fft_size/2+1;long lead=(long)fft_size-(long)hop;size_t nf=(n+lead)/hop+2;
  double*win=malloc(fft_size*sizeof(double));av9_cpx_t*buf=malloc(fft_size*sizeof(av9_cpx_t));
  double*ratio=calloc(nf,sizeof(double));unsigned char*flag=calloc(nf,1),*keep=calloc(nf,1);double*dom=calloc(nf,sizeof(double));
  double*acc=calloc(n+fft_size,sizeof(double)),*nrm=calloc(n+fft_size,sizeof(double)),*mag=malloc(nb*sizeof(double)),*tmp=malloc(nb*sizeof(double)),*refp=calloc(nb,sizeof(double));size_t refn=0;
  if(!win||!buf||!ratio||!flag||!keep||!dom||!acc||!nrm||!mag||!tmp||!refp){free(refp);free(win);free(buf);free(ratio);free(flag);free(keep);free(dom);free(acc);free(nrm);free(mag);free(tmp);free(x);seterr("allocation failed");return -1;}
  for(uint32_t k=0;k<fft_size;k++){double h=0.5-0.5*cos(2.0*M_PI*k/fft_size);win[k]=sqrt(h<0?0:h);}
  size_t klo=(size_t)ceil(lo_hz*fft_size/sr),khi=(size_t)floor(hi_hz*fft_size/sr);if(khi>=nb)khi=nb-1;
  size_t c0=(size_t)ceil(300.0*fft_size/sr),c1=(size_t)floor(1800.0*fft_size/sr);
  /* pass 1: detect */
  size_t f=0;
  for(long st=-lead;st<(long)n&&f<nf;st+=(long)hop,f++){
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;double v=(i>=0&&i<(long)n)?x[i]:0;buf[k].re=v*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);
    double core=1e-20,band=1e-20,lg=0,mx=0;size_t cnt=0,km=klo;
    for(size_t k=c0;k<=c1;k++)core+=buf[k].re*buf[k].re+buf[k].im*buf[k].im;
    for(size_t k=klo;k<=khi;k++){double p=buf[k].re*buf[k].re+buf[k].im*buf[k].im+1e-20;band+=p;lg+=log(p);cnt++;if(p>mx){mx=p;km=k;}}
    double fl=cnt?exp(lg/cnt)/(band/cnt):1;
    ratio[f]=10*log10(band/core);dom[f]=(double)km*sr/fft_size;
    flag[f]=(ratio[f]>=ratio_db&&fl<=flat_max);
    if(!flag[f]){for(size_t k=klo;k<=khi;k++)refp[k]+=buf[k].re*buf[k].re+buf[k].im*buf[k].im;refn++;}
  }
  for(size_t k=klo;k<=khi;k++)refp[k]=refn?refp[k]/refn:0;
  size_t used=f;
  /* runs */
  for(size_t i=1;i+1<used;i++)if(!flag[i]&&flag[i-1]&&flag[i+1])flag[i]=1;
  double fms=1000.0*hop/sr;size_t g=(size_t)(guard_ms/fms+0.5);
  FILE*ev=fopen(events_tsv,"w");if(!ev){free(refp);free(win);free(buf);free(ratio);free(flag);free(keep);free(dom);free(acc);free(nrm);free(mag);free(tmp);free(x);seterr2("cannot create events",events_tsv);return -1;}
  fprintf(ev,"start_s\tend_s\tlength_ms\tpeak_ratio_db\tdominant_hz\n");
  int bursts=0;
  for(size_t i=0;i<used;){
    if(!flag[i]){i++;continue;}
    size_t j=i;while(j+1<used&&flag[j+1])j++;
    double len=(j-i+1)*fms;
    if(len>=min_ms&&len<=max_ms){
      double pk=-99,dh=0;for(size_t k=i;k<=j;k++)if(ratio[k]>pk){pk=ratio[k];dh=dom[k];}
      size_t a=i>g?i-g:0,b=j+g<used?j+g:used-1;for(size_t k=a;k<=b;k++)keep[k]=1;
      double t0=((double)i*hop-lead)/sr,t1=((double)(j+1)*hop-lead+fft_size)/sr;if(t0<0)t0=0;
      fprintf(ev,"%.3f\t%.3f\t%.0f\t%.1f\t%.0f\n",t0,t1,len,pk,dh);bursts++;
    }
    i=j+1;
  }
  fclose(ev);
  /* pass 2: suppress tonal peaks in kept frames */
  size_t half=(size_t)(150.0*fft_size/sr+0.5);if(half<2)half=2;double pk_lin=pow(10.0,peak_db/20.0);
  f=0;
  for(long st=-lead;st<(long)n&&f<used;st+=(long)hop,f++){
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;double v=(i>=0&&i<(long)n)?x[i]:0;buf[k].re=v*win[k];buf[k].im=0;}
    if(keep[f]){
      av9_fft(buf,fft_size,0);
      for(size_t k=0;k<nb;k++)mag[k]=sqrt(buf[k].re*buf[k].re+buf[k].im*buf[k].im);
      for(size_t k=klo;k<=khi;k++){
        size_t a=k>half?k-half:0,b=k+half<nb?k+half:nb-1,m=0;for(size_t q=a;q<=b;q++)tmp[m++]=mag[q];
        for(size_t u=1;u<m;u++){double v=tmp[u];size_t w=u;while(w>0&&tmp[w-1]>v){tmp[w]=tmp[w-1];w--;}tmp[w]=v;}
        double floorv=tmp[m/2];
        /* also limit each bin to its own out-of-burst average power (+peak_db): chirps sweep across bins,
           so a local median inside the chirp can sit on the chirp itself */
        double refm=sqrt(refp[k]);if(refm>0&&refm<floorv)floorv=refm;
        if(mag[k]>floorv*pk_lin&&mag[k]>0){double gg=floorv*pk_lin/mag[k];buf[k].re*=gg;buf[k].im*=gg;if(k>0&&k<fft_size/2){size_t j=fft_size-k;buf[j].re*=gg;buf[j].im*=gg;}}
      }
      av9_fft(buf,fft_size,1);
      for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;if(i<0||i>=(long)n)continue;acc[i]+=buf[k].re*win[k];nrm[i]+=win[k]*win[k];}
    } else {
      for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;if(i<0||i>=(long)n)continue;acc[i]+=buf[k].re*win[k];nrm[i]+=win[k]*win[k];}
    }
  }
  FILE*fo=fopen(out_path,"wb");int bad=!fo;
  if(fo){for(size_t i=0;i<n;i++){float v=(float)(nrm[i]>1e-12?acc[i]/nrm[i]:x[i]);if(fwrite(&v,sizeof(float),1,fo)!=1){bad=1;break;}}fclose(fo);}
  free(win);free(buf);free(ratio);free(flag);free(keep);free(dom);free(acc);free(nrm);free(mag);free(tmp);free(refp);free(x);
  if(bad){seterr2("cannot write tonal burst output",out_path);return -1;}
  return bursts;
}
/* av9_spatial_voice_features: per-frame voice features for voice-type profiling.
 * Architecture: Tom Dyer (voice-profile SLAM: one profile per sample voice, strict matching, 5 Nov 2026).
 * Coding: Claude (Opus 5.5).
 * Per frame (window `frame`, step `hop`): YIN F0 (as av9_spatial_yin_f0, signal band-limited 60-1000 Hz),
 * aperiodicity, frame RMS dB, and the spectral SHAPE in `nbands` log-spaced bands from 100 to 3800 Hz:
 * 10*log10(band power / total power in 100-3800 Hz)  (level-independent; Hann window, FFT zero-padded).
 * Output TSV: time_s f0_hz aperiodicity rms_db s1..sN.  Returns frame count or -1. */
int32_t av9_spatial_voice_features(const char*in_path,const char*out_tsv,uint32_t sr,uint32_t frame,uint32_t hop,double fmin,double fmax,double thresh,uint32_t nbands){
  g_error[0]='\0';
  if(!in_path||!out_tsv||sr<4000||frame<64||frame>4096||hop<1||!(fmin>=30&&fmax>fmin&&fmax<=sr/4.0)||!(thresh>0&&thresh<1)||nbands<4||nbands>128){seterr("invalid voice feature arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  double*y=malloc(n*sizeof(double));if(!y){free(x);seterr("allocation failed");return -1;}
  { double w=2*M_PI*60.0/sr,c=cos(w),s=sin(w),al=s/(2*0.7071),a0=1+al,b0=(1+c)/2/a0,b1=-(1+c)/a0,b2=(1+c)/2/a0,a1=-2*c/a0,a2=(1-al)/a0;
    double x1=0,x2=0,y1=0,y2=0;for(size_t i=0;i<n;i++){double v=x[i],o=b0*v+b1*x1+b2*x2-a1*y1-a2*y2;x2=x1;x1=v;y2=y1;y1=o;y[i]=o;} }
  { double fc=1000.0;if(fc>0.45*sr)fc=0.45*sr;double w=2*M_PI*fc/sr,c=cos(w),s=sin(w),al=s/(2*0.7071),a0=1+al,b0=(1-c)/2/a0,b1=(1-c)/a0,b2=(1-c)/2/a0,a1=-2*c/a0,a2=(1-al)/a0;
    double x1=0,x2=0,y1=0,y2=0;for(size_t i=0;i<n;i++){double v=y[i],o=b0*v+b1*x1+b2*x2-a1*y1-a2*y2;x2=x1;x1=v;y2=y1;y1=o;y[i]=o;} }
  size_t tmin=(size_t)floor(sr/fmax),tmax=(size_t)ceil(sr/fmin);if(tmax>=frame){free(x);free(y);seterr("frame too short for fmin");return -1;}
  size_t W=frame-tmax,nfft=1;while(nfft<frame)nfft<<=1;
  double*d=malloc((tmax+2)*sizeof(double)),*win=malloc(frame*sizeof(double)),*edge=malloc((nbands+1)*sizeof(double)),*bp=malloc(nbands*sizeof(double));
  av9_cpx_t*buf=malloc(nfft*sizeof(av9_cpx_t));FILE*fo=fopen(out_tsv,"w");
  if(!d||!win||!edge||!bp||!buf||!fo){free(x);free(y);free(d);free(win);free(edge);free(bp);free(buf);if(fo)fclose(fo);seterr2("cannot create voice feature output",out_tsv);return -1;}
  for(size_t k=0;k<frame;k++)win[k]=0.5-0.5*cos(2*M_PI*(double)k/(double)frame);
  for(uint32_t b=0;b<=nbands;b++)edge[b]=100.0*pow(3800.0/100.0,(double)b/nbands);
  fprintf(fo,"time_s\tf0_hz\taperiodicity\trms_db");for(uint32_t b=0;b<nbands;b++)fprintf(fo,"\ts%u",b+1);fprintf(fo,"\n");
  int32_t frames=0;
  for(size_t st=0;st+frame<=n;st+=hop){
    double e=0;for(size_t j=0;j<frame;j++)e+=(double)x[st+j]*x[st+j];double rdb=10*log10(e/frame+1e-20);
    d[0]=0;for(size_t t=1;t<=tmax;t++){double s=0;for(size_t j=0;j<W;j++){double q=y[st+j]-y[st+j+t];s+=q*q;}d[t]=s;}
    double cum=0;size_t best=0;double bv=1e9;
    for(size_t t=1;t<=tmax;t++){cum+=d[t];d[t]=cum>0?d[t]*t/cum:1;}
    for(size_t t=tmin;t<=tmax;t++){ if(d[t]<thresh){ while(t+1<=tmax&&d[t+1]<d[t])t++; best=t;bv=d[t];break; } }
    if(!best){for(size_t t=tmin;t<=tmax;t++)if(d[t]<bv){bv=d[t];best=t;}}
    double f0=0;
    if(best&&bv<thresh){double tau=best;if(best>tmin&&best<tmax){double a=d[best-1],b=d[best],c=d[best+1],den=a-2*b+c;if(den>0)tau=best+0.5*(a-c)/den;}f0=sr/tau;}
    for(size_t k=0;k<nfft;k++){buf[k].re=k<frame?x[st+k]*win[k]:0;buf[k].im=0;}
    av9_fft(buf,nfft,0);
    double tot=1e-20;for(uint32_t b=0;b<nbands;b++)bp[b]=1e-20;
    for(size_t k=1;k<nfft/2;k++){double hz=(double)k*sr/nfft;if(hz<edge[0]||hz>=edge[nbands])continue;
      double p=buf[k].re*buf[k].re+buf[k].im*buf[k].im;uint32_t b=(uint32_t)(nbands*log(hz/100.0)/log(3800.0/100.0));if(b>=nbands)b=nbands-1;bp[b]+=p;tot+=p;}
    fprintf(fo,"%.4f\t%.2f\t%.4f\t%.2f",(st+frame/2.0)/sr,f0,bv,rdb);
    for(uint32_t b=0;b<nbands;b++)fprintf(fo,"\t%.2f",10*log10(bp[b]/tot));
    fprintf(fo,"\n");frames++;
  }
  fclose(fo);free(x);free(y);free(d);free(win);free(edge);free(bp);free(buf);return frames;
}
/* av9_spatial_voice_mask_f32: per-voice-profile time-frequency mask ("raise this voice, push the rest down").
 * Architecture: Tom Dyer (voice-profile SLAM, 5 Nov 2026).  Coding: Claude (Opus 5.5).
 * frames_tsv lines: time_s<TAB>weight(0..1)<TAB>f0_hz   (from the strict matcher, profile's own pitch window)
 * shape_tsv lines:  hz<TAB>gain(0..1)                    (the profile's mean spectral shape, linear, max 1)
 * Per STFT frame (weights/f0 interpolated from the nearest frame row, weights smoothed over smooth_ms):
 *   H(f) = max over harmonics h of exp(-0.5*((f - h*f0)/width_hz)^2)     (0 when f0 = 0)
 *   G(f) = floor + (1-floor) * w * ((1-shape_mix)*H(f) + shape_mix*S(f)) ,  floor = 10^(floor_db/20)
 * Bins outside lo..hi get the floor.  sqrt-Hann STFT, overlap-add.  Returns 0 or -1. */
int32_t av9_spatial_voice_mask_f32(const char*in_path,const char*out_path,const char*frames_tsv,const char*shape_tsv,uint32_t sr,uint32_t fft_size,uint32_t hop,
    double floor_db,double width_hz,double smooth_ms,double lo_hz,double hi_hz,double shape_mix){
  g_error[0]='\0';
  if(!in_path||!out_path||!frames_tsv||!shape_tsv||sr<4000||!is_pow2_u32(fft_size)||fft_size<128||fft_size>4096||hop<1||hop>fft_size/2||!(floor_db<=0)||!(width_hz>0)||!(hi_hz>lo_hz)||!(shape_mix>=0&&shape_mix<=1)){seterr("invalid voice mask arguments");return -1;}
  /* frames */
  FILE*ft=fopen(frames_tsv,"r");if(!ft){seterr2("cannot open frames",frames_tsv);return -1;}
  size_t cap=1024,nr=0;double*ft_t=malloc(cap*sizeof(double)),*ft_w=malloc(cap*sizeof(double)),*ft_f=malloc(cap*sizeof(double));char line[256];
  while(fgets(line,sizeof line,ft)){double a,b,c;if(sscanf(line,"%lf\t%lf\t%lf",&a,&b,&c)!=3)continue;
    if(nr==cap){cap*=2;ft_t=realloc(ft_t,cap*sizeof(double));ft_w=realloc(ft_w,cap*sizeof(double));ft_f=realloc(ft_f,cap*sizeof(double));}
    ft_t[nr]=a;ft_w[nr]=b;ft_f[nr]=c;nr++;}
  fclose(ft);
  /* shape */
  FILE*fs=fopen(shape_tsv,"r");if(!fs){free(ft_t);free(ft_w);free(ft_f);seterr2("cannot open shape",shape_tsv);return -1;}
  double sh_hz[256],sh_g[256];int ns=0;while(fgets(line,sizeof line,fs)&&ns<256){double a,b;if(sscanf(line,"%lf\t%lf",&a,&b)==2){sh_hz[ns]=a;sh_g[ns]=b;ns++;}}
  fclose(fs);
  size_t n=0;float*x=read_f32(in_path,&n);if(!x){free(ft_t);free(ft_w);free(ft_f);return -1;}
  size_t nb=fft_size/2+1;long lead=(long)fft_size-(long)hop;
  double*win=malloc(fft_size*sizeof(double)),*acc=calloc(n+fft_size,sizeof(double)),*nrm=calloc(n+fft_size,sizeof(double)),*S=malloc(nb*sizeof(double));
  av9_cpx_t*buf=malloc(fft_size*sizeof(av9_cpx_t));
  if(!win||!acc||!nrm||!S||!buf){free(win);free(acc);free(nrm);free(S);free(buf);free(x);free(ft_t);free(ft_w);free(ft_f);seterr("allocation failed");return -1;}
  for(uint32_t k=0;k<fft_size;k++){double h=0.5-0.5*cos(2.0*M_PI*k/fft_size);win[k]=sqrt(h<0?0:h);}
  for(size_t k=0;k<nb;k++){double hz=(double)k*sr/fft_size,g=0;
    if(ns>0){if(hz<=sh_hz[0])g=sh_g[0];else if(hz>=sh_hz[ns-1])g=sh_g[ns-1];else for(int i=0;i+1<ns;i++)if(hz>=sh_hz[i]&&hz<sh_hz[i+1]){double u=(hz-sh_hz[i])/(sh_hz[i+1]-sh_hz[i]);g=sh_g[i]+u*(sh_g[i+1]-sh_g[i]);break;}}
    S[k]=g;}
  double fl=pow(10.0,floor_db/20.0);
  /* smoothed weight: moving average over smooth_ms of the frame weights */
  double fstep=nr>1?ft_t[1]-ft_t[0]:0.01;int sw=(int)(smooth_ms/1000.0/fstep/2+0.5);
  double*ws=malloc((nr?nr:1)*sizeof(double));
  for(size_t i=0;i<nr;i++){double a=0;int c=0;for(long j=(long)i-sw;j<=(long)i+sw;j++){if(j<0||j>=(long)nr)continue;a+=ft_w[j];c++;}ws[i]=c?a/c:0;}
  for(long st=-lead;st<(long)n;st+=(long)hop){
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;double v=(i>=0&&i<(long)n)?x[i]:0;buf[k].re=v*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);
    double tc=(st+fft_size/2.0)/sr;double w=0,f0=0;
    if(nr>0){long i=(long)floor((tc-ft_t[0])/fstep+0.5);if(i<0)i=0;if(i>=(long)nr)i=(long)nr-1;w=ws[i];
      f0=ft_f[i];if(f0<=0){for(long d=1;d<=3&&f0<=0;d++){if(i-d>=0&&ft_f[i-d]>0)f0=ft_f[i-d];else if(i+d<(long)nr&&ft_f[i+d]>0)f0=ft_f[i+d];}}}
    for(size_t k=0;k<nb;k++){double hz=(double)k*sr/fft_size,g=fl;
      if(hz>=lo_hz&&hz<=hi_hz&&w>0){double H=0;
        if(f0>0){double h=floor(hz/f0+0.5);if(h<1)h=1;double dlt=(hz-h*f0)/width_hz;H=exp(-0.5*dlt*dlt);}
        g=fl+(1-fl)*w*((1-shape_mix)*H+shape_mix*S[k]);}
      buf[k].re*=g;buf[k].im*=g;if(k>0&&k<fft_size/2){size_t j=fft_size-k;buf[j].re*=g;buf[j].im*=g;}}
    av9_fft(buf,fft_size,1);
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;if(i<0||i>=(long)n)continue;acc[i]+=buf[k].re*win[k];nrm[i]+=win[k]*win[k];}
  }
  FILE*fo=fopen(out_path,"wb");int bad=!fo;
  if(fo){for(size_t i=0;i<n;i++){float v=(float)(nrm[i]>1e-12?acc[i]/nrm[i]:0);if(fwrite(&v,sizeof(float),1,fo)!=1){bad=1;break;}}fclose(fo);}
  free(win);free(acc);free(nrm);free(S);free(buf);free(x);free(ft_t);free(ft_w);free(ft_f);free(ws);
  if(bad){seterr2("cannot write voice mask output",out_path);return -1;}
  return 0;
}
/* av9_spatial_harmonic_f0: pitch of ONE voice inside a pitch window, robust to a second overlapping voice.
 * Architecture: Tom Dyer (per-voice pitch windows, voice-profile SLAM, 5 Nov 2026).  Coding: Claude (Opus 5.5).
 * Per STFT frame (Hann, fft_size, hop), compressed magnitude m = |X|^0.3, linear interpolation between bins.
 * For each candidate f0 in [lo,hi] (step 0.5 Hz), harmonic contrast
 *   C(f0) = sum_{h=1..H, h*f0<fmax} 0.85^(h-1) * ( m(h*f0) - m((h+0.5)*f0) ) / sum 0.85^(h-1)
 * (energy on the harmonics minus energy half-way between them: a sub-harmonic of another voice only scores on
 * every second harmonic).  Output TSV: time_s  f0_hz  contrast  (contrast relative to the frame's mean m;
 * f0 = 0 when contrast < min_contrast).  Returns frame count or -1. */
int32_t av9_spatial_harmonic_f0(const char*in_path,const char*out_tsv,uint32_t sr,uint32_t fft_size,uint32_t hop,double lo_hz,double hi_hz,uint32_t nharm,double fmax_hz,double min_contrast){
  g_error[0]='\0';
  if(!in_path||!out_tsv||sr<4000||!is_pow2_u32(fft_size)||fft_size<256||fft_size>8192||hop<1||!(lo_hz>=40&&hi_hz>lo_hz&&hi_hz<1000)||nharm<2||nharm>60||!(fmax_hz>hi_hz)){seterr("invalid harmonic f0 arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  size_t nb=fft_size/2+1;double*win=malloc(fft_size*sizeof(double)),*m=malloc(nb*sizeof(double));av9_cpx_t*buf=malloc(fft_size*sizeof(av9_cpx_t));
  FILE*fo=fopen(out_tsv,"w");
  if(!win||!m||!buf||!fo){free(win);free(m);free(buf);free(x);if(fo)fclose(fo);seterr2("cannot create harmonic f0 output",out_tsv);return -1;}
  for(uint32_t k=0;k<fft_size;k++)win[k]=0.5-0.5*cos(2*M_PI*(double)k/(double)fft_size);
  fprintf(fo,"time_s\tf0_hz\tcontrast\n");
  double bw=(double)sr/fft_size;int32_t frames=0;
  for(size_t st=0;st+fft_size<=n;st+=hop){
    for(uint32_t k=0;k<fft_size;k++){buf[k].re=x[st+k]*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);
    double mean=0;size_t cnt=0;
    for(size_t k=0;k<nb;k++){m[k]=pow(buf[k].re*buf[k].re+buf[k].im*buf[k].im+1e-30,0.15);double hz=k*bw;if(hz>=lo_hz&&hz<=fmax_hz){mean+=m[k];cnt++;}}
    mean=cnt?mean/cnt:1e-9;if(mean<=0)mean=1e-9;
    double best=-1e9,bf=0;
    for(double f0=lo_hz;f0<=hi_hz;f0+=0.5){
      double num=0,den=0,wt=1;
      for(uint32_t h=1;h<=nharm;h++){double fh=h*f0,fm=(h+0.5)*f0;if(fm>=fmax_hz)break;
        double ph=fh/bw,pm=fm/bw;size_t ih=(size_t)ph,im=(size_t)pm;if(im+1>=nb)break;
        double vh=m[ih]+(ph-ih)*(m[ih+1]-m[ih]),vm=m[im]+(pm-im)*(m[im+1]-m[im]);
        num+=wt*(vh-vm);den+=wt;wt*=0.85;}
      if(den>0){double c=num/den;if(c>best){best=c;bf=f0;}}
    }
    double rel=best/mean;double f0=rel>=min_contrast?bf:0;
    fprintf(fo,"%.4f\t%.2f\t%.4f\n",(st+fft_size/2.0)/sr,f0,rel);frames++;
  }
  fclose(fo);free(win);free(m);free(buf);free(x);return frames;
}
/* av9_spatial_voice_mask_union_f32: union of several voice-profile masks ("combine Tom and Tam").
 * Architecture: Tom Dyer (5 Nov 2026: TV male + TV female renders combined are extremely audible).
 * Coding: Claude (Opus 5.5).
 * list_tsv: one frames TSV path per line (time_s weight f0 [contrast]), up to 16 profiles.
 * Per STFT bin: G = floor + (1-floor) * max over profiles i of w_i * H_i(f), H_i the harmonic comb of profile i's
 * tracked pitch (Gaussian lobes of width_hz).  Unlike summing renders, the background stays at the floor.
 * Returns 0 or -1. */
int32_t av9_spatial_voice_mask_union_f32(const char*in_path,const char*out_path,const char*list_tsv,uint32_t sr,uint32_t fft_size,uint32_t hop,
    double floor_db,double width_hz,double smooth_ms,double lo_hz,double hi_hz){
  g_error[0]='\0';
  if(!in_path||!out_path||!list_tsv||sr<4000||!is_pow2_u32(fft_size)||fft_size<128||fft_size>4096||hop<1||hop>fft_size/2||!(floor_db<=0)||!(width_hz>0)||!(hi_hz>lo_hz)){seterr("invalid union mask arguments");return -1;}
  FILE*fl_=fopen(list_tsv,"r");if(!fl_){seterr2("cannot open list",list_tsv);return -1;}
  char path[1024];int P=0;double*T[16],*Wt[16],*F0[16];size_t NR[16];char line[256];
  while(P<16&&fgets(path,sizeof path,fl_)){size_t L=strlen(path);while(L&&(path[L-1]=='\n'||path[L-1]=='\r'))path[--L]=0;if(!L)continue;
    FILE*ft=fopen(path,"r");if(!ft)continue;size_t cap=1024,nr=0;double*t=malloc(cap*sizeof(double)),*w=malloc(cap*sizeof(double)),*f=malloc(cap*sizeof(double));
    while(fgets(line,sizeof line,ft)){double a,b,c;if(sscanf(line,"%lf\t%lf\t%lf",&a,&b,&c)!=3)continue;if(nr==cap){cap*=2;t=realloc(t,cap*sizeof(double));w=realloc(w,cap*sizeof(double));f=realloc(f,cap*sizeof(double));}t[nr]=a;w[nr]=b;f[nr]=c;nr++;}
    fclose(ft);
    /* smooth weights */
    double step=nr>1?t[1]-t[0]:0.01;int sw=(int)(smooth_ms/1000.0/step/2+0.5);double*ws=malloc((nr?nr:1)*sizeof(double));
    for(size_t i=0;i<nr;i++){double s=0;int c=0;for(long j=(long)i-sw;j<=(long)i+sw;j++){if(j<0||j>=(long)nr)continue;s+=w[j];c++;}ws[i]=c?s/c:0;}
    free(w);T[P]=t;Wt[P]=ws;F0[P]=f;NR[P]=nr;P++;}
  fclose(fl_);if(P<1){seterr("no frames files in list");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x){for(int i=0;i<P;i++){free(T[i]);free(Wt[i]);free(F0[i]);}return -1;}
  size_t nb=fft_size/2+1;long lead=(long)fft_size-(long)hop;
  double*win=malloc(fft_size*sizeof(double)),*acc=calloc(n+fft_size,sizeof(double)),*nrm=calloc(n+fft_size,sizeof(double));av9_cpx_t*buf=malloc(fft_size*sizeof(av9_cpx_t));
  if(!win||!acc||!nrm||!buf){free(win);free(acc);free(nrm);free(buf);free(x);for(int i=0;i<P;i++){free(T[i]);free(Wt[i]);free(F0[i]);}seterr("allocation failed");return -1;}
  for(uint32_t k=0;k<fft_size;k++){double h=0.5-0.5*cos(2.0*M_PI*k/fft_size);win[k]=sqrt(h<0?0:h);}
  double fl=pow(10.0,floor_db/20.0);
  for(long st=-lead;st<(long)n;st+=(long)hop){
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;double v=(i>=0&&i<(long)n)?x[i]:0;buf[k].re=v*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);
    double tc=(st+fft_size/2.0)/sr;double wv[16],fv[16];
    for(int p=0;p<P;p++){wv[p]=0;fv[p]=0;if(!NR[p])continue;double step=NR[p]>1?T[p][1]-T[p][0]:0.01;long i=(long)floor((tc-T[p][0])/step+0.5);if(i<0)i=0;if(i>=(long)NR[p])i=(long)NR[p]-1;
      wv[p]=Wt[p][i];fv[p]=F0[p][i];if(fv[p]<=0){for(long d=1;d<=3&&fv[p]<=0;d++){if(i-d>=0&&F0[p][i-d]>0)fv[p]=F0[p][i-d];else if(i+d<(long)NR[p]&&F0[p][i+d]>0)fv[p]=F0[p][i+d];}}}
    for(size_t k=0;k<nb;k++){double hz=(double)k*sr/fft_size,best=0;
      if(hz>=lo_hz&&hz<=hi_hz)for(int p=0;p<P;p++){if(wv[p]<=0||fv[p]<=0)continue;double h=floor(hz/fv[p]+0.5);if(h<1)h=1;double d=(hz-h*fv[p])/width_hz;double v=wv[p]*exp(-0.5*d*d);if(v>best)best=v;}
      double g=fl+(1-fl)*best;buf[k].re*=g;buf[k].im*=g;if(k>0&&k<fft_size/2){size_t j=fft_size-k;buf[j].re*=g;buf[j].im*=g;}}
    av9_fft(buf,fft_size,1);
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;if(i<0||i>=(long)n)continue;acc[i]+=buf[k].re*win[k];nrm[i]+=win[k]*win[k];}
  }
  FILE*fo=fopen(out_path,"wb");int bad=!fo;
  if(fo){for(size_t i=0;i<n;i++){float v=(float)(nrm[i]>1e-12?acc[i]/nrm[i]:0);if(fwrite(&v,sizeof(float),1,fo)!=1){bad=1;break;}}fclose(fo);}
  free(win);free(acc);free(nrm);free(buf);free(x);for(int i=0;i<P;i++){free(T[i]);free(Wt[i]);free(F0[i]);}
  if(bad){seterr2("cannot write union mask output",out_path);return -1;}
  return 0;
}
/* av9_spatial_spectral_smooth_f32: smooth the jagged time-frequency shape a hard voice mask leaves, for
 * comprehension listening ("someone talking through a fan").
 * Architecture: Tom Dyer (6 Nov 2026: add a smoother; aggressive channel cuts leave a jagged shape; loss at 8k).
 * Coding: Claude (Opus 5.5).
 * sqrt-Hann STFT, overlap-add.  Per bin a held envelope: hold = max(|X|, hold * decay), decay giving a 20 dB fall
 * over release_ms, so one-frame drop-outs (a comb tooth switching off and on) are filled instead of chopped.
 * The held envelope is spread across +-freq_bins neighbours at -3 dB per bin (widens the narrow comb teeth).
 * Each bin is raised toward that envelope, never by more than max_fill_db, keeping its own phase.
 * Bandwidth (bwe_db < 0, sr >= 16000): bins from 4 kHz to 0.9 x Nyquist are rebuilt from 2.0-3.6 kHz (frequency
 * translation, repeating every 1.6 kHz) at bwe_db at 4 kHz falling 6 dB per kHz; an 8 kHz-rate source has nothing
 * there.  bwe_db >= 0: no bandwidth extension.  Returns frames processed or -1. */
int32_t av9_spatial_spectral_smooth_f32(const char*in_path,const char*out_path,uint32_t sr,uint32_t fft_size,uint32_t hop,
    double release_ms,uint32_t freq_bins,double max_fill_db,double bwe_db){
  g_error[0]='\0';
  if(!in_path||!out_path||sr<4000||!is_pow2_u32(fft_size)||fft_size<128||fft_size>4096||hop<1||hop>fft_size/2||!(release_ms>0)||freq_bins>16||max_fill_db<0||max_fill_db>40){seterr("invalid spectral smooth arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  size_t nb=fft_size/2+1;long lead=(long)fft_size-(long)hop;
  double*win=malloc(fft_size*sizeof(double));av9_cpx_t*buf=malloc(fft_size*sizeof(av9_cpx_t));av9_cpx_t*src=malloc(nb*sizeof(av9_cpx_t));
  double*acc=calloc(n+fft_size,sizeof(double)),*nrm=calloc(n+fft_size,sizeof(double));
  double*mag=malloc(nb*sizeof(double)),*hold=calloc(nb,sizeof(double)),*env=malloc(nb*sizeof(double));
  if(!win||!buf||!src||!acc||!nrm||!mag||!hold||!env){free(win);free(buf);free(src);free(acc);free(nrm);free(mag);free(hold);free(env);free(x);seterr("allocation failed");return -1;}
  for(uint32_t k=0;k<fft_size;k++){double h=0.5-0.5*cos(2.0*M_PI*k/fft_size);win[k]=sqrt(h<0?0:h);}
  double hop_ms=1000.0*hop/sr,decay=pow(10.0,-20.0/20.0*hop_ms/release_ms),fill=pow(10.0,max_fill_db/20.0),spread=pow(10.0,-3.0/20.0);
  int bwe=(bwe_db<0&&sr>=16000);size_t kb0=(size_t)ceil(4000.0*fft_size/sr),kb1=(size_t)floor(0.9*0.5*sr*fft_size/sr);if(kb1>=nb)kb1=nb-1;
  int32_t frames=0;
  for(long st=-lead;st<(long)n;st+=(long)hop){
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;double v=(i>=0&&i<(long)n)?x[i]:0;buf[k].re=v*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);
    for(size_t k=0;k<nb;k++){mag[k]=sqrt(buf[k].re*buf[k].re+buf[k].im*buf[k].im);double hd=hold[k]*decay;hold[k]=mag[k]>hd?mag[k]:hd;}
    for(size_t k=0;k<nb;k++){double e=hold[k],w=1.0;for(uint32_t j=1;j<=freq_bins;j++){w*=spread;if(k>=j&&hold[k-j]*w>e)e=hold[k-j]*w;if(k+j<nb&&hold[k+j]*w>e)e=hold[k+j]*w;}env[k]=e;}
    for(size_t k=0;k<nb;k++){
      if(bwe&&k>=kb0&&k<=kb1)continue;
      double tgt=env[k],cap=mag[k]*fill;if(tgt>cap)tgt=cap;
      if(mag[k]>1e-12&&tgt>mag[k]){double g=tgt/mag[k];buf[k].re*=g;buf[k].im*=g;}
    }
    if(bwe){
      for(size_t k=0;k<nb;k++)src[k]=buf[k];
      for(size_t k=kb0;k<=kb1;k++){
        double fk=(double)k*sr/fft_size,fs=2000.0+fmod(fk-4000.0,1600.0);size_t ks=(size_t)(fs*fft_size/sr+0.5);if(ks>=nb)ks=nb-1;
        double g=pow(10.0,(bwe_db-6.0*(fk-4000.0)/1000.0)/20.0);buf[k].re=src[ks].re*g;buf[k].im=src[ks].im*g;
      }
      for(size_t k=kb1+1;k<nb;k++){buf[k].re=0;buf[k].im=0;}
    }
    for(size_t k=1;k+1<nb;k++){buf[fft_size-k].re=buf[k].re;buf[fft_size-k].im=-buf[k].im;}
    av9_fft(buf,fft_size,1);
    for(uint32_t k=0;k<fft_size;k++){long i=st+(long)k;if(i<0||i>=(long)n)continue;acc[i]+=buf[k].re*win[k];nrm[i]+=win[k]*win[k];}
    frames++;
  }
  FILE*fo=fopen(out_path,"wb");int bad=!fo;
  if(fo){for(size_t i=0;i<n;i++){float v=(float)(nrm[i]>1e-12?acc[i]/nrm[i]:x[i]);if(fwrite(&v,sizeof(float),1,fo)!=1){bad=1;break;}}fclose(fo);}
  free(win);free(buf);free(src);free(acc);free(nrm);free(mag);free(hold);free(env);free(x);
  if(bad){seterr2("cannot write spectral smooth output",out_path);return -1;}
  return frames;
}
/* av9_spatial_multi_f0_f32: several simultaneous pitches per frame, for overlapping speakers.
 * Architecture: Tom Dyer (6 Nov 2026: pattern sets for multi-person calls; a pattern is pitch and pulse).
 * Coding: Claude (Opus 5.5).  Method: iterative estimation and cancellation (after Klapuri 2006, simplified).
 * Per frame (Hann, fft_size, hop): magnitude spectrum, whitened by its own +-150 Hz moving average (so loud low
 * bins do not dominate); salience of a candidate f0 (1/48-octave grid, f_min..f_max) = sum over h=1..n_harm of
 * g(h) x the largest whitened magnitude within +-1.5 % of h*f0 (at least one bin), g = (f0+20)/(h*f0+320).
 * Pick the most salient f0; strength = salience / (sum of g x the residual's median), i.e. how far its harmonic
 * peaks stand above the noise floor; it is a voice when strength >= min_ratio and (later picks) salience >=
 * rel_floor x the first pick's.  Then cancel it: every bin within +-3 % (plus the 2-bin Hann main lobe) of each
 * of its harmonics is set to the residual's median, so its harmonics (and its subharmonic ghosts) cannot
 * be picked again; candidates within 3 % of 1/3, 1/2, 1, 2 or 3 times a chosen f0 are also refused.
 * Up to max_voices per frame.  Output TSV: t_s, then per voice f0_hz and strength (peaks over noise floor),
 * strongest first; 0 0 pads the unused slots.  Returns frames written or -1. */
static int av9_cmp_dbl(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}
int32_t av9_spatial_multi_f0_f32(const char*in_path,const char*out_tsv,uint32_t sr,uint32_t fft_size,uint32_t hop,
    double f_min,double f_max,uint32_t n_harm,uint32_t max_voices,double min_ratio,double rel_floor){
  g_error[0]='\0';
  if(!in_path||!out_tsv||sr<4000||!is_pow2_u32(fft_size)||fft_size<256||fft_size>8192||hop<1||hop>fft_size||!(f_min>=40)||!(f_max>f_min)||f_max>=sr/4.0||n_harm<1||n_harm>40||max_voices<1||max_voices>8||!(min_ratio>0)||rel_floor<0||rel_floor>1){seterr("invalid multi f0 arguments");return -1;}
  size_t n=0;float*x=read_f32(in_path,&n);if(!x)return -1;
  size_t nb=fft_size/2+1;double bin=(double)sr/fft_size;
  size_t nc=(size_t)floor(48.0*log2(f_max/f_min))+1;
  double*win=malloc(fft_size*sizeof(double));av9_cpx_t*buf=malloc(fft_size*sizeof(av9_cpx_t));
  double*mag=malloc(nb*sizeof(double)),*res=malloc(nb*sizeof(double)),*cum=malloc((nb+1)*sizeof(double)),*tmp=malloc(nb*sizeof(double));
  double*cf=malloc(nc*sizeof(double)),*sal=malloc(nc*sizeof(double)),*srt=malloc(nc*sizeof(double));
  double*vf=malloc(max_voices*sizeof(double)),*vs=malloc(max_voices*sizeof(double));
  FILE*fo=fopen(out_tsv,"w");
  if(!win||!buf||!mag||!res||!cum||!tmp||!cf||!sal||!srt||!vf||!vs||!fo){if(fo)fclose(fo);free(win);free(buf);free(mag);free(res);free(cum);free(tmp);free(cf);free(sal);free(srt);free(vf);free(vs);free(x);seterr2("multi f0: allocation or open failed",out_tsv);return -1;}
  for(uint32_t k=0;k<fft_size;k++)win[k]=0.5-0.5*cos(2.0*M_PI*k/fft_size);
  for(size_t c=0;c<nc;c++)cf[c]=f_min*pow(2.0,(double)c/48.0);
  long half=(long)(150.0/bin+0.5);if(half<1)half=1;
  fprintf(fo,"t_s");for(uint32_t v=0;v<max_voices;v++)fprintf(fo,"\tf0_%u\tstrength_%u",v+1,v+1);fprintf(fo,"\n");
  int32_t frames=0;
  for(size_t st=0;st+fft_size<=n;st+=hop){
    for(uint32_t k=0;k<fft_size;k++){buf[k].re=x[st+k]*win[k];buf[k].im=0;}
    av9_fft(buf,fft_size,0);
    for(size_t k=0;k<nb;k++)mag[k]=sqrt(buf[k].re*buf[k].re+buf[k].im*buf[k].im);
    cum[0]=0;for(size_t k=0;k<nb;k++)cum[k+1]=cum[k]+mag[k];
    for(size_t k=0;k<nb;k++){long a=(long)k-half,b=(long)k+half;if(a<0){a=0;} if(b>(long)nb-1){b=(long)nb-1;}double m=(cum[b+1]-cum[a])/(double)(b-a+1);res[k]=m>1e-12?mag[k]/m:0;}
    uint32_t nv=0;double first=0;
    for(uint32_t it=0;it<max_voices;it++){
      for(size_t c=0;c<nc;c++){
        double f0=cf[c],s=0;
        for(uint32_t h=1;h<=n_harm;h++){double fh=h*f0;if(fh>0.95*sr/2)break;
          long a=(long)floor(fh*0.985/bin),b=(long)ceil(fh*1.015/bin);if(b-a<2){long k0=(long)(fh/bin+0.5);a=k0-1;b=k0+1;}
          if(a<0){a=0;} if(b>(long)nb-1){b=(long)nb-1;}double mx=0;for(long k=a;k<=b;k++)if(res[k]>mx)mx=res[k];
          s+=(f0+20.0)/(h*f0+320.0)*mx;}
        for(uint32_t v=0;v<nv;v++){double r=f0/vf[v];if(fabs(r-1)<0.03||fabs(r-2)<0.06||fabs(r-3)<0.09||fabs(r*2-1)<0.03||fabs(r*3-1)<0.03){s=0;break;}}
        sal[c]=s;
      }
      /* strength: the pick's harmonic peaks against the residual's noise floor (median), so a busy spectrum with
         several voices does not raise the bar the way a grid median does */
      memcpy(tmp,res,nb*sizeof(double));qsort(tmp,nb,sizeof(double),av9_cmp_dbl);double floor0=tmp[nb/2];
      size_t bc=0;for(size_t c=1;c<nc;c++)if(sal[c]>sal[bc])bc=c;
      double gsum=0;for(uint32_t h=1;h<=n_harm;h++){if(h*cf[bc]>0.95*sr/2)break;gsum+=(cf[bc]+20.0)/(h*cf[bc]+320.0);}
      double strength=(floor0>1e-12&&gsum>0)?sal[bc]/(gsum*floor0):0;
      if(it==0){if(strength<min_ratio)break;first=sal[bc];}
      else if(sal[bc]<rel_floor*first||strength<min_ratio)break;
      vf[nv]=cf[bc];vs[nv]=strength;nv++;
      /* cancel its harmonics: bins set to the residual's median */
      double rmed=floor0;
      for(uint32_t h=1;h<=n_harm;h++){double fh=h*cf[bc];if(fh>0.95*sr/2)break;
        long a=(long)floor(fh*0.97/bin)-2,b=(long)ceil(fh*1.03/bin)+2;   /* +-3 % plus the Hann main lobe (2 bins) */
        if(a<0){a=0;} if(b>(long)nb-1){b=(long)nb-1;}for(long k=a;k<=b;k++)if(res[k]>rmed)res[k]=rmed;}
    }
    fprintf(fo,"%.3f",(st+fft_size/2.0)/sr);
    for(uint32_t v=0;v<max_voices;v++){if(v<nv)fprintf(fo,"\t%.1f\t%.2f",vf[v],vs[v]);else fprintf(fo,"\t0\t0");}
    fprintf(fo,"\n");frames++;
  }
  fclose(fo);free(win);free(buf);free(mag);free(res);free(cum);free(tmp);free(cf);free(sal);free(srt);free(vf);free(vs);free(x);
  return frames;
}
