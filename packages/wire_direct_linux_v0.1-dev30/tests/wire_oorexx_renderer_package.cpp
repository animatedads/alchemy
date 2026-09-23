#include <oorexxapi.h>
#include <cstdint>
#include <string>
#include <vector>
extern "C" {
#include "wire_test_renderer.h"
}
typedef struct { std::vector<WireListRow> rows; } RS;
static uint64_t cnt(void*p){return ((RS*)p)->rows.size();}
static size_t rng(void*p,uint64_t start,size_t n,WireListRow*out){auto&s=((RS*)p)->rows;if(start>=s.size())return 0;if(n>s.size()-start)n=s.size()-start;for(size_t i=0;i<n;i++)out[i]=s[start+i];return n;}
RexxMethod1(RexxObjectPtr,wire_render,RexxArrayObject,input){
    size_t n=context->ArrayItems(input); std::vector<std::string> ids,froms,subjects,dates; ids.reserve(n);froms.reserve(n);subjects.reserve(n);dates.reserve(n); RS rs;rs.rows.reserve(n);
    for(size_t i=1;i<=n;i++){
        auto d=(RexxDirectoryObject)context->ArrayAt(input,i); uint64_t id=0; context->ObjectToUnsignedInt64(context->DirectoryAt(d,"IDENTITY"),&id);
        ids.emplace_back(context->CString(context->DirectoryAt(d,"STABLEID"))); froms.emplace_back(context->CString(context->DirectoryAt(d,"FROM"))); subjects.emplace_back(context->CString(context->DirectoryAt(d,"SUBJECT"))); dates.emplace_back("2026-09-20");
        rs.rows.push_back({id,ids.back().c_str(),froms.back().c_str(),subjects.back().c_str(),dates.back().c_str()});
    }
    WireListSource src{&rs,cnt,rng}; WireRenderer*r=wire_test_renderer_new(); r->v->create(r,1,WIRE_VIRTUAL_LIST,0); r->v->bind_list(r,1,&src); r->v->show_list_range(r,1,0,n);
    RexxDirectoryObject out=context->NewDirectory(); context->DirectoryPut(out,context->UnsignedInt64ToObject(wire_test_renderer_visible_count(r)),"VISIBLE");
    context->DirectoryPut(out,context->UnsignedInt64ToObject(n?wire_test_renderer_visible_identity(r,0):0),"FIRSTIDENTITY"); context->DirectoryPut(out,context->UnsignedInt64ToObject(n?wire_test_renderer_visible_identity(r,n-1):0),"LASTIDENTITY"); r->v->destroy(r); return out;
}
static RexxMethodEntry methods[]={REXX_METHOD(wire_render,wire_render),REXX_LAST_METHOD()};
RexxPackageEntry wire_oorexx_renderer_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,"wire_oorexx_renderer_package","0.1-dev20",NULL,NULL,NULL,methods};
OOREXX_GET_PACKAGE(wire_oorexx_renderer);
