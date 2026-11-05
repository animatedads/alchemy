/* Native FFT arithmetic only. ooRexx owns media selection and spectrum rules. */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
static char error_text[256];
const char *media_spectrum_last_error(void) { return error_text; }
static int fail(const char *s) { snprintf(error_text,sizeof error_text,"%s: %s",s,strerror(errno)); return -1; }
typedef struct { double r, i; } Complex;
static void fft(Complex *v, unsigned n) {
    for (unsigned i=1,j=0;i<n;i++) {
        unsigned bit=n>>1;
        for (;j&bit;bit>>=1) j^=bit;
        j^=bit;
        if (i<j) { Complex t=v[i];v[i]=v[j];v[j]=t; }
    }
    for (unsigned len=2;len<=n;len<<=1) {
        double a=-2*M_PI/len;
        for (unsigned base=0;base<n;base+=len) {
            for (unsigned k=0;k<len/2;k++) {
                double c=cos(a*k),s=sin(a*k);
                Complex q=v[base+k+len/2];
                Complex t={q.r*c-q.i*s,q.r*s+q.i*c};
                Complex u=v[base+k];
                v[base+k]=(Complex){u.r+t.r,u.i+t.i};
                v[base+k+len/2]=(Complex){u.r-t.r,u.i-t.i};
            }
        }
    }
}

