// Architecture: Tom Dyer. Coding: ChatGPT. Trusted Linux audit transport.
#pragma once
#include <linux/audit.h>
#include <linux/netlink.h>
#include <sys/socket.h>
#include <unistd.h>
#include <poll.h>
#include <cerrno>
#include <cstring>
#include <cstdint>
#include <chrono>
#include <vector>
#include <string>
#include <cstddef>
namespace auditwire {
struct Request { nlmsghdr h; audit_status s; };
inline bool build(Request& r, bool set, unsigned flag, unsigned seq, unsigned port) {
    r={}; if(set && flag>1)return false;
    r.h.nlmsg_len=set?NLMSG_LENGTH(sizeof(audit_status)):NLMSG_LENGTH(0);
    r.h.nlmsg_type=set?AUDIT_SET:AUDIT_GET;
    r.h.nlmsg_flags=NLM_F_REQUEST|(set?NLM_F_ACK:0);r.h.nlmsg_seq=seq;r.h.nlmsg_pid=port;
    if(set){r.s.mask=AUDIT_STATUS_ENABLED;r.s.enabled=flag;}return true;
}
inline bool parseStatus(const void* p,size_t n,audit_status& s){
    if(n<offsetof(audit_status,backlog)+sizeof(s.backlog))return false;
    s={};memcpy(&s,p,n<sizeof(s)?n:sizeof(s));return s.enabled<=2;
}
inline int openSocket(bool multicast,unsigned* port=nullptr){
    int fd=socket(AF_NETLINK,SOCK_RAW|SOCK_CLOEXEC|SOCK_NONBLOCK,NETLINK_AUDIT);if(fd<0)return -1;
    sockaddr_nl local={};local.nl_family=AF_NETLINK;
    if(bind(fd,reinterpret_cast<sockaddr*>(&local),sizeof(local))<0){int e=errno;close(fd);errno=e;return -1;}
    socklen_t len=sizeof(local);
    if(getsockname(fd,reinterpret_cast<sockaddr*>(&local),&len)<0){int e=errno;close(fd);errno=e;return -1;}
    if(len!=sizeof(local)||local.nl_family!=AF_NETLINK){close(fd);errno=EPROTO;return -1;}
    if(multicast){int group=AUDIT_NLGRP_READLOG;if(setsockopt(fd,SOL_NETLINK,NETLINK_ADD_MEMBERSHIP,&group,sizeof(group))<0){int e=errno;close(fd);errno=e;return -1;}}
    if(port)*port=local.nl_pid;
    return fd;
}
inline int sendKernel(int fd,const void* bytes,size_t n){sockaddr_nl peer={};peer.nl_family=AF_NETLINK;ssize_t k=sendto(fd,bytes,n,0,reinterpret_cast<sockaddr*>(&peer),sizeof(peer));return k<0?errno:(static_cast<size_t>(k)==n?0:EIO);}
struct Record { unsigned type; std::string text; };
inline int parseRecords(const void* bytes,size_t size,std::vector<Record>& out){
    out.clear();const auto* p=static_cast<const char*>(bytes);
    while(size){nlmsghdr h={};if(size<sizeof(h))return EPROTO;memcpy(&h,p,sizeof(h));if(h.nlmsg_len<NLMSG_HDRLEN||h.nlmsg_len>size)return EPROTO;
        size_t n=h.nlmsg_len-NLMSG_HDRLEN;const char* body=p+NLMSG_HDRLEN;
        if(h.nlmsg_type==NLMSG_OVERRUN)return ENOBUFS;
        if(h.nlmsg_type==NLMSG_ERROR){return EPROTO;}
        if(h.nlmsg_type>=AUDIT_GET){if(out.size()>=256)return EOVERFLOW;while(n&&body[n-1]=='\0')--n;if(memchr(body,0,n))return EPROTO;out.push_back({h.nlmsg_type,std::string(body,n)});}
        size_t step=NLMSG_ALIGN(h.nlmsg_len);if(step>size){if(h.nlmsg_len==size)step=size;else return EPROTO;}p+=step;size-=step;
    }return 0;
}
inline int receive(int fd,char* buf,size_t cap,size_t& n){sockaddr_nl peer={};iovec v={buf,cap};msghdr m={};m.msg_name=&peer;m.msg_namelen=sizeof(peer);m.msg_iov=&v;m.msg_iovlen=1;ssize_t k;do{k=recvmsg(fd,&m,MSG_DONTWAIT);}while(k<0&&errno==EINTR);if(k<0)return errno;if(!k)return EIO;if(m.msg_flags&(MSG_TRUNC|MSG_CTRUNC))return ENOBUFS;if(m.msg_namelen!=sizeof(peer)||peer.nl_family!=AF_NETLINK||peer.nl_pid!=0)return EPROTO;n=k;return 0;}
inline int exchange(bool set,unsigned flag,audit_status& status){
    if(set&&flag>1)return EINVAL;
    unsigned port=0;int fd=openSocket(false,&port);if(fd<0)return errno;
    struct Close{int f;~Close(){close(f);}} closer{fd};Request req;if(!build(req,set,flag,1,port))return EINVAL;
    int e=sendKernel(fd,&req,req.h.nlmsg_len);if(e)return e;
    auto until=std::chrono::steady_clock::now()+std::chrono::seconds(2);
    while(true){auto ms=std::chrono::duration_cast<std::chrono::milliseconds>(until-std::chrono::steady_clock::now()).count();if(ms<=0)return ETIMEDOUT;pollfd f={fd,POLLIN,0};int ready=poll(&f,1,static_cast<int>(ms));if(ready<0){if(errno==EINTR)continue;return errno;}if(!ready)return ETIMEDOUT;
        alignas(nlmsghdr) char buf[8192];size_t n=0;e=receive(fd,buf,sizeof(buf),n);if(e==EAGAIN)continue;if(e)return e;
        const char* p=buf;while(n){nlmsghdr h={};if(n<sizeof(h))return EPROTO;memcpy(&h,p,sizeof(h));if(h.nlmsg_len<NLMSG_HDRLEN||h.nlmsg_len>n)return EPROTO;size_t len=h.nlmsg_len-NLMSG_HDRLEN;const char* b=p+NLMSG_HDRLEN;
            if(h.nlmsg_seq==1){if(h.nlmsg_type==NLMSG_ERROR){nlmsgerr err={};if(len<sizeof(err))return EPROTO;memcpy(&err,b,sizeof(err));if(err.error>0||err.error< -4095)return EPROTO;if(err.error)return -err.error;if(set)return 0;}
                if(!set&&h.nlmsg_type==AUDIT_GET)return parseStatus(b,len,status)?0:EPROTO;}
            size_t step=NLMSG_ALIGN(h.nlmsg_len);if(step>n){if(h.nlmsg_len==n)step=n;else return EPROTO;}p+=step;n-=step;
        }
    }
}
inline int setEnabled(unsigned flag,audit_status& after){if(flag>1)return EINVAL;audit_status before={};int e=exchange(false,0,before);if(e)return e;if(before.enabled==2)return EPERM;if(before.enabled!=flag){e=exchange(true,flag,after);if(e)return e;}e=exchange(false,0,after);if(e)return e;return after.enabled==flag?0:EAGAIN;}
}
