#include <stdint.h>
#include <stddef.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  void *data; size_t byte_size; int readonly; int device_type; int device_id;
  int dtype_code; int dtype_bits; int dtype_lanes; size_t ndim;
  const int64_t *shape; const int64_t *strides_bytes; void *token;
} TensorExportV1;
typedef int (*Acquire)(uint64_t,TensorExportV1*);
typedef void (*Release)(void*);
static int get(uint64_t id, TensorExportV1 *x, Acquire *a, Release *r){
  *a=(Acquire)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_export_acquire_v1");
  *r=(Release)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_export_release_v1");
  if(!*a||!*r)return -90; return (*a)(id,x);
}
int tensor_rank(uint64_t id){TensorExportV1 x={0};Acquire a;Release r;if(get(id,&x,&a,&r))return -1;int n=(int)x.ndim;r(x.token);return n;}
int64_t tensor_dim(uint64_t id,uint64_t i){TensorExportV1 x={0};Acquire a;Release r;if(get(id,&x,&a,&r)||i>=x.ndim)return -1;int64_t v=x.shape[i];r(x.token);return v;}
int64_t tensor_stride(uint64_t id,uint64_t i){TensorExportV1 x={0};Acquire a;Release r;if(get(id,&x,&a,&r)||i>=x.ndim)return -1;int64_t v=x.strides_bytes[i];r(x.token);return v;}
int tensor_dtype_bits(uint64_t id){TensorExportV1 x={0};Acquire a;Release r;if(get(id,&x,&a,&r))return -1;int v=x.dtype_bits;r(x.token);return v;}
int tensor_device_type(uint64_t id){TensorExportV1 x={0};Acquire a;Release r;if(get(id,&x,&a,&r))return -1;int v=x.device_type;r(x.token);return v;}
int64_t tensor_sum_u8(uint64_t id){TensorExportV1 x={0};Acquire a;Release r;if(get(id,&x,&a,&r)||x.device_type!=1||x.dtype_bits!=8)return -1;uint8_t*p=(uint8_t*)x.data;int64_t s=0;for(size_t i=0;i<x.byte_size;i++)s+=p[i];r(x.token);return s;}
int tensor_fill_u8(uint64_t id,uint32_t v){TensorExportV1 x={0};Acquire a;Release r;if(get(id,&x,&a,&r)||x.device_type!=1||x.readonly||x.dtype_bits!=8)return -1;uint8_t*p=(uint8_t*)x.data;for(size_t i=0;i<x.byte_size;i++)p[i]=(uint8_t)v;r(x.token);return 0;}
#include <unistd.h>
static volatile int tensor_probe_started=0;
int tensor_probe_reset(void){tensor_probe_started=0;return 0;}
int tensor_probe_is_started(void){return tensor_probe_started;}
int64_t tensor_delayed_sum_u8(uint64_t id,uint32_t millis){TensorExportV1 x={0};Acquire a;Release r;if(get(id,&x,&a,&r)||x.device_type!=1||x.dtype_bits!=8)return -1;tensor_probe_started=1;usleep((useconds_t)millis*1000);uint8_t*p=(uint8_t*)x.data;int64_t s=0;for(size_t i=0;i<x.byte_size;i++)s+=p[i];r(x.token);return s;}

