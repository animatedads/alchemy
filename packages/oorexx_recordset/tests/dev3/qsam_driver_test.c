#include "RecordSetMvsDriver.h"
#include <stdio.h>
#include <string.h>
extern int qfake_open_count(void);
extern int qfake_close_count(void);
extern int qfake_write_count(void);
extern rs_size_t qfake_last_write_length(void);
static int fail(const char *s){fprintf(stderr,"FAIL: %s\n",s);return 1;}
int main(void)
{
    MvsRecordSetOpenRequest r;
    MvsRecordSetOpenInfo i;
    MvsRecordSetDriverHandle h=0;
    unsigned char b[100];
    rs_size_t n=0,c=99;
    char e[160];
    int rc;
    memset(&r,0,sizeof(r)); memset(&i,0,sizeof(i));
    r.resourceKind=MVSRS_RESOURCE_DD; r.mode=RS_MODE_READ; r.ddName="INPUT";
    rc=mvsrs_driver_open(&r,&h,&i,e,sizeof(e));
    if(rc!=MVSRS_DRIVER_OK)return fail(e);
    if(strcmp(i.organization,"PS")||strcmp(i.recordFormat,"FB")||i.logicalRecordLength!=80||i.blockSize!=3120||i.allocationOwned!=0)return fail("metadata");
    rc=mvsrs_driver_read(h,b,sizeof(b),&n,e,sizeof(e)); if(rc!=MVSRS_DRIVER_OK||n!=3||memcmp(b,"ONE",3))return fail("read one");
    if(mvsrs_driver_rewind(h,e,sizeof(e))!=MVSRS_DRIVER_OK)return fail("rewind");
    rc=mvsrs_driver_read(h,b,sizeof(b),&n,e,sizeof(e)); if(rc!=MVSRS_DRIVER_OK||n!=3||memcmp(b,"ONE",3))return fail("read after rewind");
    if(mvsrs_driver_record_count(h,&c,e,sizeof(e))!=MVSRS_DRIVER_UNKNOWN||c!=0)return fail("count should be unknown");
    if(mvsrs_driver_close(h,0,e,sizeof(e))!=MVSRS_DRIVER_OK)return fail("close");
    if(qfake_open_count()!=1||qfake_close_count()!=1)return fail("open/close counts");
    h=0; memset(&r,0,sizeof(r)); memset(&i,0,sizeof(i)); r.resourceKind=MVSRS_RESOURCE_DD;r.mode=RS_MODE_READ;r.ddName="VARIN";
    if(mvsrs_driver_open(&r,&h,&i,e,sizeof(e))!=MVSRS_DRIVER_OK)return fail(e);
    if(strcmp(i.recordFormat,"VB")!=0)return fail("DCBRECFM VB decode");
    mvsrs_driver_close(h,0,e,sizeof(e));
    h=0; memset(&r,0,sizeof(r)); memset(&i,0,sizeof(i)); r.resourceKind=MVSRS_RESOURCE_DD;r.mode=RS_MODE_WRITE;r.ddName="INPUT";
    if(mvsrs_driver_open(&r,&h,&i,e,sizeof(e))!=MVSRS_DRIVER_OK)return fail(e);
    if(mvsrs_driver_write(h,(const unsigned char*)"XYZ",3,e,sizeof(e))!=MVSRS_DRIVER_OK)return fail(e);
    if(qfake_write_count()!=1||qfake_last_write_length()!=3)return fail("write bridge");
    mvsrs_driver_close(h,0,e,sizeof(e));
    memset(&r,0,sizeof(r)); r.resourceKind=MVSRS_RESOURCE_DATASET;r.mode=RS_MODE_READ;r.dataSetName="USER.DATA";
    if(mvsrs_driver_open(&r,&h,&i,e,sizeof(e))!=MVSRS_DRIVER_UNSUPPORTED)return fail("dataset open should remain separate in dev3");
    puts("qsam-driver-contract: PASS");
    return 0;
}
