#include "wire_ui_loader.h"
#include "wire_test_renderer.h"
#include <stdio.h>
static uint64_t count(void*c){(void)c;return 200000;}
static size_t range(void*c,uint64_t s,size_t n,WireListRow*out){(void)c;for(size_t i=0;i<n;i++)out[i]=(WireListRow){s+i,"id","from","subject","date"};return n;}
int main(void){WireRenderer*r=wire_test_renderer_new();WireListSource src={0,count,range};WireNamedListSource ls[]={{"folders",&src},{"messages",&src}};WireUILoadContext c={r,ls,2,0,0};WireHandle root=0;if(wire_ui_load_file("examples/mailreader/mailreader.xml",&c,&root)!=WIRE_OK||root!=1)return 2;r->v->destroy(r);r=wire_test_renderer_new();c.renderer=r;if(wire_ui_load_file("examples/mailreader/mailreader.wire",&c,&root)!=WIRE_OK||root!=1)return 3;r->v->destroy(r);puts("wire-ui-loader=PASS formats=xml/wire root=1");return 0;}
