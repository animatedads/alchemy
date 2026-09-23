#include "wire_filter_window.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef struct { uint64_t count; unsigned count_calls, range_calls; uint64_t starts[32]; size_t asks[32]; char ids[256][48]; } Store;
static uint64_t count_rows(void *ctx){Store*s=ctx;s->count_calls++;return s->count;}
static size_t range_rows(void *ctx,uint64_t start,size_t n,WireListRow*out){Store*s=ctx;unsigned c=s->range_calls++;s->starts[c]=start;s->asks[c]=n;if(start>=s->count)return 0;if(start+n>s->count)n=(size_t)(s->count-start);for(size_t i=0;i<n;i++){uint64_t id=start+i+1;snprintf(s->ids[i],sizeof s->ids[i],"INBOX|4242|%llu",(unsigned long long)id);out[i].identity=id;out[i].stable_id=s->ids[i];out[i].subject="synthetic";}return n;}
typedef struct { unsigned calls; } Pred;
static int every_fourth(void*ctx,const WireListRow*r){Pred*p=ctx;p->calls++;return (r->identity%4)==0;}
int main(void){
 Store s={.count=200000}; Pred p={0}; WireListSource src={&s,count_rows,range_rows}; WireFilterWindow w;
 wire_filter_window_init(&w,&src,100,every_fourth,&p); WireListRow out[100];
 size_t n=wire_filter_window_next(&w,100,out);assert(n==100);assert(s.count_calls==1);assert(s.range_calls==4);assert(p.calls==400);assert(w.candidates_seen==400);assert(w.upstream_next==400);assert(out[0].identity==4&&out[99].identity==400);assert(!strcmp(out[36].stable_id,"INBOX|4242|148"));wire_filter_window_release_rows(out,n);
 n=wire_filter_window_next(&w,100,out);assert(n==100);assert(s.count_calls==1);assert(s.range_calls==8);assert(p.calls==800);assert(w.upstream_next==800);assert(out[0].identity==404&&out[99].identity==800);wire_filter_window_release_rows(out,n);
 /* Selectivity can fill mid-pull. Continuation must resume at the first unconsumed backing ordinal. */
 wire_filter_window_reset(&w);p.calls=0;s.range_calls=0;s.count_calls=0;n=wire_filter_window_next(&w,17,out);assert(n==17);assert(s.range_calls==1);assert(p.calls==68);assert(w.upstream_next==68);assert(out[16].identity==68);wire_filter_window_release_rows(out,n);n=wire_filter_window_next(&w,1,out);assert(n==1);assert(s.range_calls==2);assert(out[0].identity==72);assert(w.upstream_next==72);wire_filter_window_release_rows(out,n);
 puts("PASS filtered window: own output window pulls bounded backing windows, preserves continuation and stable identity");return 0;
}
