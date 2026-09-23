/* MailReader visual host. UI structure is loaded from .wire or XML; this host
 * contains application/source setup and semantic dispatch only. No GTK API. */
#include "wire_renderer.h"
#include "wire_ui_loader.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
extern WireRenderer *wire_gtk4_renderer_new(void);
typedef struct { uint64_t count; const char *prefix; char stable[128][48]; char subject[128][96]; } Rows;
typedef struct { WireRenderer *renderer; WireHandle message; } App;
static void loaded(void*ctx,const char*id,WireHandle h,WireElementKind k){(void)k;App*a=ctx;if(id&&!strcmp(id,"message"))a->message=h;}
static uint64_t rows_count(void *ctx){return ((Rows*)ctx)->count;}
static size_t rows_range(void *ctx,uint64_t start,size_t count,WireListRow*out){Rows*d=ctx;if(start>=d->count)return 0;if(count>d->count-start)count=(size_t)(d->count-start);for(size_t i=0;i<count;i++){uint64_t n=start+i;size_t slot=i%128;snprintf(d->stable[slot],sizeof d->stable[slot],"%s:%llu",d->prefix,(unsigned long long)n);snprintf(d->subject[slot],sizeof d->subject[slot],"%s %llu",!strcmp(d->prefix,"folder")?"Mailbox":"Message",(unsigned long long)n);out[i]=(WireListRow){n,d->stable[slot],!strcmp(d->prefix,"folder")?"":"sender@example.invalid",d->subject[slot],"2026-09-20"};}return count;}
static void event(void*ctx,const WireNativeEvent*e){App*a=ctx;fprintf(stderr,"WIRE EVENT source=%s trigger=%s %s=%s\n",e->source_id?e->source_id:"",e->trigger?e->trigger:"",e->detail_key?e->detail_key:"",e->detail_value?e->detail_value:"");if(e->source_id&&e->trigger&&e->detail_value&&!strcmp(e->source_id,"messages")&&!strcmp(e->trigger,"SelectionChanged")){char body[256];snprintf(body,sizeof body,"Selected message\n\nStable Wire identity: %s\n\nThis projection was updated from the semantic SelectionChanged event; no GTK object crossed the boundary.",e->detail_value);WireProperty p={"value",body};(void)a->renderer->v->set_property(a->renderer,a->message,&p);}}
int main(int argc,char**argv){const char*ui=argc>1?argv[1]:"examples/mailreader/mailreader.xml";WireRenderer*r=wire_gtk4_renderer_new();if(!r)return 2;Rows folders={12,"folder",{{0}},{{0}}},messages={200000,"message",{{0}},{{0}}};WireListSource fs={&folders,rows_count,rows_range},ms={&messages,rows_count,rows_range};WireNamedListSource named[]={{"folders",&fs},{"messages",&ms}};App app={r,0};WireUILoadContext lc={r,named,2,loaded,&app};WireHandle root=0;if(r->v->set_dispatch(r,event,&app)!=WIRE_OK||wire_ui_load_file(ui,&lc,&root)!=WIRE_OK){fprintf(stderr,"failed to load Wire UI: %s\n",ui);r->v->destroy(r);return 3;}fprintf(stderr,"WIRE UI loaded: %s root=%llu\n",ui,(unsigned long long)root);WireResult rc=r->v->run(r);r->v->destroy(r);return rc==WIRE_OK?0:4;}
