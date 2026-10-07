#include "RecordSetNative.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <fstream>

static void put(const char *p,const char *s){std::ofstream f(p,std::ios::binary|std::ios::trunc);f<<s;}
int main()
{
    const char *in="/tmp/recordset-native-in.txt",*out="/tmp/recordset-native-out.txt";
    char err[256]; RecordSetHandle *h=0; rs_size_t n=0; unsigned char *data=0; rs_size_t len=0;
    put(in,"alpha\r\nbeta\n\ngamma");
    assert(rs_open(in,RS_MODE_READ,&h,err,sizeof(err))==RS_STATUS_OK);
    assert(rs_record_count(h,&n,err,sizeof(err))==RS_STATUS_OK && n==4);
    assert(rs_read_record(h,&data,&len,err,sizeof(err))==RS_STATUS_OK && len==5 && memcmp(data,"alpha",5)==0); rs_free_record(data);
    assert(rs_read_record(h,&data,&len,err,sizeof(err))==RS_STATUS_OK && len==4 && memcmp(data,"beta",4)==0); rs_free_record(data);
    assert(rs_read_record(h,&data,&len,err,sizeof(err))==RS_STATUS_OK && len==0); rs_free_record(data);
    assert(rs_position_record(h,5,err,sizeof(err))==RS_STATUS_OK && rs_eof(h));
    assert(rs_read_record(h,&data,&len,err,sizeof(err))==RS_STATUS_EOF);
    assert(!rs_is_native_recordset(h)); rs_close(h);

    assert(rs_open(out,RS_MODE_WRITE,&h,err,sizeof(err))==RS_STATUS_OK);
    assert(rs_write_record(h,(const unsigned char *)"one",3,err,sizeof(err))==RS_STATUS_OK);
    assert(rs_write_record(h,(const unsigned char *)"",0,err,sizeof(err))==RS_STATUS_OK);
    assert(rs_write_record(h,(const unsigned char *)"three",5,err,sizeof(err))==RS_STATUS_OK); rs_close(h);
    assert(rs_open(out,RS_MODE_APPEND,&h,err,sizeof(err))==RS_STATUS_OK);
    assert(rs_write_record(h,(const unsigned char *)"four",4,err,sizeof(err))==RS_STATUS_OK); rs_close(h);
    assert(rs_open(out,RS_MODE_READ,&h,err,sizeof(err))==RS_STATUS_OK);
    assert(rs_record_count(h,&n,err,sizeof(err))==RS_STATUS_OK && n==4); rs_close(h);
    remove(in);remove(out);puts("RecordSet native portable ABI: PASS");return 0;
}
