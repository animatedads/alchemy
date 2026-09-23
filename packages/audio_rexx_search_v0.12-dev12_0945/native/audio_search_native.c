#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include <stddef.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#define EPS 1e-12
#define TWEAKS 7
#define MAX_REJECT_BANDS 6
#define MAX_REFERENCE_FILES 32
static const int tweak_ms[TWEAKS] = {-20,-10,-5,0,5,10,20};
void as_context_free(void *v);

typedef struct {
    uint32_t sr;
    uint64_t n;
    float *x;
} ASAudio;

typedef struct {
    double global_center[10], global_scale[10];
    double temporal_center[5], temporal_scale[5];
    double window_center[2], window_scale[2];
    double *ref_windows; /* pairs: rms_db,zcr */
    uint64_t ref_window_count;
} ASProfile;

typedef struct {
    ASAudio *source;
    ASAudio *companion;
    ASAudio **refs;
    size_t ref_count;
    ASProfile profile;
    double align_offset_sec;
    double align_drift_ppm;
    double align_correlation;
    float *shared[TWEAKS];
    double shared_alpha[TWEAKS];
    double shared_corr[TWEAKS];
} ASContext;

typedef struct {
    double gain_db;
    double highpass_hz;
    double lowpass_hz;
    double denoise_floor_db; /* 999 means disabled */
    double echo_delay_ms;
    double echo_gain;
    double cancel_strength;
    int32_t cancel_tweak_ms;
    int32_t compress;
    double compress_ratio;
    double compress_threshold_db;
    int32_t reject_band_count;
    int32_t reject_reserved;
    double reject_band_hz[MAX_REJECT_BANDS * 2]; /* interleaved low,high Hz */
} ASParams;

_Static_assert(offsetof(ASParams, reject_band_count) == 80, "ASParams reject_band_count ABI offset");
_Static_assert(offsetof(ASParams, reject_band_hz) == 88, "ASParams reject_band_hz ABI offset");
_Static_assert(sizeof(ASParams) == 184, "ASParams ABI size");

typedef struct {
    double global_distance;
    double window_median_distance;
    double window_p25_distance;
    double temporal_distance;
    double silence_fraction;
    double post_limiter_clip_fraction;
    double pre_limiter_over_fraction;
    double pre_filter_peak;
    uint64_t pcm_hash64;
} ASStats;

typedef struct {
    double offset_sec;
    double drift_ppm;
    double correlation;
    double offset_min_sec;
    double offset_max_sec;
    double nominal_offset_sec;
} ASAlignment;

static uint16_t rd16(const unsigned char *p){ return (uint16_t)p[0] | ((uint16_t)p[1]<<8); }
static uint32_t rd32(const unsigned char *p){ return (uint32_t)p[0] | ((uint32_t)p[1]<<8) | ((uint32_t)p[2]<<16) | ((uint32_t)p[3]<<24); }
static void wr16(FILE *f, uint16_t v){ unsigned char b[2]={(unsigned char)v,(unsigned char)(v>>8)}; fwrite(b,1,2,f); }
static void wr32(FILE *f, uint32_t v){ unsigned char b[4]={(unsigned char)v,(unsigned char)(v>>8),(unsigned char)(v>>16),(unsigned char)(v>>24)}; fwrite(b,1,4,f); }

static ASAudio *audio_new(uint32_t sr, uint64_t n){
    ASAudio *a=(ASAudio*)calloc(1,sizeof(*a)); if(!a) return NULL;
    a->sr=sr; a->n=n; a->x=(float*)calloc((size_t)n,sizeof(float));
    if(!a->x){free(a);return NULL;} return a;
}
static void audio_destroy(ASAudio *a){ if(a){ free(a->x); free(a);} }

static ASAudio *load_pcm16_wav(const char *path){
    FILE *f=fopen(path,"rb"); if(!f) return NULL;
    unsigned char h[12]; if(fread(h,1,12,f)!=12 || memcmp(h,"RIFF",4) || memcmp(h+8,"WAVE",4)){fclose(f);errno=EINVAL;return NULL;}
    uint16_t fmt=0,ch=0,bits=0; uint32_t sr=0; unsigned char *data=NULL; uint32_t data_len=0;
    while(!feof(f)){
        unsigned char c[8]; if(fread(c,1,8,f)!=8) break; uint32_t len=rd32(c+4);
        if(!memcmp(c,"fmt ",4)){
            unsigned char *b=(unsigned char*)malloc(len); if(!b){fclose(f);return NULL;}
            if(fread(b,1,len,f)!=len){free(b);break;}
            if(len>=16){fmt=rd16(b);ch=rd16(b+2);sr=rd32(b+4);bits=rd16(b+14);} free(b);
        } else if(!memcmp(c,"data",4)){
            data=(unsigned char*)malloc(len); if(!data){fclose(f);return NULL;}
            if(fread(data,1,len,f)!=len){free(data);data=NULL;break;} data_len=len;
        } else { if(fseek(f,(long)len,SEEK_CUR)!=0) break; }
        if(len&1) fseek(f,1,SEEK_CUR);
        if(data && fmt) break;
    }
    fclose(f);
    if(!data || fmt!=1 || ch!=1 || bits!=16 || sr==0){free(data);errno=EINVAL;return NULL;}
    uint64_t n=data_len/2; ASAudio *a=audio_new(sr,n); if(!a){free(data);return NULL;}
    for(uint64_t i=0;i<n;i++){ int16_t s=(int16_t)rd16(data+2*i); a->x[i]=(float)((double)s/32768.0); }
    free(data); return a;
}

