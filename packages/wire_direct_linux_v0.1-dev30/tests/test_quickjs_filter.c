#include "wire_filter_window.h"
#include "wire_quickjs_predicate.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef struct { uint64_t count; unsigned count_calls,range_calls; uint64_t starts[32]; size_t asks[32]; char ids[256][48]; } Store;
static uint64_t count_rows(void*c){Store*s=c;s->count_calls++;return s->count;}
static size_t range_rows(void*c,uint64_t start,size_t n,WireListRow*out){Store*s=c;unsigned k=s->range_calls++;s->starts[k]=start;s->asks[k]=n;if(start>=s->count)return 0;if(start+n>s->count)n=(size_t)(s->count-start);for(size_t i=0;i<n;i++){uint64_t id=start+i+1;snprintf(s->ids[i],48,"INBOX|4242|%llu",(unsigned long long)id);out[i].identity=id;out[i].stable_id=s->ids[i];out[i].from=(id%8==0)?"boss@example.com":"list@example.net";out[i].subject="synthetic";}return n;}
int main(void){
 Store s={.count=200000}; WireListSource src={&s,count_rows,range_rows};
 WireQuickJSPredicate *js=wire_quickjs_predicate_new("(row)=>row.from==='boss@example.com' && (row.identity % 8)===0"); assert(js&&!wire_quickjs_predicate_failed(js));
 WireFilterWindow w; wire_filter_window_init(&w,&src,100,wire_quickjs_predicate_test,js); WireListRow out[100];
 size_t n=wire_filter_window_next(&w,100,out); assert(n==100); assert(s.count_calls==1); assert(s.range_calls==8); assert(w.candidates_seen==800); assert(w.upstream_next==800); assert(wire_quickjs_predicate_calls(js)==800); assert(out[0].identity==8&&out[99].identity==800); assert(!strcmp(out[36].stable_id,"INBOX|4242|296")); wire_filter_window_release_rows(out,n);
 n=wire_filter_window_next(&w,17,out); assert(n==17); assert(s.range_calls==10); assert(w.upstream_next==936); assert(out[0].identity==808&&out[16].identity==936); wire_filter_window_release_rows(out,n);
 n=wire_filter_window_next(&w,1,out); assert(n==1); assert(s.range_calls==11); assert(w.upstream_next==944); assert(out[0].identity==944); wire_filter_window_release_rows(out,n);
 assert(!wire_quickjs_predicate_failed(js)); wire_quickjs_predicate_free(js);
 puts("PASS real QuickJS predicate: bounded backing pulls -> JS row predicate -> filtered window; 200000 backing rows not materialised"); return 0;
}
