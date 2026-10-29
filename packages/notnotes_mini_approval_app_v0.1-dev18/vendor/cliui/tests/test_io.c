#include "oorexx_cli_ui.h"
#include <assert.h>
#include <string.h>
typedef struct { unsigned char out[1024]; size_t out_n; const unsigned char *in; size_t in_n; } Mem;
static int mw(void*ctx,const unsigned char*b,size_t n){Mem*m=(Mem*)ctx;if(m->out_n+n>sizeof m->out)return -1;memcpy(m->out+m->out_n,b,n);m->out_n+=n;return 0;}
static int mr(void*ctx,unsigned char*b,size_t cap,int timeout,size_t*n){Mem*m=(Mem*)ctx;(void)timeout;size_t q=m->in_n<cap?m->in_n:cap;if(q)memcpy(b,m->in,q);m->in+=q;m->in_n-=q;*n=q;return 0;}
static int got_left=0;
static void dispatch(void*ctx,const CliUiEvent*e){(void)ctx;if(e->kind==CLIUI_EVENT_KEY&&e->key.kind==CLIUI_KEY_LEFT)got_left++;}
int main(void){static const unsigned char input[]={27,'[','D'};Mem m={{0},0,input,sizeof input};CliUiIo io={&m,mw,mr,0};CliUiRenderer*r=cliui_ansi_create_with_io(&io);assert(r&&r->v->abi==2);r->v->set_dispatch(r,dispatch,0);assert(r->v->begin_frame(r)==CLIUI_OK);assert(r->v->draw_text(r,1,2,"hello",CLIUI_STYLE_KEYWORD)==CLIUI_OK);assert(r->v->poll(r,0)==CLIUI_OK);assert(got_left==1);assert(m.out_n>0);r->v->destroy(r);return 0;}
