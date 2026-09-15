#include <stdint.h>
#include <stdio.h>
#include <string.h>
static char hello_buf[256];
static uint16_t utf16_buf[256];
int32_t add_i32(int32_t a,int32_t b){return a+b;}
int32_t echo_i32(int32_t a){return a;}
double weighted(double a,int32_t b){return a*b;}
const char* hello(const char*s){snprintf(hello_buf,sizeof hello_buf,"hello %s",s);return hello_buf;}
uintptr_t echo_handle(uintptr_t h){return h;}
intptr_t echo_intptr(intptr_t p){return p;}
const uint16_t* echo_utf16(const uint16_t*s){size_t i=0;if(!s)return 0;for(;i<255&&s[i];++i)utf16_buf[i]=s[i];utf16_buf[i]=0;return utf16_buf;}
#include <stdlib.h>
typedef struct foreign_box { int32_t value; } foreign_box;
void fill_bytes(uint8_t *p, uint32_t n){ if(!p)return; for(uint32_t i=0;i<n;i++) p[i]=(uint8_t)(i+1); }
void* box_new(int32_t value){ foreign_box *b=(foreign_box*)malloc(sizeof(*b)); if(!b)return 0; b->value=value; return b; }
int32_t box_value(void *p){ return p ? ((foreign_box*)p)->value : -1; }
void box_free(void *p){ free(p); }
#ifdef _WIN32
#include <windows.h>
static void foreign_sleep_ms(int32_t ms){ Sleep((DWORD)ms); }
#else
#include <unistd.h>
static void foreign_sleep_ms(int32_t ms){ usleep((useconds_t)ms * 1000u); }
#endif
static volatile int32_t concurrent_now=0;
static volatile int32_t concurrent_max_seen=0;
static volatile int32_t box_probe_started=0;
static volatile int32_t fill_probe_started=0;
void concurrency_reset(void){ concurrent_now=0; concurrent_max_seen=0; box_probe_started=0; fill_probe_started=0; }
int32_t concurrent_probe(int32_t ms){
  int32_t now=__sync_add_and_fetch(&concurrent_now,1);
  int32_t seen;
  do { seen=concurrent_max_seen; if(now<=seen) break; } while(!__sync_bool_compare_and_swap(&concurrent_max_seen,seen,now));
  foreign_sleep_ms(ms);
  __sync_sub_and_fetch(&concurrent_now,1);
  return now;
}
int32_t concurrency_max(void){ return concurrent_max_seen; }
int32_t fill_probe_is_started(void){ return fill_probe_started; }
int32_t box_probe_is_started(void){ return box_probe_started; }
int32_t box_value_delayed(void *p,int32_t ms){ box_probe_started=1; foreign_sleep_ms(ms); return p ? ((foreign_box*)p)->value : -1; }
void fill_bytes_delayed(uint8_t *p,uint32_t n,int32_t ms){ if(!p)return; fill_probe_started=1; __sync_add_and_fetch(&concurrent_now,1); if(concurrent_now>concurrent_max_seen) concurrent_max_seen=concurrent_now; foreign_sleep_ms(ms); for(uint32_t i=0;i<n;i++)p[i]=(uint8_t)(i+1); __sync_sub_and_fetch(&concurrent_now,1); }
uint32_t fnv1a_bytes(const uint8_t *p, uint32_t n){
  uint32_t h=2166136261u;
  if(!p && n) return 0;
  for(uint32_t i=0;i<n;i++){ h ^= p[i]; h *= 16777619u; }
  return h;
}
void make_pattern(uint8_t *p){ if(!p)return; for(uint32_t i=0;i<8;i++)p[i]=(uint8_t)(0xa0u+i); }
int32_t box_out(void **pp){ if(!pp)return 0; foreign_box *b=(foreign_box*)malloc(sizeof(*b)); if(!b)return 0; b->value=31415; *pp=b; return 1; }

