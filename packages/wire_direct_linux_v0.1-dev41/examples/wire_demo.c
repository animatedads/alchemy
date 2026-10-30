#include "wire_renderer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern WireRenderer *wire_gtk4_renderer_new(void);

typedef struct { uint64_t count; char stable[128][32]; char subject[128][80]; } DemoRows;
static uint64_t demo_count(void *ctx){ return ((DemoRows*)ctx)->count; }
static size_t demo_range(void *ctx,uint64_t start,size_t count,WireListRow*out){
    DemoRows*d=ctx; if(start>=d->count)return 0; if(count>d->count-start)count=(size_t)(d->count-start);
    for(size_t i=0;i<count;i++){
        uint64_t n=start+i; size_t slot=i%128;
        snprintf(d->stable[slot],sizeof d->stable[slot],"message:%llu",(unsigned long long)n);
        snprintf(d->subject[slot],sizeof d->subject[slot],"Wire message %llu",(unsigned long long)n);
        out[i]=(WireListRow){n,d->stable[slot],"wire@example.invalid",d->subject[slot],"2026-09-20"};
    }
    return count;
}
static void on_event(void*ctx,const WireNativeEvent*e){(void)ctx;fprintf(stderr,"WIRE EVENT source=%s trigger=%s %s=%s\n",e->source_id?e->source_id:"",e->trigger?e->trigger:"",e->detail_key?e->detail_key:"",e->detail_value?e->detail_value:"");}
static void must(WireResult r,const char*what){if(r!=WIRE_OK){fprintf(stderr,"%s failed: %d\n",what,(int)r);exit(2);}}
int main(void){
    WireRenderer*r=wire_gtk4_renderer_new(); if(!r){fputs("GTK renderer creation failed\n",stderr);return 2;}
    DemoRows rows={200000,{{0}},{{0}}}; WireListSource source={&rows,demo_count,demo_range};
    must(r->v->set_dispatch(r,on_event,NULL),"dispatch");
    must(r->v->create(r,1,WIRE_WINDOW,0),"window");
    WireProperty title={"title","Wire Direct Linux — GTK4 demo"}; must(r->v->set_property(r,1,&title),"title");
    must(r->v->create(r,2,WIRE_SCROLL,1),"scroll");
    must(r->v->create(r,3,WIRE_VIRTUAL_LIST,2),"list");
    must(r->v->bind_list(r,3,&source),"bind list");
    must(r->v->show_list_range(r,3,0,100),"show range");
    WireResult result=r->v->run(r); r->v->destroy(r); return result==WIRE_OK?0:3;
}