static int write_pcm16_wav(const ASAudio *a,const char *path){
    FILE *f=fopen(path,"wb"); if(!f) return -1; uint64_t bytes64=a->n*2; if(bytes64>0xffffffffu-36u){fclose(f);errno=EFBIG;return -1;} uint32_t data=(uint32_t)bytes64;
    fwrite("RIFF",1,4,f); wr32(f,36+data); fwrite("WAVEfmt ",1,8,f); wr32(f,16); wr16(f,1); wr16(f,1); wr32(f,a->sr); wr32(f,a->sr*2); wr16(f,2); wr16(f,16); fwrite("data",1,4,f); wr32(f,data);
    for(uint64_t i=0;i<a->n;i++){ double v=a->x[i]; if(v>1)v=1;if(v<-1)v=-1; long q=lround(v*32767.0); if(q>32767)q=32767;if(q<-32768)q=-32768; wr16(f,(uint16_t)(int16_t)q); }
    int rc=ferror(f)?-1:0; fclose(f); return rc;
}

typedef struct { double b0,b1,b2,a1,a2,z1,z2; } Biquad;
static Biquad bq_make(int highpass,double hz,double sr){
    double w=2*M_PI*hz/sr, c=cos(w), s=sin(w), q=sqrt(0.5), alpha=s/(2*q), a0=1+alpha;
    Biquad b={0};
    if(highpass){ b.b0=(1+c)/2/a0; b.b1=-(1+c)/a0; b.b2=(1+c)/2/a0; }
    else { b.b0=(1-c)/2/a0; b.b1=(1-c)/a0; b.b2=(1-c)/2/a0; }
    b.a1=-2*c/a0; b.a2=(1-alpha)/a0; return b;
}
static inline float bq_run(Biquad *b,float x){ double y=b->b0*x+b->z1; b->z1=b->b1*x-b->a1*y+b->z2; b->z2=b->b2*x-b->a2*y; return (float)y; }
static Biquad bq_notch(double lo,double hi,double sr){
    double f0=sqrt(lo*hi), bw=hi-lo, q=f0/fmax(bw,1.0);
    if(q<0.15) q=0.15;
    if(q>80) q=80;
    double w=2*M_PI*f0/sr, c=cos(w), alpha=sin(w)/(2*q), a0=1+alpha;
    Biquad b={0}; b.b0=1/a0; b.b1=-2*c/a0; b.b2=1/a0; b.a1=-2*c/a0; b.a2=(1-alpha)/a0; return b;
}
static void apply_filter(float *x,uint64_t n,uint32_t sr,double hp,double lp){
    if(hp>0 && hp<sr*.48){ Biquad a=bq_make(1,hp,sr),b=bq_make(1,hp,sr); for(uint64_t i=0;i<n;i++){x[i]=bq_run(&a,x[i]);x[i]=bq_run(&b,x[i]);}}
    if(lp>0 && lp<sr*.48){ Biquad a=bq_make(0,lp,sr),b=bq_make(0,lp,sr); for(uint64_t i=0;i<n;i++){x[i]=bq_run(&a,x[i]);x[i]=bq_run(&b,x[i]);}}
}
static int apply_reject_bands(float *x,uint64_t n,uint32_t sr,const ASParams *p){
    int count=p->reject_band_count;
    if(count<0) count=0;
    if(count>MAX_REJECT_BANDS) count=MAX_REJECT_BANDS;
    if(count==0 || n==0) return 0;
    const double nyquist=sr*.5;
    for(int band=0;band<count;band++){
        double lo=p->reject_band_hz[2*band], hi=p->reject_band_hz[2*band+1];
        if(lo<0) lo=0;
        if(hi>nyquist) hi=nyquist;
        if(hi<=lo || hi<=0 || lo>=nyquist) continue;
        if(lo<=0){
            apply_filter(x,n,sr,hi,0);
            continue;
        }
        if(hi>=sr*.48){
            apply_filter(x,n,sr,0,lo);
            continue;
        }
        /* Three identical RBJ band-stop sections give a deep rejected region
           while preserving both sides of the band. Q is derived from the
           requested LOW-HIGH width, so narrow bands behave like notches and
           broad bands behave as broad rejection regions. */
        Biquad a=bq_notch(lo,hi,sr), b=bq_notch(lo,hi,sr), c=bq_notch(lo,hi,sr);
        for(uint64_t i=0;i<n;i++){ x[i]=bq_run(&a,x[i]); x[i]=bq_run(&b,x[i]); x[i]=bq_run(&c,x[i]); }
    }
    return 0;
}
static double rms_range(const float *x,uint64_t n){ long double s=0; for(uint64_t i=0;i<n;i++)s+=(long double)x[i]*x[i]; return sqrt((double)(s/(n?n:1))+EPS); }
static int cmpd(const void *a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y?1:0;}
static double percentile_copy(const double *x,uint64_t n,double p){ if(!n)return 0; double *q=malloc(n*sizeof(double)); if(!q)return 0; memcpy(q,x,n*sizeof(double));qsort(q,n,sizeof(double),cmpd);double pos=p*(n-1);uint64_t i=(uint64_t)floor(pos),j=(uint64_t)ceil(pos);double v=q[i]+(q[j]-q[i])*(pos-i);free(q);return v; }
static double median_copy(const double*x,uint64_t n){return percentile_copy(x,n,.5);}

