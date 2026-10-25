#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#ifndef STORAGE_FUSE3_PROTOCOL_ONLY
#define FUSE_USE_VERSION 35
#include <fuse3/fuse.h>
#endif

#define SF_PROTOCOL "SF1"
#define SF_MAX_REPLY (8u * 1024u * 1024u)
#define SF_VIRTUAL_FH UINT64_MAX
#define SF_NATIVE_API "storage.fabric.fuse.native/0.1"
#define SF_NATIVE_PROBE "storage-fuse3.probe/1"

#ifndef STORAGE_FUSE3_PROTOCOL_ONLY
static const char *g_socket_path = "/tmp/oorexx-storage-fuse.sock";
#endif

static char hex_digit(unsigned v) { return (char)(v < 10 ? '0' + v : 'A' + (v - 10)); }
static int hex_value(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static char *hex_encode(const void *data, size_t len) {
    const unsigned char *p = (const unsigned char *)data;
    char *out = (char *)malloc(len * 2 + 1);
    if (!out) return NULL;
    for (size_t i = 0; i < len; ++i) {
        out[i * 2] = hex_digit(p[i] >> 4);
        out[i * 2 + 1] = hex_digit(p[i] & 15);
    }
    out[len * 2] = '\0';
    return out;
}

static unsigned char *hex_decode(const char *hex, size_t *out_len) {
    size_t n = strlen(hex);
    if (n % 2) { errno = EPROTO; return NULL; }
    unsigned char *out = (unsigned char *)malloc(n / 2 + 1);
    if (!out) return NULL;
    for (size_t i = 0; i < n; i += 2) {
        int a = hex_value(hex[i]), b = hex_value(hex[i + 1]);
        if (a < 0 || b < 0) { free(out); errno = EPROTO; return NULL; }
        out[i / 2] = (unsigned char)((a << 4) | b);
    }
    out[n / 2] = 0;
    if (out_len) *out_len = n / 2;
    return out;
}

struct sf_fields { char *storage; char **v; size_t n; };
static void sf_fields_free(struct sf_fields *f) {
    if (!f) return;
    free(f->v); free(f->storage); memset(f, 0, sizeof(*f));
}
static int sf_split(const char *line, struct sf_fields *out) {
    memset(out, 0, sizeof(*out));
    out->storage = strdup(line ? line : "");
    if (!out->storage) return -1;
    size_t cap = 8;
    out->v = (char **)calloc(cap, sizeof(char *));
    if (!out->v) { sf_fields_free(out); return -1; }
    char *s = out->storage;
    while (*s) {
        if (out->n == cap) {
            cap *= 2;
            char **nv = (char **)realloc(out->v, cap * sizeof(char *));
            if (!nv) { sf_fields_free(out); return -1; }
            out->v = nv;
        }
        out->v[out->n++] = s;
        char *t = strchr(s, '\t');
        if (!t) break;
        *t = '\0'; s = t + 1;
    }
    if (out->n == 0) { out->v[out->n++] = out->storage; }
    char *last = out->v[out->n - 1];
    size_t l = strlen(last);
    while (l && (last[l - 1] == '\n' || last[l - 1] == '\r')) last[--l] = '\0';
    return 0;
}

#ifndef STORAGE_FUSE3_PROTOCOL_ONLY
static int send_all(int fd, const char *p, size_t n) {
    while (n) {
        ssize_t w = send(fd, p, n, MSG_NOSIGNAL);
        if (w < 0) { if (errno == EINTR) continue; return -1; }
        if (w == 0) { errno = EPIPE; return -1; }
        p += (size_t)w; n -= (size_t)w;
    }
    return 0;
}

static char *sf_rpc(const char *request) {
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return NULL;
    struct sockaddr_un un;
    memset(&un, 0, sizeof(un)); un.sun_family = AF_UNIX;
    if (strlen(g_socket_path) >= sizeof(un.sun_path)) { close(fd); errno = ENAMETOOLONG; return NULL; }
    strcpy(un.sun_path, g_socket_path);
    if (connect(fd, (struct sockaddr *)&un, sizeof(un)) < 0) { close(fd); return NULL; }
    if (send_all(fd, request, strlen(request)) < 0) { close(fd); return NULL; }
    size_t cap = 4096, used = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) { close(fd); return NULL; }
    for (;;) {
        if (used + 2048 + 1 > cap) {
            size_t nc = cap * 2;
            if (nc > SF_MAX_REPLY) nc = SF_MAX_REPLY;
            if (nc <= cap) { free(buf); close(fd); errno = EOVERFLOW; return NULL; }
            char *nb = (char *)realloc(buf, nc); if (!nb) { free(buf); close(fd); return NULL; }
            buf = nb; cap = nc;
        }
        ssize_t r = recv(fd, buf + used, cap - used - 1, 0);
        if (r < 0) { if (errno == EINTR) continue; free(buf); close(fd); return NULL; }
        if (r == 0) break;
        used += (size_t)r; buf[used] = '\0';
        if (memchr(buf, '\n', used)) break;
    }
    close(fd); buf[used] = '\0'; return buf;
}

