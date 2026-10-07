#include "RecordSetNative.h"
#include <stdio.h>
#include <string.h>
extern int fake_write_count(void); extern rs_size_t fake_last_write_length(void);
static int fail(const char*s){fprintf(stderr,"FAIL: %s\n",s);return 1;}
static int meta(RecordSetHandle*h,int k,const char*want){char b[160];rs_size_t n=0;if(rs_text_metadata(h,k,b,sizeof(b),&n)!=RS_STATUS_OK||strcmp(b,want)!=0){fprintf(stderr,"META got [%s] want [%s]\n",b,want);return 1;}return 0;}
int main(void)
{
 RecordSetHandle*h=0;char e[256];unsigned char*d=0;rs_size_t n=0,v=0;int rc;
 rc=rs_open("DD:input",RS_MODE_READ,&h,e,sizeof(e)); if(rc!=RS_STATUS_OK)return fail(e); if(meta(h,RS_META_DD_NAME,"INPUT"))return 1; if(meta(h,RS_META_ORGANIZATION,"PS"))return 1; if(meta(h,RS_META_RECORD_FORMAT,"FB"))return 1; if(rs_number_metadata(h,RS_META_LRECL,&v)!=RS_STATUS_OK||v!=80)return fail("LRECL");
 rc=rs_read_record(h,&d,&n,e,sizeof(e)); if(rc!=RS_STATUS_OK||n!=5||memcmp(d,"ALPHA",5))return fail("read 1"); rs_free_record(d);
 rc=rs_read_record(h,&d,&n,e,sizeof(e)); if(rc!=RS_STATUS_OK||n!=0)return fail("zero record"); rs_free_record(d);
 if(rs_position_record(h,1,e,sizeof(e))!=RS_STATUS_OK||rs_record_number(h)!=1)return fail("rewind position");
 if(rs_record_count(h,&v,e,sizeof(e))!=RS_STATUS_OK||v!=3)return fail("count");
 rs_close(h);
 h=0; if(rs_open("'user.rexx.exec(member)'",RS_MODE_READ,&h,e,sizeof(e))!=RS_STATUS_OK)return fail(e); if(meta(h,RS_META_DATASET_NAME,"USER.REXX.EXEC"))return 1; if(meta(h,RS_META_MEMBER_NAME,"MEMBER"))return 1; if(meta(h,RS_META_ORGANIZATION,"PO"))return 1; rs_close(h);
 h=0; if(rs_open("'USER.DATA'",RS_MODE_WRITE,&h,e,sizeof(e))!=RS_STATUS_OK)return fail(e); if(rs_write_record(h,(const unsigned char*)"ABC",3,e,sizeof(e))!=RS_STATUS_OK)return fail(e); if(fake_write_count()!=1||fake_last_write_length()!=80)return fail("FB pad to LRECL"); rs_close(h);
 h=0; if(rs_open("DD:TOOLONG99",RS_MODE_READ,&h,e,sizeof(e))==RS_STATUS_OK)return fail("bad DD accepted");
 puts("mvs-backend-contract: PASS"); return 0;
}