static void apply_noise_gate(float *x,uint64_t n,uint32_t sr,double floor_db){
    if(floor_db>100 || n==0) return;
    uint64_t frame=(uint64_t)(sr*.02);
    if(frame<64) frame=64;
    uint64_t m=(n+frame-1)/frame;
    double *r=malloc(m*sizeof(double));
    if(!r) return;
    for(uint64_t k=0;k<m;k++){uint64_t s=k*frame,e=s+frame;if(e>n)e=n;r[k]=rms_range(x+s,e-s);} double noise=percentile_copy(r,m,.25); double min_gain=pow(10.0,floor_db/20.0); double prev=1.0;
    for(uint64_t k=0;k<m;k++){ double target=(r[k]<=noise*1.05)?min_gain:fmax(min_gain,1.0-noise/(r[k]+EPS)); double g=.85*prev+.15*target; prev=g; uint64_t s=k*frame,e=s+frame;if(e>n)e=n;for(uint64_t i=s;i<e;i++)x[i]=(float)(x[i]*g); }
    free(r);
}
static void apply_echo(float *x,uint64_t n,uint32_t sr,double delay_ms,double gain){ if(fabs(gain)<1e-12||delay_ms<=0)return; uint64_t d=(uint64_t)llround(sr*delay_ms/1000.0);if(d<1||d>=n)return; float *orig=malloc(n*sizeof(float));if(!orig)return;memcpy(orig,x,n*sizeof(float));for(uint64_t i=d;i<n;i++)x[i]=(float)(x[i]+gain*orig[i-d]);free(orig); }
static void apply_compressor(float*x,uint64_t n,double threshold_db,double ratio){ if(ratio<=1)return; double th=pow(10.0,threshold_db/20.0);for(uint64_t i=0;i<n;i++){double v=x[i],a=fabs(v);if(a>th)x[i]=(float)(copysign(th+(a-th)/ratio,v));}}
static void apply_limiter(float*x,uint64_t n){const double t=.88,c=.98,span=.10;for(uint64_t i=0;i<n;i++){double v=x[i],a=fabs(v);if(a>t)v=copysign(t+span*tanh((a-t)/span),v);if(v>c)v=c;if(v<-c)v=-c;x[i]=(float)v;}}

static void basic_window(const float*x,uint64_t n,double *rmsdb,double*zcr){double r=rms_range(x,n);*rmsdb=20*log10(r+EPS);uint64_t z=0;for(uint64_t i=1;i<n;i++)if((x[i]<0)!=(x[i-1]<0))z++;*zcr=n>1?(double)z/(n-1):0;}

