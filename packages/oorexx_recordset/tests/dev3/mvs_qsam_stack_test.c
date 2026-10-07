#include "RecordSetNative.h"
#include <stdio.h>
#include <string.h>
extern int qfake_last_write_tail(void);
static int fail(const char *s){fprintf(stderr,"FAIL: %s\n",s);return 1;}
static int textmeta(RecordSetHandle*h,int key,const char*want){char b[64];rs_size_t n=0;if(rs_text_metadata(h,key,b,sizeof(b),&n)!=RS_STATUS_OK||strcmp(b,want)!=0)return fail("metadata mismatch");return 0;}
int main(void)
{
    RecordSetHandle *h=0; unsigned char *p=0; rs_size_t n=0,c=0; char e[160];
    if(rs_open("DD:input",RS_MODE_READ,&h,e,sizeof(e))!=RS_STATUS_OK)return fail(e);
    if(textmeta(h,RS_META_DD_NAME,"INPUT")||textmeta(h,RS_META_RECORD_FORMAT,"FB"))return 1;
    if(rs_read_record(h,&p,&n,e,sizeof(e))!=RS_STATUS_OK||n!=3||memcmp(p,"ONE",3))return fail("fixed read");
    rs_free_record(p);
    if(rs_position_record(h,1,e,sizeof(e))!=RS_STATUS_OK)return fail(e);
    if(rs_record_count(h,&c,e,sizeof(e))!=RS_STATUS_UNKNOWN)return fail("sequential count must be unknown");
    rs_close(h);
    h=0;
    if(rs_open("DD:input",RS_MODE_WRITE,&h,e,sizeof(e))!=RS_STATUS_OK)return fail(e);
    if(rs_write_record(h,(const unsigned char*)"ABC",3,e,sizeof(e))!=RS_STATUS_OK)return fail(e); /* semantic layer pads FB to 80 */
    if(qfake_last_write_tail()!=0x40)return fail("MVS fixed record was not padded with EBCDIC blank X40");
    rs_close(h);
    h=0;
    if(rs_open("DD:varin",RS_MODE_WRITE,&h,e,sizeof(e))!=RS_STATUS_OK)return fail(e);
    if(textmeta(h,RS_META_RECORD_FORMAT,"VB"))return 1;
    { unsigned char v[77]; memset(v,'V',sizeof(v));
      if(rs_write_record(h,v,76,e,sizeof(e))!=RS_STATUS_OK)return fail("VB max payload should be LRECL-4");
      if(rs_write_record(h,v,77,e,sizeof(e))==RS_STATUS_OK)return fail("VB payload greater than LRECL-4 accepted"); }
    rs_close(h);
    h=0;
    if(rs_open("'USER.DATA'",RS_MODE_READ,&h,e,sizeof(e))==RS_STATUS_OK)return fail("dataset allocation leaked into DD-only dev3 driver");
    puts("mvs-qsam-stack: PASS");
    return 0;
}