static int sf_rpc_fields(const char *request, struct sf_fields *out) {
    char *reply = sf_rpc(request);
    if (!reply) return -errno;
    int rc = sf_split(reply, out); free(reply);
    if (rc < 0) return -ENOMEM;
    if (out->n < 2 || strcmp(out->v[0], SF_PROTOCOL) != 0) { sf_fields_free(out); return -EPROTO; }
    char *end = NULL; long e = strtol(out->v[1], &end, 10);
    if (!end || *end || e < 0 || e > INT_MAX) { sf_fields_free(out); return -EPROTO; }
    if (e) { int neg = -(int)e; sf_fields_free(out); return neg; }
    return 0;
}

static char *req1(const char *op, const char *s) {
    char *h = hex_encode(s, strlen(s)); if (!h) return NULL;
    size_t n = strlen(op) + strlen(h) + 8;
    char *r = (char *)malloc(n); if (r) snprintf(r, n, "SF1\t%s\t%s\n", op, h);
    free(h); return r;
}
static char *req2s(const char *op, const char *a, const char *b) {
    char *ha=hex_encode(a,strlen(a)), *hb=hex_encode(b,strlen(b));
    if (!ha || !hb) { free(ha); free(hb); return NULL; }
    size_t n=strlen(op)+strlen(ha)+strlen(hb)+10; char *r=malloc(n);
    if (r) snprintf(r,n,"SF1\t%s\t%s\t%s\n",op,ha,hb);
    free(ha); free(hb);
    return r;
}
#endif

#ifndef STORAGE_FUSE3_PROTOCOL_ONLY
static char *handle_hex(uint64_t fh);
static const char *mode_from_flags(int flags) {
    switch (flags & O_ACCMODE) { case O_WRONLY: return "WRITE"; case O_RDWR: return "RW"; default: return "READ"; }
}
static int path_is_system_stream(const char *path) { return strstr(path, ":$") != NULL; }