int32_t media_spectrum_map_f32(const char *input,const char *output,
    uint32_t rate,uint32_t size,uint32_t hop,uint32_t window_ms) {
    error_text[0]=0;
    if (!input||!output||!*input||!*output||!strcmp(input,output)||
        (rate!=8000&&rate!=16000&&rate!=48000)||size<256||size>8192||
        (size&(size-1))||hop<1||hop>size||window_ms<100||window_ms>10000||
        ((uint64_t)rate*window_ms)%1000) {
        errno=EINVAL;return fail("invalid spectrum request");
    }
    uint64_t per=(uint64_t)rate*window_ms/1000;
    if (per<size) {errno=EINVAL;return fail("window shorter than FFT");}
    int fd=open(input,O_RDONLY|O_CLOEXEC);
    if (fd<0)return fail("open f32 input");
    struct stat st;
    if (fstat(fd,&st)||!S_ISREG(st.st_mode)||st.st_size<=0||
        st.st_size%(off_t)(per*sizeof(float))||
        st.st_size>(off_t)(120ULL*rate*sizeof(float))) {
        close(fd);errno=EINVAL;return fail("f32 extent must be exact and <=120 seconds");
    }
    unsigned windows=(unsigned)(st.st_size/(off_t)(per*sizeof(float)));
    int outfd=open(output,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if (outfd<0){close(fd);return fail("exclusive spectrum output");}
    FILE *out=fdopen(outfd,"w");
    if (!out){close(fd);close(outfd);unlink(output);return fail("fdopen spectrum output");}
    float *samples=malloc((size_t)per*sizeof *samples);
    double *window=malloc(size*sizeof *window);
    double *powers=malloc((size/2+1)*sizeof *powers);
    Complex *bins=malloc(size*sizeof *bins);
    if (!samples||!window||!powers||!bins) {errno=ENOMEM;goto error;}
    double sum=0;
    for (unsigned i=0;i<size;i++) {window[i]=0.5-0.5*cos(2*M_PI*i/(size-1));sum+=window[i];}
    if (fprintf(out,"schema\tmedia.spectrum.map/1\nwindow_ms\t%u\nrate_hz\t%u\nfft_size\t%u\nhop_samples\t%u\n",window_ms,rate,size,hop)<0) goto error;
    if (fprintf(out,"window_index\twindow_start_ms\tbin_index\tfrequency_hz\traw_dbfs\n")<0) goto error;
    /* The input is read with positional IO so each window has an exact origin. */
    for (unsigned w=0;w<windows;w++) {
        size_t bytes=(size_t)per*sizeof *samples;
        size_t got=0;
        while (got<bytes) {
            ssize_t n=pread(fd,(char*)samples+got,bytes-got,(off_t)((uint64_t)w*bytes+got));
            if (n<=0){errno=EIO;goto error;}
            got+=(size_t)n;
        }
        for (size_t i=0;i<per;i++) if (!isfinite(samples[i])) {errno=EINVAL;goto error;}
        memset(powers,0,(size/2+1)*sizeof *powers);
        unsigned frames=0;
        for (uint64_t at=0;at+size<=per;at+=hop) {
            for (unsigned i=0;i<size;i++) bins[i]=(Complex){samples[at+i]*window[i],0};
            fft(bins,size);
            for (unsigned k=0;k<=size/2;k++) {
                double mult=(k==0||k==size/2)?1.0:2.0;
                double re=mult*bins[k].r/sum,im=mult*bins[k].i/sum;
                powers[k]+=re*re+im*im;
            }
            frames++;
        }
        for (unsigned k=0;k<=size/2;k++) {
            double mean=powers[k]/frames;
            double db=mean>1e-18?10*log10(mean):-180.0;
            if (fprintf(out,"%u\t%u\t%u\t%.6f\t%.6f\n",w,w*window_ms,k,(double)rate*k/size,db)<0) goto error;
        }
    }
    if (fflush(out)) goto error;
    fclose(out);close(fd);free(samples);free(window);free(powers);free(bins);return 0;
error:
    fail("spectrum FFT");
    fclose(out);close(fd);unlink(output);
    free(samples);free(window);free(powers);free(bins);return -1;
}

/* Dense float32 map: row-major [frame][frequency bin]. No FFT frame or bin
 * is reduced away. The ooRexx map object applies reversible gain rules. */
int32_t media_spectrum_dense_f32(const char *input,const char *output,
    const char *receipt,uint32_t rate,uint32_t size,uint32_t hop) {
    error_text[0]=0;
    if (!input||!output||!receipt||!*input||!*output||!*receipt||
        !strcmp(input,output)||!strcmp(input,receipt)||!strcmp(output,receipt)||
        (rate!=8000&&rate!=16000&&rate!=48000)||size<256||size>8192||
        (size&(size-1))||hop<1||hop>size) {
        errno=EINVAL;return fail("invalid dense spectrum request");
    }
    int in=open(input,O_RDONLY|O_CLOEXEC);
    if (in<0)return fail("open dense f32 input");
    struct stat st;
    if (fstat(in,&st)||!S_ISREG(st.st_mode)||st.st_size<=0||
        st.st_size%(off_t)sizeof(float)||st.st_size>(off_t)(120ULL*rate*sizeof(float))||
        st.st_size<(off_t)(size*sizeof(float))) {
        close(in);errno=EINVAL;return fail("dense f32 extent invalid");
    }
    uint64_t samples=(uint64_t)st.st_size/sizeof(float);
    uint64_t frames=(samples-size)/hop+1;
    uint64_t bins_per_frame=size/2+1;
    if (frames>300000||frames*bins_per_frame>60000000) {
        close(in);errno=E2BIG;return fail("dense spectrum bound");
    }
    int outfd=open(output,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if (outfd<0){close(in);return fail("exclusive dense map output");}
    FILE *out=fdopen(outfd,"wb");
    if (!out){close(in);close(outfd);unlink(output);return fail("fdopen dense map");}
    float *samples_buf=malloc(size*sizeof *samples_buf);
    float *row=malloc(bins_per_frame*sizeof *row);
    double *window=malloc(size*sizeof *window);
    Complex *fft_buf=malloc(size*sizeof *fft_buf);
    if (!samples_buf||!row||!window||!fft_buf) {errno=ENOMEM;goto dense_error;}
    double sum=0,maximum=-180;
    for (unsigned i=0;i<size;i++) {window[i]=0.5-0.5*cos(2*M_PI*i/(size-1));sum+=window[i];}
    for (uint64_t f=0;f<frames;f++) {
        size_t bytes=size*sizeof *samples_buf,got=0;
        while (got<bytes) {
            ssize_t n=pread(in,(char*)samples_buf+got,bytes-got,(off_t)((f*hop*sizeof(float))+got));
            if (n<=0){errno=EIO;goto dense_error;}
            got+=(size_t)n;
        }
        for (unsigned i=0;i<size;i++) {
            if (!isfinite(samples_buf[i])) {errno=EINVAL;goto dense_error;}
            fft_buf[i]=(Complex){samples_buf[i]*window[i],0};
        }
        fft(fft_buf,size);
        for (unsigned k=0;k<=size/2;k++) {
            double mult=(k==0||k==size/2)?1.0:2.0;
            double re=mult*fft_buf[k].r/sum,im=mult*fft_buf[k].i/sum;
            double p=re*re+im*im;
            double db=p>1e-18?10*log10(p):-180.0;
            if (db>maximum) maximum=db;
            row[k]=(float)db;
        }
        if (fwrite(row,sizeof *row,(size_t)bins_per_frame,out)!=(size_t)bins_per_frame) {
            errno=EIO;goto dense_error;
        }
    }
    if (fflush(out)) goto dense_error;
    if (fclose(out)) {out=NULL;goto dense_error;}
    out=NULL;
    int receiptfd=open(receipt,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if (receiptfd<0) goto dense_error;
    FILE *meta=fdopen(receiptfd,"w");
    if (!meta){close(receiptfd);unlink(receipt);goto dense_error;}
    int written=fprintf(meta,"schema\tmedia.spectrum.dense/1\nrate_hz\t%u\nfft_size\t%u\nhop_samples\t%u\ninput_samples\t%llu\nframe_count\t%llu\nbins_per_frame\t%llu\nmap_bytes\t%llu\nfirst_center_sample\t%u\nlast_center_sample\t%llu\nmaximum_dbfs\t%.9g\nvalue_type\tfloat32_le\nnormalization\tHANN_COHERENT_AMPLITUDE\n",
        rate,size,hop,(unsigned long long)samples,(unsigned long long)frames,
        (unsigned long long)bins_per_frame,(unsigned long long)(frames*bins_per_frame*sizeof(float)),
        size/2,(unsigned long long)((frames-1)*hop+size/2),maximum);
    if (written<0||fflush(meta)||fclose(meta)) {unlink(receipt);errno=EIO;goto dense_error;}
    close(in);free(samples_buf);free(row);free(window);free(fft_buf);return 0;
dense_error:
    fail("dense spectrum FFT");
    if (out) fclose(out);
    close(in);unlink(output);
    free(samples_buf);free(row);free(window);free(fft_buf);return -1;
}

double media_spectrum_bucket_db(const char *path,uint32_t frame,uint32_t bin,
    uint32_t bins_per_frame) {
    error_text[0]=0;
    if (!path||!*path||bins_per_frame<2||bin>=bins_per_frame) {
        errno=EINVAL;fail("invalid dense bucket");return NAN;
    }
    int fd=open(path,O_RDONLY|O_CLOEXEC);
    if (fd<0){fail("open dense bucket");return NAN;}
    uint64_t offset=((uint64_t)frame*bins_per_frame+bin)*sizeof(float);
    struct stat st;
    if (fstat(fd,&st)||offset+sizeof(float)>(uint64_t)st.st_size) {
        close(fd);errno=ERANGE;fail("dense bucket outside map");return NAN;
    }
    float value;
    ssize_t n=pread(fd,&value,sizeof value,(off_t)offset);
    close(fd);
    if (n!=(ssize_t)sizeof value){errno=EIO;fail("short dense bucket read");return NAN;}
    return value;
}

static int compare_double(const void *a,const void *b) {
    double x=*(const double*)a,y=*(const double*)b;
    return (x>y)-(x<y);
}

/* A small, reproducible summary of every dense bucket in each named band.
 * This is a measurement of energy and time variation, not speech detection. */
int32_t media_spectrum_band_profile_f32(const char *map,const char *output,
    uint32_t rate,uint32_t size,uint32_t source_rate) {
    error_text[0]=0;
    if (!map||!output||!*map||!*output||!strcmp(map,output)||
        rate<8000||rate>48000||size<256||size>8192||
        (size&(size-1))||source_rate<8000||source_rate>48000) {
        errno=EINVAL;return fail("invalid band profile request");
    }
    const unsigned bounds[]={100,300,800,2000,4000,8000,20000};
    const unsigned bands=6;
    uint64_t bins=size/2+1;
    int in=open(map,O_RDONLY|O_CLOEXEC);
    if (in<0)return fail("open dense profile input");
    struct stat st;
    if (fstat(in,&st)||!S_ISREG(st.st_mode)||st.st_size<=0||
        st.st_size%(off_t)(bins*sizeof(float))) {
        close(in);errno=EINVAL;return fail("invalid dense profile extent");
    }
    uint64_t frames=(uint64_t)st.st_size/(bins*sizeof(float));
    if (frames>300000) {close(in);errno=E2BIG;return fail("profile frame bound");}
    float *row=malloc((size_t)bins*sizeof(float));
    double *levels=malloc((size_t)frames*bands*sizeof(double));
    if (!row||!levels) {close(in);free(row);free(levels);errno=ENOMEM;return fail("profile memory");}
    unsigned counts[6]={0};
    for (unsigned b=0;b<bands;b++) {
        for (unsigned k=0;k<bins;k++) {
            double hz=(double)k*rate/size;
            if (hz>=bounds[b]&&hz<bounds[b+1]&&hz<=source_rate/2.0) counts[b]++;
        }
    }
    for (uint64_t f=0;f<frames;f++) {
        size_t got=0,bytes=(size_t)bins*sizeof(float);
        while (got<bytes) {
            ssize_t n=pread(in,(char*)row+got,bytes-got,(off_t)(f*bytes+got));
            if (n<=0){free(row);free(levels);close(in);errno=EIO;return fail("short dense profile read");}
            got+=(size_t)n;
        }
        for (unsigned b=0;b<bands;b++) {
            double power=0;
            for (unsigned k=0;k<bins;k++) {
                double hz=(double)k*rate/size;
                if (hz>=bounds[b]&&hz<bounds[b+1]&&hz<=source_rate/2.0) {
                    if (!isfinite(row[k])){free(row);free(levels);close(in);errno=EINVAL;return fail("nonfinite dense bucket");}
                    power+=pow(10.0,row[k]/10.0);
                }
            }
            levels[b*frames+f]=counts[b]?10*log10(power/counts[b]):-180;
        }
    }
    close(in);free(row);
    int outfd=open(output,O_WRONLY|O_CREAT|O_EXCL|O_CLOEXEC,0600);
    if (outfd<0){free(levels);return fail("exclusive profile output");}
    FILE *out=fdopen(outfd,"w");
    if (!out){close(outfd);unlink(output);free(levels);return fail("profile output stream");}
    if (fprintf(out,"schema\tmedia.spectrum.band-profile/1\nframe_count\t%llu\nrate_hz\t%u\nfft_size\t%u\nsource_rate_hz\t%u\nband_low_hz\tband_high_hz\tbins\tp10_dbfs\tp50_dbfs\tp90_dbfs\tp90_minus_p10_db\n",
        (unsigned long long)frames,rate,size,source_rate)<0) goto profile_error;
    for (unsigned b=0;b<bands;b++) {
        qsort(levels+b*frames,(size_t)frames,sizeof(double),compare_double);
        double p10=levels[b*frames+(frames-1)/10];
        double p50=levels[b*frames+(frames-1)/2];
        double p90=levels[b*frames+((frames-1)*9)/10];
        if (fprintf(out,"%u\t%u\t%u\t%.5f\t%.5f\t%.5f\t%.5f\n",
            bounds[b],bounds[b+1],counts[b],p10,p50,p90,p90-p10)<0) goto profile_error;
    }
    if (fflush(out)||fclose(out)) {out=NULL;goto profile_error;}
    free(levels);return 0;
profile_error:
    errno=EIO;fail("write band profile");
    if (out) fclose(out);
    unlink(output);free(levels);return -1;
}
