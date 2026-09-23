#include "wire_quickjs_predicate.h"
#include <quickjs.h>
#include <stdlib.h>
#include <string.h>
struct WireQuickJSPredicate { JSRuntime *rt; JSContext *ctx; JSValue fn; int failed; unsigned long long calls; };
static void set_s(JSContext*c,JSValue o,const char*k,const char*v){JS_SetPropertyStr(c,o,k,v?JS_NewString(c,v):JS_NULL);}
WireQuickJSPredicate *wire_quickjs_predicate_new(const char *source){
 if(!source)return NULL;
 WireQuickJSPredicate*p=calloc(1,sizeof *p);
 if(!p)return NULL;
 p->rt=JS_NewRuntime(); if(!p->rt){free(p);return NULL;} p->ctx=JS_NewContext(p->rt); if(!p->ctx){JS_FreeRuntime(p->rt);free(p);return NULL;}
 p->fn=JS_Eval(p->ctx,source,strlen(source),"wire-filter.js",JS_EVAL_TYPE_GLOBAL);
 if(JS_IsException(p->fn)){p->failed=1;return p;} return p;
}
int wire_quickjs_predicate_test(void *ctx,const WireListRow *row){
 WireQuickJSPredicate*p=ctx; if(!p||p->failed||!row)return 0; p->calls++;
 JSValue o=JS_NewObject(p->ctx); JS_SetPropertyStr(p->ctx,o,"identity",JS_NewInt64(p->ctx,(int64_t)row->identity));
 set_s(p->ctx,o,"stableId",row->stable_id); set_s(p->ctx,o,"from",row->from); set_s(p->ctx,o,"subject",row->subject); set_s(p->ctx,o,"date",row->date);
 JSValue argv[1]={o}; JSValue r=JS_Call(p->ctx,p->fn,JS_UNDEFINED,1,argv); JS_FreeValue(p->ctx,o);
 if(JS_IsException(r)){p->failed=1;JS_FreeValue(p->ctx,r);return 0;} int b=JS_ToBool(p->ctx,r); JS_FreeValue(p->ctx,r); if(b<0){p->failed=1;return 0;} return b;
}
int wire_quickjs_predicate_failed(const WireQuickJSPredicate*p){return p?p->failed:1;}
unsigned long long wire_quickjs_predicate_calls(const WireQuickJSPredicate*p){return p?p->calls:0;}
void wire_quickjs_predicate_free(WireQuickJSPredicate*p){if(!p)return;if(p->ctx){JS_FreeValue(p->ctx,p->fn);JS_FreeContext(p->ctx);}if(p->rt)JS_FreeRuntime(p->rt);free(p);}
