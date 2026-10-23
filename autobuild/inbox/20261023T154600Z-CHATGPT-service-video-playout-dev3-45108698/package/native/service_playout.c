/*
 * A01 Service Playout v0.1, native Linux reference sink.
 * Queue receives PREQUALIFIED frames/audio; authorisation belongs upstream.
 * Stable I420/24fps/48kHz stereo outputs; no GUI or ooRexx callback in media thread.
 * Explicitly not a compressed-stream decoder: staged WebM assets are decoded
 * by the swappable asset preparation adapter before native queue admission.
 */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdint.h>
#include <stdatomic.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <dlfcn.h>
#include <sys/ioctl.h>
#include <linux/videodev2.h>

#define QCAP 64
#define PATHCAP 2048
#define SAMPLES_PER_FRAME 2000
#define PCM_BYTES (SAMPLES_PER_FRAME*4)

typedef struct pa_simple pa_simple;
typedef struct {int format; uint32_t rate; uint8_t channels;} pa_sample_spec;
typedef pa_simple *(*pa_new_t)(const char*, const char*,int,const char*,const char*,const pa_sample_spec*,const void*,const void*,int*);
typedef int (*pa_write_t)(pa_simple*,const void*,size_t,int*);
typedef void (*pa_free_t)(pa_simple*);

typedef struct {
    char video[PATHCAP]; char audio[PATHCAP];
    int count, is_card;
} item;

typedef struct {
    pthread_mutex_t mu; pthread_t thread;
    atomic_int running, stop, hold, error;
    int thread_joinable, queued, head, tail;
    atomic_ullong frames_sent, items_finished, underruns, held_frames;
    item queue[QCAP];
    int vfd, afd, v4l2, pulse, realtime;
    void *pulse_lib; pa_simple *ps; pa_write_t pa_write; pa_free_t pa_free;
    unsigned char *idle, *frame;
    size_t frame_bytes;
    unsigned char silence[PCM_BYTES];
    char why[256];
    char report[512];
} engine;
static engine E = {.mu=PTHREAD_MUTEX_INITIALIZER,.vfd=-1,.afd=-1};

static int fail(const char *why) {
    int err=errno;
    pthread_mutex_lock(&E.mu);
    snprintf(E.why,sizeof E.why,"%s: %s",why,strerror(err));
    atomic_store(&E.error,1);
    pthread_mutex_unlock(&E.mu);
    return 0;
}
static int write_exact(int fd,const unsigned char *buf,size_t n) {
    while(n) { ssize_t r=write(fd,buf,n); if(r<0&&errno==EINTR)continue; if(r<=0)return 0; buf+=r;n-=(size_t)r; }
    return 1;
}
static int read_exact(int fd,unsigned char *buf,size_t n) {
    while(n) { ssize_t r=read(fd,buf,n); if(r<0&&errno==EINTR)continue; if(r<=0)return 0; buf+=r;n-=(size_t)r; }
    return 1;
}
static int safe_path(const char *p) {return p && *p && strlen(p)<PATHCAP && p[0]=='/';}
static int open_read(const char *p) {return open(p,O_RDONLY|O_CLOEXEC|O_NOFOLLOW);}
static int open_output(const char *p) {
    if (strncmp(p,"file:",5)==0 && safe_path(p+5)) return open(p+5,O_CREAT|O_TRUNC|O_WRONLY|O_CLOEXEC|O_NOFOLLOW,0600);
    return open(p,O_WRONLY|O_CLOEXEC|O_NOFOLLOW);
}
static void close_outputs(void) {
    if (E.ps && E.pa_free) E.pa_free(E.ps);
    E.ps=NULL;
    if (E.pulse_lib)dlclose(E.pulse_lib);
    E.pulse_lib=NULL; E.pa_free=NULL; E.pa_write=NULL;
    if(E.vfd>=0)close(E.vfd);
    E.vfd=-1;
    if(E.afd>=0)close(E.afd);
    E.afd=-1;
    free(E.frame); E.frame=NULL;free(E.idle);E.idle=NULL;
}
int svc_reset(void) {
    if(atomic_load(&E.running) || E.thread_joinable)return 0;
    pthread_mutex_lock(&E.mu);close_outputs();atomic_store(&E.error,0);E.why[0]=0;
    E.queued=E.head=E.tail=0;
    atomic_store(&E.stop,0);atomic_store(&E.hold,0);
    E.frames_sent=E.items_finished=E.underruns=E.held_frames=0;
    E.v4l2=E.pulse=E.realtime=0;pthread_mutex_unlock(&E.mu);return 1;
}
int svc_open(const char *video,const char *audio,int realtime) {
    if(!video || !audio || atomic_load(&E.running) || E.thread_joinable)return 0;
    if(!svc_reset())return 0;
    E.frame_bytes=(size_t)1280*720*3/2;
    E.frame=malloc(E.frame_bytes);E.idle=malloc(E.frame_bytes);
    if(!E.frame || !E.idle)return fail("frame allocation");
    /* Dark-grey YUV420P fallback for interruptions / empty queue. */
    memset(E.idle,110,1280*720);
    memset(E.idle+1280*720,128,E.frame_bytes-1280*720);
    E.v4l2=(strncmp(video,"file:",5)!=0);
    E.pulse=(strncmp(audio,"pulse:",6)==0);
    E.vfd=open_output(video);if(E.vfd<0)return fail("video output");
    if(E.v4l2) {
        struct v4l2_format f;memset(&f,0,sizeof f);
        f.type=V4L2_BUF_TYPE_VIDEO_OUTPUT;
        f.fmt.pix.width=1280;f.fmt.pix.height=720;
        f.fmt.pix.pixelformat=V4L2_PIX_FMT_YUV420;
        f.fmt.pix.field=V4L2_FIELD_NONE;
        if(ioctl(E.vfd,VIDIOC_S_FMT,&f)<0)return fail("VIDIOC_S_FMT");
        if(f.fmt.pix.width!=1280||f.fmt.pix.height!=720||f.fmt.pix.pixelformat!=V4L2_PIX_FMT_YUV420)
           {errno=EINVAL;return fail("device changed format");}
    }
    if(E.pulse) {
        E.pulse_lib=dlopen("libpulse-simple.so.0",RTLD_NOW|RTLD_LOCAL);
        if(!E.pulse_lib){errno=ENOENT;return fail("libpulse-simple.so.0 missing");}
        pa_new_t make;
        void *sym=dlsym(E.pulse_lib,"pa_simple_new");memcpy(&make,&sym,sizeof make);
        sym=dlsym(E.pulse_lib,"pa_simple_write");memcpy(&E.pa_write,&sym,sizeof E.pa_write);
        sym=dlsym(E.pulse_lib,"pa_simple_free");memcpy(&E.pa_free,&sym,sizeof E.pa_free);
        if(!make||!E.pa_write||!E.pa_free){errno=ENOENT;return fail("PulseAudio symbols missing");}
        pa_sample_spec spec={3,48000,2};int err=0;
        const char *dev=audio+6;if(!*dev)dev=NULL;
        E.ps=make(NULL,"A01 Service Playout",1,dev,"Service Agent Speech",&spec,NULL,NULL,&err);
        if(!E.ps){errno=EIO;return fail("PulseAudio stream open");}
    } else {
        E.afd=open_output(audio);if(E.afd<0)return fail("audio output");
    }
    E.realtime=realtime ? 1 : 0;return 1;
}
int svc_set_idle(const char *frame_path) {
    if(!safe_path(frame_path)||!E.idle||atomic_load(&E.running))return 0;
    int fd=open_read(frame_path);if(fd<0)return 0;
    int ok=read_exact(fd,E.idle,E.frame_bytes);close(fd);return ok;
}
/* Fail closed before queue admission AND again at segment opening. A file may
 * disappear or change between those points; there is no production authorisation
 * or staged-asset immutability claim in this demo implementation. */