static void global_features(const ASAudio*a,double out[10]){
    uint64_t n=a->n; double rms=rms_range(a->x,n),peak=0;uint64_t z=0;for(uint64_t i=0;i<n;i++){double q=fabs(a->x[i]);if(q>peak)peak=q;if(i&&(a->x[i]<0)!=(a->x[i-1]<0))z++;}
    out[0]=20*log10(rms+EPS);out[1]=20*log10(peak+EPS);out[2]=n>1?(double)z/(n-1):0;
    const double lo[3]={70,300,1200},hi[3]={300,1200,4000};double e[3]={0},total=0;for(uint64_t i=0;i<n;i++)total+=(double)a->x[i]*a->x[i];
    for(int b=0;b<3;b++){float *t=malloc(n*sizeof(float));if(!t)continue;memcpy(t,a->x,n*sizeof(float));apply_filter(t,n,a->sr,lo[b],hi[b]);for(uint64_t i=0;i<n;i++)e[b]+=(double)t[i]*t[i];free(t);} total+=EPS;for(int b=0;b<3;b++)e[b]/=total;
    double sum=e[0]+e[1]+e[2]+EPS,centers[3]={185,750,2600};double cen=0;for(int b=0;b<3;b++)cen+=centers[b]*e[b];cen/=sum;double bw=0;for(int b=0;b<3;b++){double d=centers[b]-cen;bw+=d*d*e[b];}bw=sqrt(bw/sum);
    out[3]=cen;out[4]=bw;double cum=0,roll=4000;for(int b=0;b<3;b++){cum+=e[b]/sum;if(cum>=.85){roll=centers[b];break;}}out[5]=roll;out[6]=pow(fmax(e[0],EPS)*fmax(e[1],EPS)*fmax(e[2],EPS),1.0/3.0)/(sum/3.0+EPS);out[7]=e[0];out[8]=e[1];out[9]=e[2];
}
static void temporal_features(const ASAudio*a,double out[5]){
    uint64_t frame=(uint64_t)llround(a->sr*.1);if(frame<64)frame=64;uint64_t m=a->n/frame;if(m<4){memset(out,0,5*sizeof(double));return;}double *env=NULL;double *db=NULL;env=malloc(m*sizeof(double));db=malloc(m*sizeof(double));if(!env||!db){free(env);free(db);memset(out,0,5*sizeof(double));return;}
    for(uint64_t k=0;k<m;k++){env[k]=rms_range(a->x+k*frame,frame);db[k]=20*log10(env[k]+EPS);}double med=median_copy(db,m),thr=fmax(-58.0,med+4.0);uint8_t *act=malloc(m);double *ar=malloc(m*sizeof(double)),*gr=malloc(m*sizeof(double));uint64_t na=0,ng=0,run=0;int state=-1;uint64_t active=0;
    for(uint64_t k=0;k<m;k++){int v=db[k]>=thr;active+=v;if(state<0){state=v;run=1;}else if(v==state)run++;else{if(state)ar[na++]=run*.1;else gr[ng++]=run*.1;state=v;run=1;}if(act)act[k]=(uint8_t)v;}if(run){if(state)ar[na++]=run*.1;else gr[ng++]=run*.1;}
    out[0]=(double)active/m;out[1]=na?median_copy(ar,na):0;out[2]=ng?median_copy(gr,ng):0;out[3]=ng?percentile_copy(gr,ng,.9):0;
    double mean=0;for(uint64_t k=0;k<m;k++)mean+=env[k];mean/=m;double bestp=-1,bestf=0;for(int fi=10;fi<=80;fi++){double f=fi/10.0,re=0,im=0;for(uint64_t k=0;k<m;k++){double v=env[k]-mean,ph=2*M_PI*f*(k*.1);re+=v*cos(ph);im-=v*sin(ph);}double p=re*re+im*im;if(p>bestp){bestp=p;bestf=f;}}out[4]=bestf;
    free(env);free(db);free(act);free(ar);free(gr);
}
static void free_profile(ASProfile*p);
static double robust_scale(const double *v,uint64_t n,double center){double *d=malloc(n*sizeof(double));if(!d)return fmax(fabs(center)*.05,1e-3);for(uint64_t i=0;i<n;i++)d[i]=fabs(v[i]-center);double mad=median_copy(d,n)*1.4826;free(d);double floor=fmax(fabs(center)*.05,1e-3);return mad<floor?floor:mad;}
static int build_profile(ASProfile*p,ASAudio**rr,size_t nr){
    memset(p,0,sizeof(*p));
    if(!rr || nr<2 || nr>MAX_REFERENCE_FILES){errno=EINVAL;return -1;}
    double *g=calloc(nr*10,sizeof(double)),*t=calloc(nr*5,sizeof(double));
    if(!g||!t){free(g);free(t);return -1;}
    for(size_t z=0;z<nr;z++){global_features(rr[z],g+z*10);temporal_features(rr[z],t+z*5);}
    for(int j=0;j<10;j++){double *v=malloc(nr*sizeof(double));if(!v){free(g);free(t);return -1;}for(size_t z=0;z<nr;z++)v[z]=g[z*10+j];p->global_center[j]=median_copy(v,nr);p->global_scale[j]=robust_scale(v,nr,p->global_center[j]);free(v);}
    for(int j=0;j<5;j++){double *v=malloc(nr*sizeof(double));if(!v){free(g);free(t);return -1;}for(size_t z=0;z<nr;z++)v[z]=t[z*5+j];p->temporal_center[j]=median_copy(v,nr);p->temporal_scale[j]=robust_scale(v,nr,p->temporal_center[j]);free(v);}
    free(g);free(t);
    uint64_t cap=8;for(size_t z=0;z<nr;z++)cap+=(rr[z]->n/rr[z]->sr)+2;
    p->ref_windows=calloc(cap*2,sizeof(double));if(!p->ref_windows)return -1;
    uint64_t q=0;for(size_t z=0;z<nr;z++){uint64_t win=rr[z]->sr*2,hop=rr[z]->sr;if(rr[z]->n<win)win=rr[z]->n;for(uint64_t s=0;s+win<=rr[z]->n;s+=hop){double a,b;basic_window(rr[z]->x+s,win,&a,&b);p->ref_windows[2*q]=a;p->ref_windows[2*q+1]=b;q++;if(win==rr[z]->n)break;}}
    if(q==0){free_profile(p);errno=EINVAL;return -1;}
    p->ref_window_count=q;for(int j=0;j<2;j++){double *v=malloc(q*sizeof(double));if(!v){free_profile(p);return -1;}for(uint64_t i=0;i<q;i++)v[i]=p->ref_windows[2*i+j];p->window_center[j]=median_copy(v,q);p->window_scale[j]=robust_scale(v,q,p->window_center[j]);free(v);}
    return 0;
}
static void free_profile(ASProfile*p){free(p->ref_windows);memset(p,0,sizeof(*p));}

