#include "xtp/xtp_transport.hpp"
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <array>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <vector>

namespace {
constexpr uint8_t XTP_VERSION=3, TYPE_DATA=0x00, TYPE_CNTL=0x01, TYPE_FIRST=0x02;
constexpr uint8_t TRAIL_SREQ=0x80, TRAIL_RCLOSE=0x20, TRAIL_WCLOSE=0x10, TRAIL_EOM=0x02;
constexpr size_t HEADER=24, TRAILER=16, CONTROL=40;
uint16_t rol16(uint16_t v){return uint16_t((v<<1)|(v>>15));}
struct Checksum{uint16_t x=0,rx=0;};
Checksum checksum(const uint8_t*p,size_t n){Checksum c{};for(size_t i=0;i<n;i+=2){uint16_t w=uint16_t(p[i])<<8;if(i+1<n)w|=p[i+1];c.x^=w;c.rx=rol16(c.rx);c.rx^=w;}return c;}
uint32_t checksum32(const uint8_t*p,size_t n){auto c=checksum(p,n);return(uint32_t(c.x)<<16)|c.rx;}
void put32(std::vector<uint8_t>&b,size_t o,uint32_t v,bool l){if(l){b[o]=uint8_t(v);b[o+1]=uint8_t(v>>8);b[o+2]=uint8_t(v>>16);b[o+3]=uint8_t(v>>24);}else{b[o]=uint8_t(v>>24);b[o+1]=uint8_t(v>>16);b[o+2]=uint8_t(v>>8);b[o+3]=uint8_t(v);}}
void put16(std::vector<uint8_t>&b,size_t o,uint16_t v,bool l){if(l){b[o]=uint8_t(v);b[o+1]=uint8_t(v>>8);}else{b[o]=uint8_t(v>>8);b[o+1]=uint8_t(v);}}
uint8_t cmd0(uint8_t type,bool l){return uint8_t((l?0x80:0)|((XTP_VERSION&3)<<5)|(type&0x1f));}
std::vector<uint8_t> payload(uint8_t type,uint32_t key,uint32_t seq,const std::vector<uint8_t>&data,bool final){
    bool little=true;size_t pad=(8-(data.size()%8))%8,body=data.size()+pad;std::vector<uint8_t>b(HEADER+body+TRAILER,0);b[0]=cmd0(type,little);b[3]=0x80|0x08;put32(b,4,key,little);put32(b,16,seq,little);std::copy(data.begin(),data.end(),b.begin()+HEADER);size_t t=HEADER+body;put32(b,t,checksum32(b.data()+HEADER,body),little);b[t+8]=uint8_t(pad);uint8_t flags=TRAIL_SREQ;if(final)flags|=TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_EOM;b[t+9]=flags;put16(b,t+10,64,little);std::vector<uint8_t>ht;ht.insert(ht.end(),b.begin(),b.begin()+HEADER);ht.insert(ht.end(),b.begin()+t,b.end());put32(ht,HEADER+12,0,little);put32(b,t+12,checksum32(ht.data(),ht.size()),little);return b;
}
std::vector<uint8_t> reject(uint32_t key,uint32_t rseq,uint32_t alloc){
    bool l=true;std::vector<uint8_t>b(HEADER+CONTROL+TRAILER,0);b[0]=cmd0(TYPE_CNTL,l);b[3]=0x80;put32(b,4,(key&0x7fffffffU)|0x80000000U,l);size_t c=HEADER;put32(b,c+0,1000000000u,l);put32(b,c+4,65536u,l);put32(b,c+8,rseq,l);put32(b,c+12,alloc,l);put32(b,c+20,1,l);put32(b,c+28,(key&0x7fffffffU)|0x80000000U,l);size_t t=HEADER+CONTROL;put32(b,t,checksum32(b.data()+HEADER,CONTROL),l);put32(b,t+4,rseq,l);put16(b,t+10,64,l);std::vector<uint8_t>ht;ht.insert(ht.end(),b.begin(),b.begin()+HEADER);ht.insert(ht.end(),b.begin()+t,b.end());put32(ht,HEADER+12,0,l);put32(b,t+12,checksum32(ht.data(),ht.size()),l);return b;
}
void send_group(int fd,const sockaddr_in&group,const std::vector<uint8_t>&b){if(sendto(fd,b.data(),b.size(),0,reinterpret_cast<const sockaddr*>(&group),sizeof(group))<0)throw std::runtime_error(std::strerror(errno));}
}

int main(){
    try{
        if(!xtp::multicast_reject_covers(8,4)||xtp::multicast_reject_covers(4,8))throw std::runtime_error("reject coverage rule");
        xtp::Route route;route.peer="SUPPRESS";route.layer=4;route.carrier="udp";route.destination="239.192.0.51:29551";route.multicast=true;
        xtp::ListenOptions lo;lo.timeout_ms=2500;lo.receive_window=512;lo.reject_suppression_ms=120;
        xtp::MulticastListener listener(route,lo);
        xtp::ReceiveResult rr;std::exception_ptr ep;
        std::thread receiver([&]{try{rr=listener.receive();}catch(...){ep=std::current_exception();}});
        int fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)throw std::runtime_error("socket");unsigned char loop=1;setsockopt(fd,IPPROTO_IP,IP_MULTICAST_LOOP,&loop,sizeof(loop));
        sockaddr_in group{};group.sin_family=AF_INET;group.sin_port=htons(29551);inet_pton(AF_INET,"239.192.0.51",&group.sin_addr);
        std::this_thread::sleep_for(std::chrono::milliseconds(80));
        const uint32_t key=0x23456755u;
        send_group(fd,group,payload(TYPE_FIRST,key,0,{'A','A','A','A'},false));
        std::this_thread::sleep_for(std::chrono::milliseconds(25));
        send_group(fd,group,payload(TYPE_DATA,key,8,{'B','B','B','B'},false));
        std::this_thread::sleep_for(std::chrono::milliseconds(25));
        // Another receiver has already asked for rollback to byte 4. This
        // covers our own RSEQ=4, so our reject should be suppressed.
        send_group(fd,group,reject(key,4,516));
        std::this_thread::sleep_for(std::chrono::milliseconds(150));
        send_group(fd,group,payload(TYPE_DATA,key,4,{'C','C','C','C'},false));
        send_group(fd,group,payload(TYPE_DATA,key,8,{'B','B','B','B'},true));
        receiver.join();close(fd);if(ep)std::rethrow_exception(ep);
        std::string got(rr.logical.begin(),rr.logical.end());if(got!="AAAACCCCBBBB")throw std::runtime_error("reassembled payload mismatch: "+got);
        auto st=listener.stats();if(st.reject_notices_suppressed!=1||st.reject_notices_sent!=0)throw std::runtime_error("suppression counters mismatch");
        std::cout<<"PASS multicast peer reject suppression suppresses covered reject and completes stream\n";return 0;
    }catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<"\n";return 1;}
}