int64_t sum6_i64(int64_t a,int64_t b,int64_t c,int64_t d,int64_t e,int64_t f){return a+b+c+d+e+f;}
static volatile int32_t box_free_pp_seen=0;
void box_free_pp_reset(void){box_free_pp_seen=0;}
int32_t box_free_pp_count(void){return box_free_pp_seen;}
void box_free_pp(void **pp){if(pp&&*pp){free(*pp);*pp=0;__sync_add_and_fetch(&box_free_pp_seen,1);}}
int32_t box_out_pp(void **pp){if(!pp)return 0;foreign_box*b=(foreign_box*)malloc(sizeof(*b));if(!b)return 0;b->value=27182;*pp=b;return 1;}
typedef struct foreign_layout { int32_t order; int32_t channels; uint64_t mask; void *opaque; } foreign_layout;
void layout_fill(foreign_layout *p,int32_t channels,uint64_t mask){if(!p)return;p->order=1;p->channels=channels;p->mask=mask;p->opaque=0;}
int32_t layout_channels(const foreign_layout *p){return p?p->channels:-1;}
uint64_t layout_mask(const foreign_layout *p){return p?p->mask:0;}
int32_t layout_array_channel_sum(const foreign_layout *p,uint32_t n){int32_t s=0;if(!p)return 0;for(uint32_t i=0;i<n;i++)s+=p[i].channels;return s;}
uint32_t pointer_array_first_sum(uint8_t **p,uint32_t n){uint32_t s=0;if(!p)return 0;for(uint32_t i=0;i<n;i++)if(p[i])s+=p[i][0];return s;}
static volatile int layout_probe_started=0;
void layout_probe_reset(void){layout_probe_started=0;}
int32_t layout_probe_is_started(void){return layout_probe_started;}
int32_t layout_channels_delayed(const foreign_layout *p,int32_t ms){layout_probe_started=1;foreign_sleep_ms(ms);return p?p->channels:-1;}
uint32_t pointer_array_first_sum_delayed(uint8_t **p,uint32_t n,int32_t ms){foreign_sleep_ms(ms);return pointer_array_first_sum(p,n);}
static volatile int32_t device_free_seen=0;
void device_free_reset(void){device_free_seen=0;}
int32_t device_free_count(void){return device_free_seen;}
void* device_alloc_64(void){void*p=malloc(64);if(p)memset(p,0x5a,64);return p;}
void device_free(void*p){if(p){free(p);__sync_add_and_fetch(&device_free_seen,1);}}

int32_t device_consume(void *p){return p?1:0;}
typedef int32_t (*foreign_binary_i32_cb)(int32_t,int32_t);
int32_t callback_apply_i32(foreign_binary_i32_cb cb,int32_t a,int32_t b){return cb?cb(a,b):-1;}
int32_t callback_apply_twice_i32(foreign_binary_i32_cb cb,int32_t a,int32_t b){if(!cb)return -1;return cb(a,b)+cb(b,a);}
#ifndef _WIN32
#include <pthread.h>
typedef struct foreign_cb_thread_args { foreign_binary_i32_cb cb; int32_t a; int32_t b; int32_t result; } foreign_cb_thread_args;
static void* foreign_cb_thread_main(void *vp){ foreign_cb_thread_args *x=(foreign_cb_thread_args*)vp; x->result=x->cb?x->cb(x->a,x->b):-1; return 0; }
int32_t callback_apply_other_thread_i32(foreign_binary_i32_cb cb,int32_t a,int32_t b){ foreign_cb_thread_args x={cb,a,b,-1}; pthread_t t; if(pthread_create(&t,0,foreign_cb_thread_main,&x)!=0)return -2; pthread_join(t,0); return x.result; }
#endif

/* v0.14 scalar-resource / errno fixtures */
#include <errno.h>
static volatile int32_t fake_handle_close_seen=0;
void fake_handle_close_reset(void){fake_handle_close_seen=0;}
int32_t fake_handle_close_count(void){return fake_handle_close_seen;}
int32_t fake_handle_new(void){return 123;}
int32_t fake_handle_close(int32_t h){if(h==123||h==88)__sync_add_and_fetch(&fake_handle_close_seen,1);return 0;}
int32_t fake_handle_value(int32_t h){return h;}
int32_t fake_errno_failure(void){errno=EINVAL;return -1;}
int32_t fake_out_handle_success(int32_t *out){if(!out){errno=EINVAL;return -1;}*out=88;return 0;}
int32_t fake_out_handle_failure(int32_t *out){if(out)*out=99;errno=EINVAL;return -1;}
int32_t fake_handle_invalid(void){errno=EINVAL;return -1;}
static volatile int32_t fake_handle_probe_started=0;
void fake_handle_probe_reset(void){fake_handle_probe_started=0;}
int32_t fake_handle_probe_is_started(void){return fake_handle_probe_started;}
int32_t fake_handle_value_delayed(int32_t h,int32_t ms){fake_handle_probe_started=1;foreign_sleep_ms(ms);return h;}
static uint8_t raw_bytes_fixture[8]={0xde,0xad,0x00,0xbe,0xef,0x01,0x02,0x03};
static void *raw_pointer_slots[2]={raw_bytes_fixture,raw_bytes_fixture+4};
void* raw_bytes_address(void){return raw_bytes_fixture;}
void* raw_slots_address(void){return raw_pointer_slots;}