static void frame_logrms(const ASAudio*a,double **out,uint64_t *count){
    uint64_t frame=(uint64_t)llround(a->sr*.1);
    if(frame<1) frame=1;
    uint64_t m=a->n/frame;
    *out=NULL; *count=0;
    if(m==0) return;
    double *v=malloc(m*sizeof(double));
    if(!v) return;
    for(uint64_t k=0;k<m;k++) v[k]=log(rms_range(a->x+k*frame,frame)+EPS);
    double med=median_copy(v,m);
    double *d=malloc(m*sizeof(double));
    if(!d){ free(v); return; }
    for(uint64_t k=0;k<m;k++) d[k]=fabs(v[k]-med);
    double mad=median_copy(d,m)*1.4826,sc=fmax(mad,1e-8);
    for(uint64_t k=0;k<m;k++){v[k]=(v[k]-med)/sc;if(v[k]>8)v[k]=8;if(v[k]<-8)v[k]=-8;}
    free(d); *out=v; *count=m;
}
static double align_score(const double*t,uint64_t tn,const double*c,uint64_t cn,double off,double drift){if(tn<8)return -1e9;double rt=0,rq=0,rtt=0,rqq=0,rtq=0,rdt=0,rdq=0,rdtt=0,rdqq=0,rdtq=0;double prevt=t[0],prevq=0;for(uint64_t i=0;i<tn;i++){double pos=(off+i*.1*(1+drift*1e-6))/.1;if(pos<0||pos>cn-1)return -1e9;uint64_t k=(uint64_t)floor(pos);double frac=pos-k;double q=(k+1<cn)?c[k]+frac*(c[k+1]-c[k]):c[k];double a=t[i];rt+=a;rq+=q;rtt+=a*a;rqq+=q*q;rtq+=a*q;if(i){double da=a-prevt,dq=q-prevq;rdt+=da;rdq+=dq;rdtt+=da*da;rdqq+=dq*dq;rdtq+=da*dq;}prevt=a;prevq=q;}double n=(double)tn,den=sqrt(fmax((rtt-rt*rt/n)*(rqq-rq*rq/n),EPS));double corr=(rtq-rt*rq/n)/den;double nd=(double)(tn-1),dend=sqrt(fmax((rdtt-rdt*rdt/nd)*(rdqq-rdq*rdq/nd),EPS));double dc=(rdtq-rdt*rdq/nd)/dend;return .5*(corr+dc);}
static void solve_alignment(ASContext*ctx){double*t=NULL,*c=NULL;uint64_t tn=0,cn=0;frame_logrms(ctx->source,&t,&tn);frame_logrms(ctx->companion,&c,&cn);double maxoff=fmax(0,(double)ctx->companion->n/ctx->companion->sr-(double)ctx->source->n/ctx->source->sr);double best=-1e9,bo=0,bd=0;for(int di=-5000;di<=5000;di+=500){for(double o=0;o<=maxoff+1e-9;o+=.1){double s=align_score(t,tn,c,cn,o,di);if(s>best){best=s;bo=o;bd=di;}}}for(double d=fmax(-7500,bd-1000);d<=fmin(7500,bd+1000)+1e-9;d+=100){for(double o=fmax(0,bo-.4);o<=fmin(maxoff,bo+.4)+1e-9;o+=.01){double s=align_score(t,tn,c,cn,o,d);if(s>best){best=s;bo=o;bd=d;}}}ctx->align_offset_sec=bo;ctx->align_drift_ppm=bd;ctx->align_correlation=best;free(t);free(c);}
static float companion_sample(const ASContext*ctx,uint64_t i,int tweak){double t=(double)i/ctx->source->sr;double q=ctx->align_offset_sec+t*(1+ctx->align_drift_ppm*1e-6)+tweak/1000.0;double pos=q*ctx->companion->sr;if(pos<0||pos>=ctx->companion->n-1)return 0;uint64_t k=(uint64_t)floor(pos);double f=pos-k;return (float)(ctx->companion->x[k]+f*(ctx->companion->x[k+1]-ctx->companion->x[k]));}
static void build_shared(ASContext*ctx){uint64_t n=ctx->source->n;for(int z=0;z<TWEAKS;z++){ctx->shared[z]=calloc(n,sizeof(float));if(!ctx->shared[z])continue;long double xx=0,rr=0,xr=0;for(uint64_t i=0;i<n;i++){double x=ctx->source->x[i],r=companion_sample(ctx,i,tweak_ms[z]);xx+=x*x;rr+=r*r;xr+=x*r;}double corr=(double)(xr/(sqrt((double)xx*(double)rr)+EPS));double alpha=(double)(xr/((double)rr+EPS));if(fabs(corr)<.04)alpha=0;if(alpha>3)alpha=3;if(alpha<-3)alpha=-3;ctx->shared_alpha[z]=alpha;ctx->shared_corr[z]=corr;for(uint64_t i=0;i<n;i++)ctx->shared[z][i]=(float)(alpha*companion_sample(ctx,i,tweak_ms[z]));}}
static int tweak_index(int ms){int best=0,bd=abs(ms-tweak_ms[0]);for(int i=1;i<TWEAKS;i++){int d=abs(ms-tweak_ms[i]);if(d<bd){bd=d;best=i;}}return best;}

