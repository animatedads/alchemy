// Architecture: Tom Dyer. Coding: ChatGPT. Pure wire tests; no host mutation.
#include "../native/audit_netlink.h"
#include <iostream>
#include <cstdlib>
using namespace auditwire;
static void check(bool ok,const char* name){if(!ok){std::cerr<<"FAIL "<<name<<'\n';std::exit(1);}std::cout<<"PASS "<<name<<'\n';}
int main(){
    Request r;check(build(r,false,0,9,123)&&r.h.nlmsg_type==AUDIT_GET&&r.h.nlmsg_len==NLMSG_LENGTH(0)&&r.h.nlmsg_seq==9&&r.h.nlmsg_pid==123&&r.h.nlmsg_flags==NLM_F_REQUEST,"audit GET exact header, no payload");
    check(build(r,true,1,9,123)&&r.h.nlmsg_type==AUDIT_SET&&r.h.nlmsg_flags==(NLM_F_REQUEST|NLM_F_ACK)&&r.h.nlmsg_len==NLMSG_LENGTH(sizeof(audit_status)),"audit SET acknowledged request");
    check(r.s.mask==AUDIT_STATUS_ENABLED&&r.s.enabled==1&&r.s.pid==0&&r.s.failure==0&&r.s.rate_limit==0&&r.s.backlog_limit==0,"audit SET only ENABLED mask, no daemon registration");
    check(build(r,true,0,1,2)&&r.s.mask==AUDIT_STATUS_ENABLED&&r.s.enabled==0&&r.s.pid==0,"audit SET off exact mask");
    check(!build(r,true,2,1,2)&&!build(r,true,3,1,2),"audit SET lock and invalid refused before send");
    audit_status s={};check(setEnabled(2,s)==EINVAL,"audit native flag 2 refused without transport");
    audit_status original={};original.enabled=2;original.failure=1;original.pid=99;original.backlog_limit=100;original.lost=3;original.backlog=5;
    check(parseStatus(&original,sizeof(original),s)&&s.enabled==2&&s.failure==1&&s.pid==99&&s.backlog_limit==100&&s.lost==3&&s.backlog==5,"audit status preserves lock and counters");
    check(parseStatus(&original,32,s)&&!parseStatus(&original,31,s),"audit status legacy size supported, truncation refused");
    original.enabled=3;check(!parseStatus(&original,sizeof(original),s),"audit invalid enabled status refused");
    std::vector<Record> out;char buf[128]={};nlmsghdr h={};h.nlmsg_type=1105;h.nlmsg_len=NLMSG_LENGTH(4);memcpy(buf,&h,sizeof(h));memcpy(buf+NLMSG_HDRLEN,"abc",4);
    check(parseRecords(buf,h.nlmsg_len,out)==0&&out.size()==1&&out[0].type==1105&&out[0].text=="abc","audit netlink type and bounded record framing");
    size_t offset=NLMSG_ALIGN(h.nlmsg_len);h.nlmsg_type=1106;memcpy(buf+offset,&h,sizeof(h));memcpy(buf+offset+NLMSG_HDRLEN,"def",4);
    check(parseRecords(buf,offset+h.nlmsg_len,out)==0&&out.size()==2&&out[1].type==1106&&out[1].text=="def","audit multiple records in one datagram");
    check(parseRecords(buf,offset+h.nlmsg_len-1,out)==EPROTO,"audit truncated datagram refused");
    h.nlmsg_type=NLMSG_OVERRUN;memcpy(buf,&h,sizeof(h));check(parseRecords(buf,h.nlmsg_len,out)==ENOBUFS,"audit overrun signalled");
    h.nlmsg_type=1105;memcpy(buf,&h,sizeof(h));memcpy(buf+NLMSG_HDRLEN,"a\0b",4);check(parseRecords(buf,h.nlmsg_len,out)==EPROTO,"audit embedded NUL rejected");
}