static int checked_media(const char *path, size_t expected) {
    if(!safe_path(path))return 0;
    int fd=open_read(path);
    if(fd<0)return 0;
    struct stat st;
    int valid=fstat(fd,&st)==0 && S_ISREG(st.st_mode) && st.st_size>=0 &&
        (uint64_t)st.st_size==(uint64_t)expected;
    close(fd);
    return valid;
}
static int validate_item(const item *it) {
    size_t vbytes=it->is_card ? E.frame_bytes : (size_t)it->count*E.frame_bytes;
    return checked_media(it->video,vbytes) &&
        (!it->audio[0] || checked_media(it->audio,(size_t)it->count*PCM_BYTES));
}
static int enqueue(const char *video,const char *audio,int count,int is_card) {
    if(!safe_path(video)||count<1||count>24*600||!E.frame)return 0;
    if(audio && *audio && !safe_path(audio))return 0;
    item pending={0};
    snprintf(pending.video,sizeof pending.video,"%s",video);
    if(audio)snprintf(pending.audio,sizeof pending.audio,"%s",audio);
    pending.count=count;pending.is_card=is_card;
    if(!validate_item(&pending))return 0;
    pthread_mutex_lock(&E.mu);
    if(E.queued>=QCAP){pthread_mutex_unlock(&E.mu);return 0;}
    E.queue[E.tail]=pending;
    E.tail=(E.tail+1)%QCAP;E.queued++;
    pthread_mutex_unlock(&E.mu);return 1;
}
int svc_enqueue_clip(const char *video,const char *audio,int frames){return enqueue(video,audio,frames,0);}
int svc_enqueue_card(const char *still,const char *audio,int frames){return enqueue(still,audio,frames,1);}
static int send_frame(const unsigned char *v,const unsigned char *a) {
    if(!write_exact(E.vfd,v,E.frame_bytes))return fail("video write");
    if(E.pulse){int err=0;if(E.pa_write(E.ps,a,PCM_BYTES,&err)<0){errno=EIO;return fail("PulseAudio write");}}
    else if(!write_exact(E.afd,a,PCM_BYTES))return fail("audio write");
    E.frames_sent++;return 1;
}
static void sleep_frame(struct timespec *target) {
    target->tv_nsec+=41666667L; if(target->tv_nsec>=1000000000L){target->tv_sec++;target->tv_nsec-=1000000000L;}
    clock_nanosleep(CLOCK_MONOTONIC,TIMER_ABSTIME,target,NULL);
}
static int tick(item *cur,int *remain,int *vfd,int *afd,struct timespec *clock0) {
    /* Hold is a frame-clock state, not a device disconnect. Keep pumping an
     * idle picture + digital silence while the scene cursor is preserved. */
    if(atomic_load(&E.hold)) {
        unsigned char pcm[PCM_BYTES]={0};
        if(!send_frame(E.idle,pcm))return 0;
        E.held_frames++;
        if(E.realtime)sleep_frame(clock0);
        return 1;
    }
    if(*remain<=0) {
        if(*vfd>=0)close(*vfd);
        if(*afd>=0)close(*afd);
        *vfd=*afd=-1;
        pthread_mutex_lock(&E.mu);
        if(E.queued) { *cur=E.queue[E.head];E.head=(E.head+1)%QCAP;E.queued--;*remain=cur->count; }
        else { *remain=0; }
        pthread_mutex_unlock(&E.mu);
        if(*remain) {
            if(!validate_item(cur)){errno=ENOENT;return fail("queued media absent or changed");}
            *vfd=open_read(cur->video);if(*vfd<0)return fail("segment video open");
            if(cur->audio[0]){*afd=open_read(cur->audio);if(*afd<0)return fail("segment audio open");}
        }
    }
    unsigned char pcm[PCM_BYTES]={0};const unsigned char *video=E.idle;
    if(*remain>0) {
        if(cur->is_card) {
            if(*remain==cur->count && !read_exact(*vfd,E.frame,E.frame_bytes))return fail("card read");
        } else if(!read_exact(*vfd,E.frame,E.frame_bytes))return fail("clip frame read");
        video=E.frame;
        if(*afd>=0) {
            ssize_t got=0;
            while(got<PCM_BYTES){ssize_t n=read(*afd,pcm+got,PCM_BYTES-(size_t)got);if(n>0)got+=n;else if(n<0&&errno==EINTR)continue;else break;}
            /* FFmpeg may produce slightly shorter/longer audio. Pad tail with zeroes. */
        }
        (*remain)--;if(*remain==0)E.items_finished++;
    }
    else E.underruns++;
    if(!send_frame(video,pcm))return 0;
    if(E.realtime)sleep_frame(clock0);
    return 1;
}
/* The control thread may change hold while the playout thread continues. */
int svc_set_hold(int enabled) {
    if(!E.frame)return 0;
    atomic_store(&E.hold,enabled ? 1 : 0);
    return 1;
}
int svc_run_frames(int count) {
    if(atomic_load(&E.running)||E.thread_joinable||!E.frame||count<1||count>24*600)return 0;
    item cur;memset(&cur,0,sizeof cur);int remain=0,vid=-1,aud=-1;
    struct timespec now;clock_gettime(CLOCK_MONOTONIC,&now);
    for(int i=0;i<count;i++)if(!tick(&cur,&remain,&vid,&aud,&now)){if(vid>=0)close(vid);if(aud>=0)close(aud);return 0;}
    if(vid>=0)close(vid);
    if(aud>=0)close(aud);
    return 1;
}
static void *worker(void *unused) {
    (void)unused;item cur;memset(&cur,0,sizeof cur);int remain=0,vid=-1,aud=-1;
    struct timespec now;clock_gettime(CLOCK_MONOTONIC,&now);
    while(!atomic_load(&E.stop))if(!tick(&cur,&remain,&vid,&aud,&now))break;
    if(vid>=0)close(vid);
    if(aud>=0)close(aud);
    atomic_store(&E.running,0);return NULL;
}
int svc_start(void){
    if(!E.frame||atomic_load(&E.running)||E.thread_joinable)return 0;
    E.realtime=1;
    atomic_store(&E.stop,0);
    atomic_store(&E.running,1);
    int rc=pthread_create(&E.thread,NULL,worker,NULL);
    if(rc!=0){atomic_store(&E.running,0);errno=rc;return fail("thread creation");}
    E.thread_joinable=1;
    return 1;
}
int svc_stop(void){
    atomic_store(&E.stop,1);
    if(E.thread_joinable){pthread_join(E.thread,NULL);E.thread_joinable=0;}
    atomic_store(&E.running,0);
    return atomic_load(&E.error)?0:1;
}
const char *svc_stats(void){
    pthread_mutex_lock(&E.mu);
    snprintf(E.report,sizeof E.report,"{\"frames\":%llu,\"finished\":%llu,\"underruns\":%llu,\"held_frames\":%llu,\"held\":%d,\"queued\":%d,\"running\":%d,\"error\":%d,\"why\":\"%.180s\"}",
       atomic_load(&E.frames_sent),atomic_load(&E.items_finished),atomic_load(&E.underruns),atomic_load(&E.held_frames),atomic_load(&E.hold),E.queued,atomic_load(&E.running),atomic_load(&E.error),E.why);
    pthread_mutex_unlock(&E.mu);return E.report;
}