static ASAudio *apply_params(ASContext*ctx,const ASParams*p,ASStats*diag){ASAudio*y=audio_new(ctx->source->sr,ctx->source->n);if(!y)return NULL;int ti=tweak_index(p->cancel_tweak_ms);double gain=pow(10.0,p->gain_db/20.0),peak=0;for(uint64_t i=0;i<y->n;i++){double v=ctx->source->x[i]-p->cancel_strength*(ctx->shared[ti]?ctx->shared[ti][i]:0);v*=gain;y->x[i]=(float)v;if(fabs(v)>peak)peak=fabs(v);}if(diag)diag->pre_filter_peak=peak;apply_filter(y->x,y->n,y->sr,p->highpass_hz,p->lowpass_hz);if(apply_reject_bands(y->x,y->n,y->sr,p)!=0){audio_destroy(y);return NULL;}if(p->denoise_floor_db<100)apply_noise_gate(y->x,y->n,y->sr,p->denoise_floor_db);apply_echo(y->x,y->n,y->sr,p->echo_delay_ms,p->echo_gain);if(p->compress)apply_compressor(y->x,y->n,p->compress_threshold_db,p->compress_ratio);uint64_t over=0;for(uint64_t i=0;i<y->n;i++)if(fabs(y->x[i])>.95)over++;if(diag)diag->pre_limiter_over_fraction=(double)over/y->n;apply_limiter(y->x,y->n);return y;}

/* H additive voice mix: replay two independently derived candidate chains on the
   same immutable source window, sum their already-limited derived views at the
   requested gains, then apply the standard sample-local limiter once more.
   No peak normalization is performed; the mix is a new derived material with
   explicit lineage rather than a replacement for either input view. */