typedef struct {
  void *data; size_t byte_size; int readonly; int device_type; int device_id;
  int dtype_code; int dtype_bits; int dtype_lanes; size_t ndim;
  const int64_t *shape; const int64_t *strides_bytes;
  void *token; void (*release)(void*);
  const char *execution_provider; uint64_t stream_handle; uint64_t fence_handle;
  int sync_policy; int affinity_kind;
} TensorImportV2;
typedef struct {
  void *data; size_t byte_size; int readonly; int device_type; int device_id;
  int dtype_code; int dtype_bits; int dtype_lanes; size_t ndim;
  const int64_t *shape; const int64_t *strides_bytes; void *token;
  const char *execution_provider; uint64_t stream_handle; uint64_t fence_handle;
  int sync_policy; int affinity_kind;
} TensorExportV2;
typedef uint64_t (*ImportV2)(const TensorImportV2*);
typedef int (*AcquireV2)(uint64_t,TensorExportV2*);
typedef void (*ReleaseV2)(void*);
typedef int (*CloseV1)(uint64_t);
static void free_device_fake(void *p){free(p);}
static void promote_runtime(void){
  void *h=dlopen("libforeign_runtime.so",RTLD_NOW|RTLD_NOLOAD|RTLD_GLOBAL); if(h) dlclose(h);
}
uint64_t tensor_fake_device_new(void){
  promote_runtime();
  ImportV2 imp=(ImportV2)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_import_v2"); if(!imp)return 0;
  uint8_t *p=(uint8_t*)malloc(32); if(!p)return 0; for(int i=0;i<32;i++)p[i]=(uint8_t)i;
  static const int64_t shape[1]={32}, stride[1]={1};
  TensorImportV2 in={p,32,0,2,0,1,8,1,1,shape,stride,p,free_device_fake,"synthetic.cuda",0x1111,0x2222,1,2};
  uint64_t id=imp(&in); if(!id)free(p); return id;
}
static int get2(uint64_t id,TensorExportV2*x,AcquireV2*a,ReleaseV2*r){
  promote_runtime();
  *a=(AcquireV2)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_export_acquire_v2"); *r=(ReleaseV2)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_export_release_v2");
  if(!*a||!*r)return -90; return (*a)(id,x);
}
int tensor_v2_device_type(uint64_t id){TensorExportV2 x={0};AcquireV2 a;ReleaseV2 r;if(get2(id,&x,&a,&r))return -1;int v=x.device_type;r(x.token);return v;}
uint64_t tensor_v2_stream(uint64_t id){TensorExportV2 x={0};AcquireV2 a;ReleaseV2 r;if(get2(id,&x,&a,&r))return 0;uint64_t v=x.stream_handle;r(x.token);return v;}
uint64_t tensor_v2_fence(uint64_t id){TensorExportV2 x={0};AcquireV2 a;ReleaseV2 r;if(get2(id,&x,&a,&r))return 0;uint64_t v=x.fence_handle;r(x.token);return v;}
int tensor_v2_sync_policy(uint64_t id){TensorExportV2 x={0};AcquireV2 a;ReleaseV2 r;if(get2(id,&x,&a,&r))return -1;int v=x.sync_policy;r(x.token);return v;}
int tensor_v2_affinity(uint64_t id){TensorExportV2 x={0};AcquireV2 a;ReleaseV2 r;if(get2(id,&x,&a,&r))return -1;int v=x.affinity_kind;r(x.token);return v;}
int tensor_v2_provider_is_synthetic_cuda(uint64_t id){TensorExportV2 x={0};AcquireV2 a;ReleaseV2 r;if(get2(id,&x,&a,&r))return 0;int ok=x.execution_provider&&strcmp(x.execution_provider,"synthetic.cuda")==0;r(x.token);return ok;}
int tensor_v2_cpu_deref_allowed(uint64_t id){TensorExportV2 x={0};AcquireV2 a;ReleaseV2 r;if(get2(id,&x,&a,&r))return 0;int ok=x.device_type==1;r(x.token);return ok;}
int tensor_v2_close(uint64_t id){CloseV1 c=(CloseV1)dlsym(RTLD_DEFAULT,"rexx_foreign_tensor_close_v1");return c?c(id):-90;}
static volatile int tensor_v2_probe_started=0;
int tensor_v2_probe_reset(void){tensor_v2_probe_started=0;return 0;}
int tensor_v2_probe_is_started(void){return tensor_v2_probe_started;}
int tensor_v2_delayed_context(uint64_t id,uint32_t millis){TensorExportV2 x={0};AcquireV2 a;ReleaseV2 r;if(get2(id,&x,&a,&r))return -1;tensor_v2_probe_started=1;usleep((useconds_t)millis*1000);int v=x.device_type;r(x.token);return v;}
