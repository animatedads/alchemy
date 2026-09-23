#include "../src/pharo_alchemy_adapter.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
typedef struct{int has,sends;}F;
static pa_status_t u(void*p,pa_handle_t h,const char*s,int*a){(void)h;(void)s;*a=((F*)p)->has;return PA_OK;}
static pa_result_t s(void*p,const pa_message_t*m){F*f=p;pa_result_t r;memset(&r,0,sizeof r);f->sends++;r.status=!f->has?PA_NO_SELECTOR:(!strcmp(m->selector_utf8,"explode")?PA_FOREIGN_EXCEPTION:PA_OK);return r;}
static pa_status_t x(void*p,pa_handle_t h){(void)p;(void)h;return PA_OK;}
int main(void){
 F f={0,0};pa_runtime_adapter_t a={&f,u,s,x,x};pa_registry_t*g=pa_registry_create();pa_handle_t h=pa_registry_publish(g,123);
 pa_message_t m;pa_result_t r;int yes=-1;memset(&m,0,sizeof m);m.receiver=h;m.call_id=808;
 assert(pa_adapter_understands(&a,h,"later",&yes)==PA_OK&&yes==0&&f.sends==0);
 f.has=1;assert(pa_adapter_understands(&a,h,"later",&yes)==PA_OK&&yes==1&&f.sends==0);
 m.selector_utf8="later";r=pa_dispatch_pinned(g,&m,pa_adapter_dispatch,&a);assert(r.status==PA_OK&&r.call_id==808);
 m.selector_utf8="explode";r=pa_dispatch_pinned(g,&m,pa_adapter_dispatch,&a);assert(r.status==PA_FOREIGN_EXCEPTION);
 puts("PHARO ALCHEMY runtime adapter seam PASS");pa_registry_destroy(g);return 0;
}