static ASAudio *apply_additive_mix(ASContext *ctx,const ASParams *primary,const ASParams *residual,double primary_gain,double residual_gain,ASStats *diag){
    ASAudio *a=apply_params(ctx,primary,NULL), *b=apply_params(ctx,residual,NULL);
    if(!a||!b){audio_destroy(a);audio_destroy(b);return NULL;}
    if(a->sr!=b->sr||a->n!=b->n){audio_destroy(a);audio_destroy(b);errno=EINVAL;return NULL;}
    ASAudio *y=audio_new(a->sr,a->n); if(!y){audio_destroy(a);audio_destroy(b);return NULL;}
    double peak=0; uint64_t over=0;
    for(uint64_t i=0;i<y->n;i++){
        double v=primary_gain*a->x[i]+residual_gain*b->x[i];
        y->x[i]=(float)v; if(fabs(v)>peak)peak=fabs(v); if(fabs(v)>.95)over++;
    }
    if(diag){diag->pre_filter_peak=peak;diag->pre_limiter_over_fraction=(double)over/y->n;}
    apply_limiter(y->x,y->n);
    audio_destroy(a);audio_destroy(b);return y;
}
static uint64_t pcm_hash64(const ASAudio*a){uint64_t h=1469598103934665603ULL;for(uint64_t i=0;i<a->n;i++){double v=a->x[i];if(v>1)v=1;if(v<-1)v=-1;int16_t q=(int16_t)lround(v*32767.0);unsigned char b0=(unsigned char)q,b1=(unsigned char)(q>>8);h^=b0;h*=1099511628211ULL;h^=b1;h*=1099511628211ULL;}return h;}
static double normdist(const double*a,const double*c,const double*s,int n){double q=0;for(int i=0;i<n;i++){double d=(a[i]-c[i])/s[i];q+=d*d;}return sqrt(q);}
static void evaluate_audio(ASContext*ctx,ASAudio*y,ASStats*st){double g[10],t[5];global_features(y,g);temporal_features(y,t);st->global_distance=normdist(g,ctx->profile.global_center,ctx->profile.global_scale,10);st->temporal_distance=normdist(t,ctx->profile.temporal_center,ctx->profile.temporal_scale,5);uint64_t win=y->sr*2,hop=y->sr,count=(y->n<win?1:1+(y->n-win)/hop);double *dist=malloc(count*sizeof(double));for(uint64_t wi=0;wi<count;wi++){uint64_t s=wi*hop,n=win;if(y->n<win){s=0;n=y->n;}double a,b;basic_window(y->x+s,n,&a,&b);double za=(a-ctx->profile.window_center[0])/ctx->profile.window_scale[0],zb=(b-ctx->profile.window_center[1])/ctx->profile.window_scale[1],best=1e100;for(uint64_t r=0;r<ctx->profile.ref_window_count;r++){double ra=(ctx->profile.ref_windows[2*r]-ctx->profile.window_center[0])/ctx->profile.window_scale[0],rb=(ctx->profile.ref_windows[2*r+1]-ctx->profile.window_center[1])/ctx->profile.window_scale[1],d=hypot(za-ra,zb-rb);if(d<best)best=d;}dist[wi]=best;}st->window_median_distance=median_copy(dist,count);st->window_p25_distance=percentile_copy(dist,count,.25);free(dist);uint64_t sil=0,post=0;double silent=pow(10.0,-55.0/20.0);for(uint64_t i=0;i<y->n;i++){double a=fabs(y->x[i]);if(a<silent)sil++;if(a>=.979)post++;}st->silence_fraction=(double)sil/y->n;st->post_limiter_clip_fraction=(double)post/y->n;st->pcm_hash64=pcm_hash64(y);}

