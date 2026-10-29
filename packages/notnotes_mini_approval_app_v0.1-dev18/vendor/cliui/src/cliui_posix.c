#include "oorexx_cli_ui.h"
#if defined(__unix__) || defined(__APPLE__)
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/select.h>
typedef struct { int in_fd,out_fd; } PosixIo;
static int pwrite(void *ctx,const unsigned char*b,size_t n){PosixIo*p=(PosixIo*)ctx;size_t off=0;while(off<n){ssize_t q=write(p->out_fd,b+off,n-off);if(q<0){if(errno==EINTR)continue;return -1;}if(q==0)return -1;off+=(size_t)q;}return 0;}
static int pread(void *ctx,unsigned char*b,size_t cap,int timeout_ms,size_t*nread){PosixIo*p=(PosixIo*)ctx;fd_set f;FD_ZERO(&f);FD_SET(p->in_fd,&f);struct timeval tv,*pt=0;if(timeout_ms>=0){tv.tv_sec=timeout_ms/1000;tv.tv_usec=(timeout_ms%1000)*1000;pt=&tv;}int rc;do{rc=select(p->in_fd+1,&f,0,0,pt);}while(rc<0&&errno==EINTR);if(rc<0)return -1;if(rc==0){*nread=0;return 0;}ssize_t q=read(p->in_fd,b,cap);if(q<0)return -1;*nread=(size_t)q;return 0;}
CliUiRenderer *cliui_ansi_create(int in_fd,int out_fd){PosixIo *p=(PosixIo*)calloc(1,sizeof*p);if(!p)return NULL;p->in_fd=in_fd;p->out_fd=out_fd;CliUiIo io={p,pwrite,pread,free};CliUiRenderer*r=cliui_ansi_create_with_io(&io);/* renderer owns only this tiny provider context; it never changes fd modes */if(!r)free(p);return r;}
#else
CliUiRenderer *cliui_ansi_create(int in_fd,int out_fd){(void)in_fd;(void)out_fd;return NULL;}
#endif
