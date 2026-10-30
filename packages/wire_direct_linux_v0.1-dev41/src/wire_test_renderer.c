#include "wire_renderer.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#define MAX_BINDINGS 32
#define MAX_VISIBLE 512
#define MAX_PROPS 64
#define MAX_ROW_PROPS 256
typedef struct { WireHandle h; char key[32]; char value[4096]; } TestProp;
typedef struct { WireHandle h; char stable_id[96]; char key[32]; char value[256]; } TestRowProp;
typedef struct { WireHandle h; WireListSource source; } ListBinding;
typedef struct { WireDispatch dispatch; void *ctx; unsigned creates; ListBinding lists[MAX_BINDINGS]; size_t list_count; WireListRow visible[MAX_VISIBLE]; size_t visible_count; WireHandle visible_owner; TestProp props[MAX_PROPS]; size_t prop_count; TestRowProp row_props[MAX_ROW_PROPS]; size_t row_prop_count; } TestState;
static void destroy(WireRenderer*r){if(r){free(r->impl);free(r);}}
static WireResult create(WireRenderer*r,WireHandle h,WireElementKind k,WireHandle p){(void)h;(void)k;(void)p;if(!r)return WIRE_EINVAL;((TestState*)r->impl)->creates++;return WIRE_OK;}
static WireResult prop(WireRenderer*r,WireHandle h,const WireProperty*p){if(!r||!p||!p->key)return WIRE_EINVAL;TestState*s=r->impl;for(size_t i=0;i<s->prop_count;i++)if(s->props[i].h==h&&!strcmp(s->props[i].key,p->key)){snprintf(s->props[i].value,sizeof s->props[i].value,"%s",p->value?p->value:"");return WIRE_OK;}if(s->prop_count==MAX_PROPS)return WIRE_ESTATE;TestProp*q=&s->props[s->prop_count++];q->h=h;snprintf(q->key,sizeof q->key,"%s",p->key);snprintf(q->value,sizeof q->value,"%s",p->value?p->value:"");return WIRE_OK;}
static WireResult rem(WireRenderer*r,WireHandle h){(void)h;return r?WIRE_OK:WIRE_EINVAL;}
static WireResult dispatch(WireRenderer*r,WireDispatch f,void*c){if(!r)return WIRE_EINVAL;((TestState*)r->impl)->dispatch=f;((TestState*)r->impl)->ctx=c;return WIRE_OK;}
static ListBinding *find_list(TestState*s,WireHandle h){for(size_t i=0;i<s->list_count;i++)if(s->lists[i].h==h)return &s->lists[i];return NULL;}
static WireResult bind_list(WireRenderer*r,WireHandle h,const WireListSource*src){if(!r||!src||!src->count||!src->range)return WIRE_EINVAL;TestState*s=r->impl;ListBinding*b=find_list(s,h);if(!b){if(s->list_count==MAX_BINDINGS)return WIRE_ESTATE;b=&s->lists[s->list_count++];b->h=h;}b->source=*src;return WIRE_OK;}
static WireResult show_range(WireRenderer*r,WireHandle h,uint64_t start,size_t count){if(!r||count>MAX_VISIBLE)return WIRE_EINVAL;TestState*s=r->impl;ListBinding*b=find_list(s,h);if(!b)return WIRE_ESTATE;uint64_t total=b->source.count(b->source.ctx);s->visible_owner=h;if(start>=total){s->visible_count=0;return WIRE_OK;}if(count>total-start)count=(size_t)(total-start);s->visible_count=b->source.range(b->source.ctx,start,count,s->visible);return WIRE_OK;}
static int visible_has(TestState*s,WireHandle h,const char*stable){if(s->visible_owner!=h)return 0;for(size_t i=0;i<s->visible_count;i++)if(s->visible[i].stable_id&&!strcmp(s->visible[i].stable_id,stable))return 1;return 0;}
static WireResult row_prop(WireRenderer*r,WireHandle h,const WireListRowProperty*p){if(!r||!p||!p->stable_id||!p->key)return WIRE_EINVAL;TestState*s=r->impl;if(!visible_has(s,h,p->stable_id))return WIRE_ESTATE;for(size_t i=0;i<s->row_prop_count;i++){TestRowProp*q=&s->row_props[i];if(q->h==h&&!strcmp(q->stable_id,p->stable_id)&&!strcmp(q->key,p->key)){snprintf(q->value,sizeof q->value,"%s",p->value?p->value:"");return WIRE_OK;}}if(s->row_prop_count==MAX_ROW_PROPS)return WIRE_ESTATE;TestRowProp*q=&s->row_props[s->row_prop_count++];q->h=h;snprintf(q->stable_id,sizeof q->stable_id,"%s",p->stable_id);snprintf(q->key,sizeof q->key,"%s",p->key);snprintf(q->value,sizeof q->value,"%s",p->value?p->value:"");return WIRE_OK;}
static WireResult run(WireRenderer*r){return r?WIRE_OK:WIRE_EINVAL;}
static const WireRendererVTable VT={WIRE_RENDERER_ABI,destroy,create,prop,rem,dispatch,bind_list,show_range,row_prop,run};
WireRenderer *wire_test_renderer_new(void){WireRenderer*r=calloc(1,sizeof(*r));TestState*s=calloc(1,sizeof(*s));if(!r||!s){free(r);free(s);return NULL;}r->v=&VT;r->impl=s;return r;}
unsigned wire_test_renderer_create_count(WireRenderer*r){return r?((TestState*)r->impl)->creates:0;}
WireResult wire_test_renderer_fire(WireRenderer*r,const char*id,const char*trigger){if(!r||!id||!trigger)return WIRE_EINVAL;TestState*s=r->impl;if(!s->dispatch)return WIRE_ESTATE;WireNativeEvent e={id,trigger,NULL,NULL};s->dispatch(s->ctx,&e);return WIRE_OK;}
WireResult wire_test_renderer_select_visible(WireRenderer*r,WireHandle h,size_t i){if(!r)return WIRE_EINVAL;TestState*s=r->impl;if(!s->dispatch||s->visible_owner!=h||i>=s->visible_count)return WIRE_ESTATE;char source[32],fallback[32];snprintf(source,sizeof source,"%llu",(unsigned long long)h);const char *stable=s->visible[i].stable_id;if(!stable){snprintf(fallback,sizeof fallback,"%llu",(unsigned long long)s->visible[i].identity);stable=fallback;}WireNativeEvent e={source,"SelectionChanged","identity",stable};s->dispatch(s->ctx,&e);return WIRE_OK;}
size_t wire_test_renderer_visible_count(WireRenderer*r){return r?((TestState*)r->impl)->visible_count:0;}
uint64_t wire_test_renderer_visible_identity(WireRenderer*r,size_t i){TestState*s=r?r->impl:NULL;return s&&i<s->visible_count?s->visible[i].identity:0;}
const char *wire_test_renderer_visible_stable_id(WireRenderer*r,size_t i){TestState*s=r?r->impl:NULL;return s&&i<s->visible_count?s->visible[i].stable_id:NULL;}

const char *wire_test_renderer_property(WireRenderer*r,WireHandle h,const char*key){TestState*s=r?r->impl:NULL;if(!s||!key)return NULL;for(size_t i=0;i<s->prop_count;i++)if(s->props[i].h==h&&!strcmp(s->props[i].key,key))return s->props[i].value;return NULL;}

const char *wire_test_renderer_row_property(WireRenderer*r,WireHandle h,const char*stable_id,const char*key){TestState*s=r?r->impl:NULL;if(!s||!stable_id||!key)return NULL;for(size_t i=0;i<s->row_prop_count;i++){TestRowProp*q=&s->row_props[i];if(q->h==h&&!strcmp(q->stable_id,stable_id)&&!strcmp(q->key,key))return q->value;}return NULL;}
