#include "wire_renderer.h"
#include "wire_test_renderer.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef struct { unsigned calls; char id[32]; char trigger[32]; char key[32]; char value[96]; } Seen;
static void on_event(void*c,const WireNativeEvent*e){Seen*s=c;s->calls++;snprintf(s->id,sizeof s->id,"%s",e->source_id?e->source_id:"");snprintf(s->trigger,sizeof s->trigger,"%s",e->trigger?e->trigger:"");snprintf(s->key,sizeof s->key,"%s",e->detail_key?e->detail_key:"");snprintf(s->value,sizeof s->value,"%s",e->detail_value?e->detail_value:"");}
typedef struct { uint64_t count; unsigned count_calls; unsigned range_calls; uint64_t last_start; size_t last_count; char ids[512][48]; } Big;
static uint64_t cnt(void*c){Big*b=c;b->count_calls++;return b->count;}
static size_t range(void*c,uint64_t start,size_t n,WireListRow*out){Big*b=c;b->range_calls++;b->last_start=start;b->last_count=n;for(size_t i=0;i<n;i++){uint64_t id=start+i+1;snprintf(b->ids[i],sizeof b->ids[i],"INBOX|4242|%llu",(unsigned long long)id);out[i].identity=id;out[i].stable_id=b->ids[i];out[i].subject="synthetic";}return n;}
int main(void){
 WireRenderer*r=wire_test_renderer_new();assert(r&&r->v->abi==WIRE_RENDERER_ABI);Seen s={0};assert(r->v->set_dispatch(r,on_event,&s)==WIRE_OK);
 assert(r->v->create(r,1,WIRE_WINDOW,0)==WIRE_OK);assert(r->v->create(r,2,WIRE_VIRTUAL_LIST,1)==WIRE_OK);assert(r->v->create(r,3,WIRE_DOCUMENT,1)==WIRE_OK);assert(wire_test_renderer_create_count(r)==3);
 Big b={200000,0,0,0,0,{{0}}};WireListSource src={&b,cnt,range};assert(r->v->bind_list(r,2,&src)==WIRE_OK);
 assert(r->v->show_list_range(r,2,8700,100)==WIRE_OK);assert(b.count_calls==1&&b.range_calls==1&&b.last_count==100);assert(wire_test_renderer_visible_count(r)==100);assert(!strcmp(wire_test_renderer_visible_stable_id(r,0),"INBOX|4242|8701"));
 WireListRowProperty ap={"INBOX|4242|8738","assessment","Important"};assert(r->v->set_list_row_property(r,2,&ap)==WIRE_OK);assert(!strcmp(wire_test_renderer_row_property(r,2,"INBOX|4242|8738","assessment"),"Important"));assert(b.range_calls==1);WireListRowProperty absent={"INBOX|4242|999999","assessment","Nope"};assert(r->v->set_list_row_property(r,2,&absent)==WIRE_ESTATE);assert(b.range_calls==1);
 assert(wire_test_renderer_select_visible(r,2,37)==WIRE_OK);assert(s.calls==1&&!strcmp(s.id,"2")&&!strcmp(s.trigger,"SelectionChanged")&&!strcmp(s.key,"identity")&&!strcmp(s.value,"INBOX|4242|8738")); WireProperty body={"value","Selected message body"};assert(r->v->set_property(r,3,&body)==WIRE_OK);assert(!strcmp(wire_test_renderer_property(r,3,"value"),"Selected message body"));
 assert(r->v->show_list_range(r,2,199990,100)==WIRE_OK);assert(b.range_calls==2&&b.last_count==10);assert(wire_test_renderer_visible_count(r)==10);assert(wire_test_renderer_visible_identity(r,9)==200000);
 r->v->destroy(r);puts("PASS wire direct core: ABI4 + visible-row semantic update + stable-identity selection + Document update + renderer-driven 200000-row VirtualList");return 0;
}