typedef struct foreign_graph_iovec {
    void *iov_base;
    uint64_t iov_len;
} foreign_graph_iovec;

typedef struct foreign_graph_msg {
    foreign_graph_iovec *msg_iov;
    void *msg_control;
    uint64_t msg_controllen;
} foreign_graph_msg;

static volatile int graph_probe_started=0;
void graph_probe_reset(void){ graph_probe_started=0; }
int32_t graph_probe_is_started(void){ return graph_probe_started; }
uint32_t graph_sum(const foreign_graph_msg *m){
    if(!m || !m->msg_iov || !m->msg_iov->iov_base) return 0;
    const uint8_t *p=(const uint8_t*)m->msg_iov->iov_base;
    uint32_t sum=0;
    for(uint64_t i=0;i<m->msg_iov->iov_len;i++) sum+=p[i];
    if(m->msg_control){
        const uint8_t *c=(const uint8_t*)m->msg_control;
        for(uint64_t i=0;i<m->msg_controllen;i++) sum+=c[i];
    }
    return sum;
}
uint32_t graph_sum_delayed(const foreign_graph_msg *m,int32_t ms){
    graph_probe_started=1;
    foreign_sleep_ms(ms);
    return graph_sum(m);
}

/* v0.22.4 exact 8-bit scalar / struct-field fixtures. */
typedef struct foreign_byte_fields {
    int8_t signed_byte;
    uint8_t unsigned_byte;
} foreign_byte_fields;

int8_t echo_i8(int8_t value){ return value; }
uint8_t echo_u8(uint8_t value){ return value; }
int32_t add_i8_u8(int8_t a,uint8_t b){ return (int32_t)a + (int32_t)b; }
void byte_fields_fill(foreign_byte_fields *p,int8_t s,uint8_t u){ if(p){p->signed_byte=s;p->unsigned_byte=u;} }
int32_t byte_fields_sum(const foreign_byte_fields *p){ return p ? (int32_t)p->signed_byte + (int32_t)p->unsigned_byte : 0; }

/* v0.22.6 ABI-derived native C scalar fixtures. */
#include <stddef.h>
#ifndef _WIN32
#include <sys/types.h>
#include <sys/socket.h>
#endif
long echo_c_long(long value){ return value; }
unsigned long echo_c_ulong(unsigned long value){ return value; }
size_t echo_c_size_t(size_t value){ return value; }
ptrdiff_t echo_c_ptrdiff_t(ptrdiff_t value){ return value; }
#ifndef _WIN32
ssize_t echo_c_ssize_t(ssize_t value){ return value; }
socklen_t echo_c_socklen_t(socklen_t value){ return value; }
#endif

typedef struct foreign_native_scalars {
    long signed_long;
    unsigned long unsigned_long;
    size_t size_value;
    ptrdiff_t diff_value;
#ifndef _WIN32
    ssize_t ssize_value;
    socklen_t socklen_value;
#endif
} foreign_native_scalars;

long native_scalars_long(const foreign_native_scalars *p){ return p ? p->signed_long : 0; }
size_t native_scalars_size(const foreign_native_scalars *p){ return p ? p->size_value : 0; }
#ifndef _WIN32
ssize_t native_scalars_ssize(const foreign_native_scalars *p){ return p ? p->ssize_value : 0; }
socklen_t native_scalars_socklen(const foreign_native_scalars *p){ return p ? p->socklen_value : 0; }
#endif
