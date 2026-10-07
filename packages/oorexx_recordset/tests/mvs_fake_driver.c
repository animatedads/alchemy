#include "RecordSetMvsDriver.h"
#include <stdlib.h>
#include <string.h>

typedef struct FakeHandle { int index; int mode; } FakeHandle;
static const char *rows[] = { "ALPHA", "", "GAMMA" };
static int writeCount = 0;
static rs_size_t lastWriteLength = 0;

static void err(char *b, rs_size_t c, const char *s) { rs_size_t i=0; if(!b||!c)return; while(i+1<c&&s[i]){b[i]=s[i];i++;} b[i]=0; }
int mvsrs_driver_open(const MvsRecordSetOpenRequest *r,MvsRecordSetDriverHandle *out,MvsRecordSetOpenInfo *i,char *e,rs_size_t c)
{
    FakeHandle *h=(FakeHandle*)calloc(1,sizeof(FakeHandle)); if(!h){err(e,c,"alloc");return MVSRS_DRIVER_ERROR;}
    h->mode=r->mode; *out=h; memset(i,0,sizeof(*i)); strcpy(i->organization,r->resourceKind==MVSRS_RESOURCE_MEMBER?"PO":"PS"); strcpy(i->recordFormat,"FB"); i->logicalRecordLength=80; i->blockSize=3120; i->allocationOwned=r->resourceKind==MVSRS_RESOURCE_DD?0:1; err(e,c,""); return MVSRS_DRIVER_OK;
}
int mvsrs_driver_close(MvsRecordSetDriverHandle h,int releaseAllocation,char *e,rs_size_t c){(void)releaseAllocation;free(h);err(e,c,"");return MVSRS_DRIVER_OK;}
int mvsrs_driver_read(MvsRecordSetDriverHandle v,unsigned char *b,rs_size_t cap,rs_size_t *n,char *e,rs_size_t c)
{ FakeHandle*h=(FakeHandle*)v; rs_size_t len; if(h->index>=3)return MVSRS_DRIVER_EOF; len=(rs_size_t)strlen(rows[h->index]); if(len>cap){err(e,c,"small");return MVSRS_DRIVER_ERROR;} if(len)memcpy(b,rows[h->index],len); *n=len; h->index++; return MVSRS_DRIVER_OK; }
int mvsrs_driver_write(MvsRecordSetDriverHandle v,const unsigned char*b,rs_size_t n,char*e,rs_size_t c){(void)v;(void)b;writeCount++;lastWriteLength=n;err(e,c,"");return MVSRS_DRIVER_OK;}
int mvsrs_driver_rewind(MvsRecordSetDriverHandle v,char*e,rs_size_t c){((FakeHandle*)v)->index=0;err(e,c,"");return MVSRS_DRIVER_OK;}
int mvsrs_driver_record_count(MvsRecordSetDriverHandle v,rs_size_t*n,char*e,rs_size_t c){(void)v;(void)e;(void)c;*n=3;return MVSRS_DRIVER_OK;}
int fake_write_count(void){return writeCount;} rs_size_t fake_last_write_length(void){return lastWriteLength;}