static int add_reference(ASContext*ctx,const char*path){
    if(!ctx||!path||!*path||ctx->ref_count>=MAX_REFERENCE_FILES){errno=EINVAL;return -1;}
    ASAudio *a=load_pcm16_wav(path);if(!a)return -1;
    if(ctx->source && a->sr!=ctx->source->sr){audio_destroy(a);errno=EINVAL;return -1;}
    ASAudio **next=realloc(ctx->refs,(ctx->ref_count+1)*sizeof(*next));if(!next){audio_destroy(a);return -1;}
    ctx->refs=next;ctx->refs[ctx->ref_count++]=a;return 0;
}
static char *manifest_dir(const char*path){const char *slash=strrchr(path,'/');if(!slash)return strdup(".");size_t n=(size_t)(slash-path);if(n==0)n=1;char*d=malloc(n+1);if(!d)return NULL;memcpy(d,path,n);d[n]='\0';return d;}
static char *join_manifest_path(const char*dir,const char*entry){if(entry[0]=='/')return strdup(entry);size_t n=strlen(dir)+1+strlen(entry)+1;char*p=malloc(n);if(!p)return NULL;snprintf(p,n,"%s/%s",dir,entry);return p;}
static char *trim_line(char*s){while(*s==' '||*s=='\t'||*s=='\r'||*s=='\n')s++;char*e=s+strlen(s);while(e>s&&(e[-1]==' '||e[-1]=='\t'||e[-1]=='\r'||e[-1]=='\n'))*--e='\0';return s;}
void *as_context_new_corpus(const char *source,const char *companion,const char *manifest){
    ASContext*ctx=calloc(1,sizeof(*ctx));if(!ctx)return NULL;
    ctx->source=load_pcm16_wav(source);ctx->companion=load_pcm16_wav(companion);
    if(!ctx->source||!ctx->companion||ctx->source->sr!=ctx->companion->sr)goto fail;
    FILE*f=fopen(manifest,"rb");if(!f)goto fail;char*dir=manifest_dir(manifest);if(!dir){fclose(f);goto fail;}
    char line[4096];int header_seen=0;
    while(fgets(line,sizeof(line),f)){char*v=trim_line(line);if(!*v)continue;if(*v=='#'){if(!strcmp(v,"# audio.quality.corpus/2"))header_seen=1;continue;}char*tab=strchr(v,'\t');if(tab)*tab='\0';char*path=join_manifest_path(dir,v);if(!path||add_reference(ctx,path)){free(path);free(dir);fclose(f);goto fail;}free(path);}
    free(dir);fclose(f);
    if(!header_seen||ctx->ref_count<2||build_profile(&ctx->profile,ctx->refs,ctx->ref_count))goto fail;
    solve_alignment(ctx);build_shared(ctx);return ctx;
fail:as_context_free(ctx);errno=EINVAL;return NULL;
}
void *as_context_new(const char *source,const char *companion,const char *ref1,const char *ref2){
    ASContext*ctx=calloc(1,sizeof(*ctx));if(!ctx)return NULL;ctx->source=load_pcm16_wav(source);ctx->companion=load_pcm16_wav(companion);
    if(!ctx->source||!ctx->companion||ctx->source->sr!=ctx->companion->sr||add_reference(ctx,ref1)||add_reference(ctx,ref2)||build_profile(&ctx->profile,ctx->refs,ctx->ref_count))goto fail;
    solve_alignment(ctx);build_shared(ctx);return ctx;fail:as_context_free(ctx);errno=EINVAL;return NULL;
}
void as_context_free(void*v){ASContext*ctx=v;if(!ctx)return;for(int i=0;i<TWEAKS;i++)free(ctx->shared[i]);free_profile(&ctx->profile);audio_destroy(ctx->source);audio_destroy(ctx->companion);for(size_t i=0;i<ctx->ref_count;i++)audio_destroy(ctx->refs[i]);free(ctx->refs);free(ctx);}
uint32_t as_context_sample_rate(void*v){ASContext*c=v;return c?c->source->sr:0;}
double as_context_duration(void*v){ASContext*c=v;return c?(double)c->source->n/c->source->sr:0;}
int32_t as_context_alignment(void*v,ASAlignment*out){ASContext*c=v;if(!c||!out)return -1;out->offset_sec=c->align_offset_sec;out->drift_ppm=c->align_drift_ppm;out->correlation=c->align_correlation;out->offset_min_sec=0;out->offset_max_sec=(double)c->companion->n/c->companion->sr-(double)c->source->n/c->source->sr;out->nominal_offset_sec=15;return 0;}
int32_t as_evaluate(void*v,const ASParams*p,ASStats*out){ASContext*c=v;if(!c||!p||!out)return -1;memset(out,0,sizeof(*out));ASAudio*y=apply_params(c,p,out);if(!y)return -2;evaluate_audio(c,y,out);audio_destroy(y);return 0;}
int32_t as_render(void*v,const ASParams*p,const char*path){ASContext*c=v;if(!c||!p||!path)return -1;ASStats s={0};ASAudio*y=apply_params(c,p,&s);if(!y)return -2;int rc=write_pcm16_wav(y,path);audio_destroy(y);return rc;}
double as_output_rms_db(void*v,const ASParams*p){ASContext*c=v;if(!c||!p)return NAN;ASAudio*y=apply_params(c,p,NULL);if(!y)return NAN;double rms=rms_range(y->x,y->n);audio_destroy(y);return 20.0*log10(rms+EPS);}
int32_t as_evaluate_additive_mix(void*v,const ASParams*primary,const ASParams*residual,double primary_gain,double residual_gain,ASStats*out){ASContext*c=v;if(!c||!primary||!residual||!out)return -1;memset(out,0,sizeof(*out));ASAudio*y=apply_additive_mix(c,primary,residual,primary_gain,residual_gain,out);if(!y)return -2;evaluate_audio(c,y,out);audio_destroy(y);return 0;}
int32_t as_render_additive_mix(void*v,const ASParams*primary,const ASParams*residual,double primary_gain,double residual_gain,const char*path){ASContext*c=v;if(!c||!primary||!residual||!path)return -1;ASStats s={0};ASAudio*y=apply_additive_mix(c,primary,residual,primary_gain,residual_gain,&s);if(!y)return -2;int rc=write_pcm16_wav(y,path);audio_destroy(y);return rc;}
double as_shared_alpha(void*v,int32_t tweak){ASContext*c=v;if(!c)return 0;return c->shared_alpha[tweak_index(tweak)];}
double as_shared_correlation(void*v,int32_t tweak){ASContext*c=v;if(!c)return 0;return c->shared_corr[tweak_index(tweak)];}
