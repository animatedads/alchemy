#include "wire_ui_loader.h"
#include "wire_test_renderer.h"
#include <stdio.h>
#include <string.h>
typedef struct { int seen; WireHandle handle; uint64_t start; size_t count; char source[32]; } Capture;
static uint64_t count(void*c){(void)c;return 200000;}
static size_t range(void*c,uint64_t s,size_t n,WireListRow*out){(void)c;for(size_t i=0;i<n;i++)out[i]=(WireListRow){s+i,"id","from","subject","date"};return n;}
static void virtual_loaded(void*ctx,const char*id,WireHandle h,const char*source,uint64_t start,size_t n){Capture*c=ctx;if(id&&!strcmp(id,"messages")){c->seen++;c->handle=h;c->start=start;c->count=n;snprintf(c->source,sizeof c->source,"%s",source?source:"");}}
static int one(const char*path){WireRenderer*r=wire_test_renderer_new();WireListSource src={0,count,range};WireNamedListSource ls[]={{"folders",&src},{"messages",&src}};Capture cap={0};WireUILoadContext c={r,ls,2,0,0,virtual_loaded,&cap};WireHandle root=0;WireResult rc=wire_ui_load_file(path,&c,&root);int ok=rc==WIRE_OK&&root==1&&cap.seen==1&&cap.handle!=0&&cap.start==0&&cap.count==100&&!strcmp(cap.source,"messages");r->v->destroy(r);return ok;}
int main(void){if(!one("examples/mailreader/mailreader.xml"))return 2;if(!one("examples/mailreader/mailreader.wire"))return 3;puts("wire-ui-loader=PASS formats=xml/wire root=1 virtual-policy=messages:0+100");return 0;}