static int sf_getattr(const char *path, struct stat *st, struct fuse_file_info *fi) {
    (void)fi; memset(st,0,sizeof(*st)); char *req=req1("GETATTR",path); if(!req) return -ENOMEM;
    struct sf_fields f; int rc=sf_rpc_fields(req,&f); free(req); if(rc) return rc;
    if(f.n<6){sf_fields_free(&f);return -EPROTO;} size_t kl=0; unsigned char *kind=hex_decode(f.v[2],&kl); if(!kind){sf_fields_free(&f);return -EPROTO;}
    long long size=strtoll(f.v[3],NULL,10);
    if(strcmp((char*)kind,"DIRECTORY")==0){st->st_mode=S_IFDIR|0755;st->st_nlink=2;}
    else {st->st_mode=S_IFREG|((strcmp((char*)kind,"CONTROL")==0)?0444:0644);st->st_nlink=1;st->st_size=(off_t)size;}
    free(kind); sf_fields_free(&f); return 0;
}
static int sf_readdir(const char *path, void *buf, fuse_fill_dir_t filler, off_t off, struct fuse_file_info *fi, enum fuse_readdir_flags flags){
    (void)off;(void)fi;(void)flags; filler(buf,".",NULL,0,0); filler(buf,"..",NULL,0,0);
    char *req=req1("READDIR",path);if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(rc)return rc;
    if(f.n<3){sf_fields_free(&f);return -EPROTO;} long count=strtol(f.v[2],NULL,10); if(count<0 || (size_t)(3+count)>f.n){sf_fields_free(&f);return -EPROTO;}
    for(long i=0;i<count;i++){size_t nl=0;unsigned char*n=hex_decode(f.v[3+i],&nl);if(!n){sf_fields_free(&f);return -EPROTO;} if(filler(buf,(char*)n,NULL,0,0)){free(n);break;}free(n);} sf_fields_free(&f);return 0;
}
static int sf_open(const char *path, struct fuse_file_info *fi){
    /* First native qualification deliberately bypasses the kernel page cache.
     * StorageFuse owns writer-handle/generation ordering; writeback caching or
     * writable mmap would otherwise add a second mutation authority. */
    fi->direct_io=1;
    fi->keep_cache=0;
    if(path_is_system_stream(path)){fi->fh=SF_VIRTUAL_FH;return 0;}
    const char*m=mode_from_flags(fi->flags);char*req=req2s("OPEN",path,m);if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(rc)return rc;
    if(f.n<3){sf_fields_free(&f);return -EPROTO;} size_t hl=0;unsigned char*h=hex_decode(f.v[2],&hl);if(!h){sf_fields_free(&f);return -EPROTO;} if(hl<2||h[0]!='h'){free(h);sf_fields_free(&f);return -EPROTO;} fi->fh=strtoull((char*)h+1,NULL,10);free(h);sf_fields_free(&f);
    if(fi->flags&O_TRUNC){
        char raw[64]; snprintf(raw,sizeof(raw),"h%" PRIu64,fi->fh);
        char *hh=hex_encode(raw,strlen(raw)); if(!hh) return -ENOMEM;
        size_t rn=strlen(hh)+40; char *tr=malloc(rn); if(!tr){free(hh);return -ENOMEM;}
        snprintf(tr,rn,"SF1\tTRUNCATEH\t%s\t0\n",hh); free(hh);
        struct sf_fields tf; int trc=sf_rpc_fields(tr,&tf); free(tr);
        if(!trc) sf_fields_free(&tf);
        if(trc) {
            char *rh=handle_hex(fi->fh);
            if(rh){size_t rn2=strlen(rh)+32;char*rr=malloc(rn2);if(rr){snprintf(rr,rn2,"SF1\tRELEASE\t%s\n",rh);struct sf_fields rf;if(sf_rpc_fields(rr,&rf)==0)sf_fields_free(&rf);free(rr);}free(rh);}
            return trc;
        }
    }
    return 0;
}
static int sf_create(const char *path, mode_t mode, struct fuse_file_info *fi){(void)mode;fi->direct_io=1;fi->keep_cache=0;const char*m=mode_from_flags(fi->flags);char*req=req2s("CREATE",path,m);if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(rc)return rc;if(f.n<3){sf_fields_free(&f);return -EPROTO;}size_t hl=0;unsigned char*h=hex_decode(f.v[2],&hl);if(!h){sf_fields_free(&f);return -EPROTO;}fi->fh=strtoull((char*)h+1,NULL,10);free(h);sf_fields_free(&f);return 0;}
static char *handle_hex(uint64_t fh){char tmp[64];snprintf(tmp,sizeof(tmp),"h%" PRIu64,fh);return hex_encode(tmp,strlen(tmp));}
static int sf_read(const char *path,char *buf,size_t size,off_t off,struct fuse_file_info *fi){
    if(fi && fi->fh==SF_VIRTUAL_FH){char*req=req1("VREAD",path);if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(rc)return rc;if(f.n<3){sf_fields_free(&f);return -EPROTO;}size_t dl=0;unsigned char*d=hex_decode(f.v[2],&dl);if(!d){sf_fields_free(&f);return -EPROTO;}if((size_t)off>=dl){free(d);sf_fields_free(&f);return 0;}size_t n=dl-(size_t)off;if(n>size)n=size;memcpy(buf,d+off,n);free(d);sf_fields_free(&f);return (int)n;}
    char*hh=handle_hex(fi->fh);if(!hh)return -ENOMEM;size_t n=strlen(hh)+96;char*req=malloc(n);if(!req){free(hh);return -ENOMEM;}snprintf(req,n,"SF1\tREAD\t%s\t%lld\t%zu\n",hh,(long long)off,size);free(hh);struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(rc)return rc;if(f.n<3){sf_fields_free(&f);return -EPROTO;}size_t dl=0;unsigned char*d=hex_decode(f.v[2],&dl);if(!d){sf_fields_free(&f);return -EPROTO;}if(dl>size)dl=size;memcpy(buf,d,dl);free(d);sf_fields_free(&f);return (int)dl;
}
static int sf_write(const char *path,const char *buf,size_t size,off_t off,struct fuse_file_info *fi){(void)path;char*hh=handle_hex(fi->fh),*dh=hex_encode(buf,size);if(!hh||!dh){free(hh);free(dh);return -ENOMEM;}size_t n=strlen(hh)+strlen(dh)+96;char*req=malloc(n);if(!req){free(hh);free(dh);return -ENOMEM;}snprintf(req,n,"SF1\tWRITE\t%s\t%lld\t%s\n",hh,(long long)off,dh);free(hh);free(dh);struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(rc)return rc;if(f.n<3){sf_fields_free(&f);return -EPROTO;}long w=strtol(f.v[2],NULL,10);sf_fields_free(&f);return (int)w;}
static int sf_release(const char *path,struct fuse_file_info *fi){(void)path;if(fi->fh==SF_VIRTUAL_FH)return 0;char*hh=handle_hex(fi->fh);if(!hh)return -ENOMEM;size_t n=strlen(hh)+32;char*req=malloc(n);snprintf(req,n,"SF1\tRELEASE\t%s\n",hh);free(hh);struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(!rc)sf_fields_free(&f);return rc;}
static int sf_mkdir(const char *path,mode_t mode){(void)mode;char*req=req1("MKDIR",path);if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(!rc)sf_fields_free(&f);return rc;}
static int sf_unlink(const char *path){char*req=req1("UNLINK",path);if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(!rc)sf_fields_free(&f);return rc;}
static int sf_rmdir(const char *path){char*req=req1("RMDIR",path);if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(!rc)sf_fields_free(&f);return rc;}
static int sf_rename(const char *a,const char *b,unsigned flags){if(flags)return -EINVAL;char*req=req2s("RENAME",a,b);if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(!rc)sf_fields_free(&f);return rc;}
static int sf_truncate(const char *path,off_t size,struct fuse_file_info *fi){char*req=NULL;if(fi && fi->fh!=SF_VIRTUAL_FH){char*hh=handle_hex(fi->fh);if(!hh)return -ENOMEM;size_t n=strlen(hh)+96;req=malloc(n);if(req)snprintf(req,n,"SF1\tTRUNCATEH\t%s\t%lld\n",hh,(long long)size);free(hh);}else{char*ph=hex_encode(path,strlen(path));if(!ph)return -ENOMEM;size_t n=strlen(ph)+96;req=malloc(n);if(req)snprintf(req,n,"SF1\tTRUNCATE\t%s\t%lld\n",ph,(long long)size);free(ph);}if(!req)return -ENOMEM;struct sf_fields f;int rc=sf_rpc_fields(req,&f);free(req);if(!rc)sf_fields_free(&f);return rc;}

