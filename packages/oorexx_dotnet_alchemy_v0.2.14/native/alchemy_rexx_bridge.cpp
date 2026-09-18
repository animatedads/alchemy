#include <oorexxapi.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
struct ar_host { RexxInstance *instance; RexxThreadContext *ctx; };
static char *dupstr(const char *s){ if(!s) return NULL; size_t n=strlen(s)+1; char *p=(char*)malloc(n); if(p) memcpy(p,s,n); return p; }
extern "C" {
const char *ar_contract_version(){ return "alchemy.object.bridge/0.1"; }
ar_host *ar_host_create(){ auto *h=new ar_host{}; if(!RexxCreateInterpreter(&h->instance,&h->ctx,NULL)){ delete h; return NULL; } return h; }
void ar_host_destroy(ar_host *h){ if(!h)return; if(h->instance)h->instance->Terminate(); delete h; }
void ar_free(void *p){free(p);} uintptr_t ar_call_program(ar_host *h,const char *name,const char *arg){if(!h||!name)return 0; RexxArrayObject args = arg ? h->ctx->ArrayOfOne(h->ctx->String(arg)) : NULL; RexxObjectPtr o=h->ctx->CallProgram(name,args);if(!o){if(h->ctx->CheckCondition())h->ctx->DisplayCondition();return 0;}return(uintptr_t)h->ctx->RequestGlobalReference(o);}
uintptr_t ar_retain(ar_host*h,uintptr_t o){return h&&o?(uintptr_t)h->ctx->RequestGlobalReference((RexxObjectPtr)o):0;} void ar_release(ar_host*h,uintptr_t o){if(h&&o)h->ctx->ReleaseGlobalReference((RexxObjectPtr)o);}
uintptr_t ar_send_slots(ar_host*h,uintptr_t o,const char*m,size_t argc,const char**tags,const char**texts,uint64_t*handles){if(!h||!o||!m)return 0;RexxArrayObject a=h->ctx->NewArray(argc);for(size_t i=0;i<argc;i++){const char*t=tags[i]?tags[i]:"O";RexxObjectPtr v=NULLOBJECT;if(t[0]=='O')continue;else if(t[0]=='N')v=h->ctx->Nil();else if(t[0]=='S')v=h->ctx->String(texts[i]?texts[i]:"");else if(t[0]=='I')v=h->ctx->Int64ToObject(strtoll(texts[i]?texts[i]:"0",NULL,10));else if(t[0]=='D')v=h->ctx->DoubleToObject(strtod(texts[i]?texts[i]:"0",NULL));else if(t[0]=='H'){auto c=h->ctx->FindClass("ALCHEMYDOTNETOBJECT");v=c?h->ctx->SendMessage1(c,"NEW",h->ctx->UnsignedInt64ToObject(handles[i])):NULLOBJECT;}else if(t[0]=='R'){v=(RexxObjectPtr)(uintptr_t)handles[i];}if(v!=NULLOBJECT)h->ctx->ArrayPut(a,v,i+1);}RexxObjectPtr r=h->ctx->SendMessage((RexxObjectPtr)o,m,a);if(!r||h->ctx->CheckCondition()){if(h->ctx->CheckCondition())h->ctx->DisplayCondition();return 0;}return(uintptr_t)h->ctx->RequestGlobalReference(r);}
uintptr_t ar_send0(ar_host*h,uintptr_t o,const char*m){if(!h||!o||!m)return 0;RexxObjectPtr r=h->ctx->SendMessage0((RexxObjectPtr)o,m);if(!r||h->ctx->CheckCondition()){if(h->ctx->CheckCondition())h->ctx->DisplayCondition();return 0;}return(uintptr_t)h->ctx->RequestGlobalReference(r);}
uintptr_t ar_send_string(ar_host*h,uintptr_t o,const char*m,const char*a){if(!h||!o||!m)return 0;RexxObjectPtr r=h->ctx->SendMessage1((RexxObjectPtr)o,m,h->ctx->String(a?a:""));if(!r||h->ctx->CheckCondition()){if(h->ctx->CheckCondition())h->ctx->DisplayCondition();return 0;}return(uintptr_t)h->ctx->RequestGlobalReference(r);}
char*ar_string(ar_host*h,uintptr_t o){return(!h||!o)?NULL:dupstr(h->ctx->ObjectToStringValue((RexxObjectPtr)o));} int ar_has_condition(ar_host*h){return h&&h->ctx->CheckCondition();}
}