static struct fuse_operations sf_ops={.getattr=sf_getattr,.readdir=sf_readdir,.open=sf_open,.create=sf_create,.read=sf_read,.write=sf_write,.release=sf_release,.mkdir=sf_mkdir,.unlink=sf_unlink,.rmdir=sf_rmdir,.rename=sf_rename,.truncate=sf_truncate};

static int sf_native_probe(void) {
    int runtime = fuse_version();
    if (runtime <= 0) {
        fprintf(stderr, "storage-fuse3: libfuse runtime version unavailable\n");
        return 3;
    }
    printf("%s api=%s protocol=%s fuse_use_version=%d libfuse_runtime=%d io=direct_io authority=rpc\n",
           SF_NATIVE_PROBE, SF_NATIVE_API, SF_PROTOCOL, FUSE_USE_VERSION, runtime);
    return 0;
}

int main(int argc,char**argv){
    if(argc==2 && strcmp(argv[1],"--storage-fuse-probe")==0) return sf_native_probe();
    const char*env=getenv("STORAGE_FUSE_SOCKET");
    if(env&&*env)g_socket_path=env;
    return fuse_main(argc,argv,&sf_ops,NULL);
}
#else
int main(void){
    const unsigned char sample[]={'a',0,'b','\n',':'}; char*h=hex_encode(sample,sizeof(sample)); if(!h)return 2; size_t n=0;unsigned char*d=hex_decode(h,&n);int ok=(n==sizeof(sample)&&memcmp(sample,d,n)==0);free(h);free(d);
    struct sf_fields f;if(sf_split("SF1\t0\t4142\n",&f)<0)return 3;ok=ok&&f.n==3&&!strcmp(f.v[0],"SF1")&&!strcmp(f.v[1],"0")&&!strcmp(f.v[2],"4142");sf_fields_free(&f);
    if (!ok) return 4;
    puts("PASS storage_fuse3 protocol helpers");
    return 0;
}
#endif
