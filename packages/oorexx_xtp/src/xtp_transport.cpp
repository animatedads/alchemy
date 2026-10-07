#include "xtp/xtp_transport.hpp"
#include "xtp/xtp_wire.hpp"
#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>
#include <algorithm>
#include <array>
#include <cerrno>
#include <cstdio>
#include <cstring>
#include <optional>
#include <map>
#include <set>
#include <stdexcept>
#include <utility>
#include <chrono>
#include <poll.h>
#include <deque>
#include <thread>

namespace xtp {

bool multicast_reject_covers(uint32_t own_rseq,uint32_t observed_rseq){ return own_rseq>=observed_rseq; }

namespace {
constexpr uint8_t XTP_VERSION=3, TYPE_DATA=0x00, TYPE_CNTL=0x01, TYPE_FIRST=0x02;
constexpr uint8_t TRAIL_SREQ=0x80, TRAIL_RCLOSE=0x20, TRAIL_WCLOSE=0x10, TRAIL_EOM=0x02, TRAIL_END=0x01, TRAIL_NODCHECK=0x08;
constexpr size_t HEADER=24, TRAILER=16, CONTROL=40;
constexpr uint16_t XTP_ETHERTYPE=0x817D;
constexpr std::array<uint8_t,8> QUAL_MAGIC{{'X','T','P','Q','1',0x00,0x36,0x7d}};

std::vector<uint8_t> qualification_payload(uint32_t key){
    std::vector<uint8_t> q(16,0);
    std::copy(QUAL_MAGIC.begin(),QUAL_MAGIC.end(),q.begin());
    q[8]=uint8_t(key>>24);q[9]=uint8_t(key>>16);q[10]=uint8_t(key>>8);q[11]=uint8_t(key);
    q[12]=0x51;q[13]=0x55;q[14]=0x41;q[15]=0x4c;
    return q;
}
bool qualification_payload_p(const std::vector<uint8_t>& q){
    return q.size()==16 && std::equal(QUAL_MAGIC.begin(),QUAL_MAGIC.end(),q.begin()) &&
           q[12]==0x51 && q[13]==0x55 && q[14]==0x41 && q[15]==0x4c;
}
std::pair<std::string,std::string> qualification_provider(const Route&r){
    if(r.layer==2 && r.carrier=="l2") return {"l2","ethernet-0x817d-first-cntl"};
    if(r.layer==3 && r.carrier=="raw36") return {"l3","ipv4-protocol-36-first-cntl"};
    if(r.layer==4 && r.carrier=="udp") return {"l4","udp-encapsulated-first-cntl"};
    return {"unknown","unsupported"};
}

uint16_t rol16(uint16_t v){return uint16_t((v<<1)|(v>>15));}
struct Checksum{uint16_t x=0,rx=0;};
Checksum checksum(const uint8_t*p,size_t n){Checksum c{};for(size_t i=0;i<n;i+=2){uint16_t w=uint16_t(p[i])<<8;if(i+1<n)w|=p[i+1];c.x^=w;c.rx=rol16(c.rx);c.rx^=w;}return c;}
uint32_t checksum32(const uint8_t*p,size_t n){auto c=checksum(p,n);return(uint32_t(c.x)<<16)|c.rx;}
void put32(std::vector<uint8_t>&b,size_t o,uint32_t v,bool l){if(l){b[o]=uint8_t(v);b[o+1]=uint8_t(v>>8);b[o+2]=uint8_t(v>>16);b[o+3]=uint8_t(v>>24);}else{b[o]=uint8_t(v>>24);b[o+1]=uint8_t(v>>16);b[o+2]=uint8_t(v>>8);b[o+3]=uint8_t(v);}}
void put16(std::vector<uint8_t>&b,size_t o,uint16_t v,bool l){if(l){b[o]=uint8_t(v);b[o+1]=uint8_t(v>>8);}else{b[o]=uint8_t(v>>8);b[o+1]=uint8_t(v);}}
uint32_t get32(const uint8_t*b,size_t o,bool l){if(l)return uint32_t(b[o])|(uint32_t(b[o+1])<<8)|(uint32_t(b[o+2])<<16)|(uint32_t(b[o+3])<<24);return(uint32_t(b[o])<<24)|(uint32_t(b[o+1])<<16)|(uint32_t(b[o+2])<<8)|uint32_t(b[o+3]);}
uint8_t cmd0(uint8_t type,bool l){return uint8_t((l?0x80:0)|((XTP_VERSION&3)<<5)|(type&0x1f));}

std::vector<uint8_t> payload_packet(uint8_t type,uint32_t key,uint32_t seq,const std::vector<uint8_t>&data,bool little,bool multi=false,bool noerr=false,bool final_packet=true,bool status_request=true){
    size_t pad=(8-(data.size()%8))%8,body=data.size()+pad;
    std::vector<uint8_t>b(HEADER+body+TRAILER,0);
    b[0]=cmd0(type,little);
    b[3]=uint8_t((little?0x80:0)|(noerr?0x10:0)|(multi?0x08:0));
    put32(b,4,key&0x7fffffffU,little);
    put32(b,16,seq,little);
    std::copy(data.begin(),data.end(),b.begin()+HEADER);
    size_t t=HEADER+body;
    put32(b,t,checksum32(b.data()+HEADER,body),little);
    b[t+8]=uint8_t(pad);
    uint8_t flags=0;
    if(status_request) flags|=TRAIL_SREQ;
    if(final_packet) flags|=TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_EOM;
    b[t+9]=flags;
    put16(b,t+10,64,little);
    std::vector<uint8_t>ht;ht.insert(ht.end(),b.begin(),b.begin()+HEADER);ht.insert(ht.end(),b.begin()+t,b.end());put32(ht,HEADER+12,0,little);put32(b,t+12,checksum32(ht.data(),ht.size()),little);return b;
}

std::vector<uint8_t> first_packet(uint32_t key,const std::vector<uint8_t>&data,bool little,bool multi=false,bool noerr=false){
    return payload_packet(TYPE_FIRST,key,0,data,little,multi,noerr,true,true);
}


struct Cntl{uint32_t key=0,rate=0xffffffffu,burst=0xffffffffu,rseq=0,dseq=0,alloc=0;uint8_t flags=0;};
std::optional<Cntl> parse_cntl(const uint8_t*p,size_t n){
    if(n<HEADER+CONTROL+TRAILER||(n%8)!=0) return std::nullopt;
    bool l=(p[0]&0x80)!=0;
    if(((p[3]&0x80)!=0)!=l) return std::nullopt;
    if(((p[0]>>5)&3)!=XTP_VERSION||(p[0]&0x1f)!=TYPE_CNTL) return std::nullopt;
    size_t t=n-TRAILER;std::vector<uint8_t>ht;ht.insert(ht.end(),p,p+HEADER);ht.insert(ht.end(),p+t,p+n);uint32_t given=get32(p,t+12,l);put32(ht,HEADER+12,0,l);if(checksum32(ht.data(),ht.size())!=given)return std::nullopt;if(!(p[t+9]&TRAIL_NODCHECK)&&checksum32(p+HEADER,t-HEADER)!=get32(p,t,l))return std::nullopt;
    Cntl q;q.key=get32(p,4,l);q.rate=get32(p,HEADER+0,l);q.burst=get32(p,HEADER+4,l);q.rseq=get32(p,HEADER+8,l);q.alloc=get32(p,HEADER+12,l);q.dseq=get32(p,t+4,l);q.flags=p[t+9];return q;
}

struct PayloadPacket { bool little=false; bool multi=false; bool noerr=false; bool first=false; bool final_packet=false; bool status_request=false; uint32_t key=0,seq=0; std::vector<uint8_t> data; };
std::optional<PayloadPacket> parse_payload_packet(const uint8_t*p,size_t n){
    if(n<HEADER+TRAILER||(n%8)!=0)return std::nullopt;
    bool l=(p[0]&0x80)!=0;if(((p[3]&0x80)!=0)!=l)return std::nullopt;
    uint8_t type=uint8_t(p[0]&0x1f);
    if(((p[0]>>5)&3)!=XTP_VERSION||(type!=TYPE_FIRST&&type!=TYPE_DATA))return std::nullopt;
    size_t t=n-TRAILER;uint8_t pad=uint8_t(p[t+8]&0x3f);if(pad>t-HEADER)return std::nullopt;
    std::vector<uint8_t>ht;ht.insert(ht.end(),p,p+HEADER);ht.insert(ht.end(),p+t,p+n);uint32_t hgiven=get32(p,t+12,l);put32(ht,HEADER+12,0,l);if(checksum32(ht.data(),ht.size())!=hgiven)return std::nullopt;
    if(!(p[t+9]&TRAIL_NODCHECK)&&checksum32(p+HEADER,t-HEADER)!=get32(p,t,l))return std::nullopt;
    PayloadPacket f;f.little=l;f.multi=(p[3]&0x08)!=0;f.noerr=(p[3]&0x10)!=0;f.first=type==TYPE_FIRST;f.key=get32(p,4,l)&0x7fffffffU;f.seq=get32(p,16,l);f.final_packet=(p[t+9]&TRAIL_EOM)!=0;f.status_request=(p[t+9]&TRAIL_SREQ)!=0;f.data.assign(p+HEADER,p+t-pad);return f;
}

using First = PayloadPacket;
std::optional<First> parse_first(const uint8_t*p,size_t n){auto f=parse_payload_packet(p,n);if(!f||!f->first)return std::nullopt;return f;}

std::vector<uint8_t> control_packet_ex(uint32_t key,uint32_t received,uint32_t alloc,bool little,bool close_context,uint32_t rate=0xffffffffu,uint32_t burst=0xffffffffu){
    if(rate==0) throw std::runtime_error("XTP RATE must be positive or 0xffffffff (disabled)");
    if(burst==0) throw std::runtime_error("XTP BURST must be positive");
    std::vector<uint8_t>b(HEADER+CONTROL+TRAILER,0);b[0]=cmd0(TYPE_CNTL,little);b[3]=little?0x80:0;put32(b,4,(key&0x7fffffffU)|0x80000000U,little);
    size_t c=HEADER;put32(b,c+0,rate,little);put32(b,c+4,burst,little);put32(b,c+8,received,little);put32(b,c+12,alloc,little);put32(b,c+20,1,little);put32(b,c+28,(key&0x7fffffffU)|0x80000000U,little);
    size_t t=HEADER+CONTROL;put32(b,t,checksum32(b.data()+HEADER,CONTROL),little);put32(b,t+4,received,little);b[t+9]=close_context?uint8_t(TRAIL_WCLOSE|TRAIL_RCLOSE|TRAIL_END):0;put16(b,t+10,64,little);
    std::vector<uint8_t>ht;ht.insert(ht.end(),b.begin(),b.begin()+HEADER);ht.insert(ht.end(),b.begin()+t,b.end());put32(ht,HEADER+12,0,little);put32(b,t+12,checksum32(ht.data(),ht.size()),little);return b;
}
std::vector<uint8_t> control_packet(uint32_t key,uint32_t received,uint32_t alloc,bool little,uint32_t rate=0xffffffffu,uint32_t burst=0xffffffffu){return control_packet_ex(key,received,alloc,little,true,rate,burst);}
std::vector<uint8_t> reject_packet(uint32_t key,uint32_t rseq,uint32_t alloc,bool little,uint32_t rate=0xffffffffu,uint32_t burst=0xffffffffu){return control_packet_ex(key,rseq,alloc,little,false,rate,burst);}

struct Endpoint{std::string host;uint16_t port;};
Endpoint ep(const std::string&s){auto k=s.rfind(':');if(k==std::string::npos)throw std::runtime_error("L4 destination must be host:port");unsigned long p=std::stoul(s.substr(k+1));if(p>65535)throw std::runtime_error("bad L4 port");return{s.substr(0,k),uint16_t(p)};}
sockaddr_in ipaddr(const std::string&h,uint16_t port=0){sockaddr_in a{};a.sin_family=AF_INET;a.sin_port=htons(port);if(inet_pton(AF_INET,h.c_str(),&a.sin_addr)!=1)throw std::runtime_error("XTP transport currently supports IPv4 destinations");return a;}
void set_timeout(int fd,int ms){if(ms<=0)return;timeval tv{ms/1000,(ms%1000)*1000};if(setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv))<0)throw std::runtime_error(std::string("setsockopt timeout: ")+std::strerror(errno));}
std::array<uint8_t,6> mac(const std::string&s){std::array<uint8_t,6>m{};unsigned v[6];if(std::sscanf(s.c_str(),"%x:%x:%x:%x:%x:%x",&v[0],&v[1],&v[2],&v[3],&v[4],&v[5])!=6)throw std::runtime_error("bad MAC address");for(size_t i=0;i<6;i++){if(v[i]>255)throw std::runtime_error("bad MAC address");m[i]=uint8_t(v[i]);}return m;}
std::string mac_text(const uint8_t*m){char b[32];std::snprintf(b,sizeof(b),"%02x:%02x:%02x:%02x:%02x:%02x",m[0],m[1],m[2],m[3],m[4],m[5]);return b;}
std::array<uint8_t,6> iface_mac(int fd,const std::string&ifn){ifreq r{};std::strncpy(r.ifr_name,ifn.c_str(),IFNAMSIZ-1);if(ioctl(fd,SIOCGIFHWADDR,&r)<0)throw std::runtime_error(std::string("SIOCGIFHWADDR: ")+std::strerror(errno));std::array<uint8_t,6>m{};std::memcpy(m.data(),r.ifr_hwaddr.sa_data,6);return m;}
std::optional<std::pair<const uint8_t*,size_t>> raw_payload(const uint8_t*p,size_t n){if(n<20)return std::nullopt;uint8_t ihl=uint8_t((p[0]&0x0f)*4);if((p[0]>>4)!=4||ihl<20||n<ihl||p[9]!=36)return std::nullopt;return std::make_pair(p+ihl,n-ihl);}
SendResult base_result(const Route&r,size_t logical,size_t wire){SendResult x;x.route=r;x.logical_bytes=logical;x.wire_bytes=wire;return x;}
void validate_ack(const Cntl&q,uint32_t key,size_t wire){if((q.key&0x7fffffffU)!=(key&0x7fffffffU))throw std::runtime_error("XTP control key mismatch");if((q.flags&(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END))!=(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END))throw std::runtime_error("XTP close acknowledgement incomplete");if(q.rseq<wire||q.dseq<wire)throw std::runtime_error("XTP acknowledgement behind transmitted wire sequence");}

SendResult send_udp(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const SendOptions&o){auto e=ep(r.destination);int fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)throw std::runtime_error(std::string("UDP socket: ")+std::strerror(errno));try{set_timeout(fd,o.timeout_ms);auto a=ipaddr(e.host,e.port);auto pkt=first_packet(o.key,wire,o.little_endian);for(int attempt=1;attempt<=o.retries;++attempt){if(sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("UDP sendto: ")+std::strerror(errno));std::array<uint8_t,65536>b{};ssize_t n=recvfrom(fd,b.data(),b.size(),0,nullptr,nullptr);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK||errno==EINTR)continue;throw std::runtime_error(std::string("UDP recvfrom: ")+std::strerror(errno));}auto q=parse_cntl(b.data(),size_t(n));if(!q||(q->key&0x7fffffffU)!=(o.key&0x7fffffffU))continue;validate_ack(*q,o.key,wire.size());auto x=base_result(r,logical,wire.size());x.attempts=attempt;x.rseq=q->rseq;x.dseq=q->dseq;x.alloc=q->alloc;x.peer_rate_bytes_per_sec=q->rate;x.peer_burst_bytes=q->burst;close(fd);return x;}throw std::runtime_error("XTP L4 retries exhausted");}catch(...){close(fd);throw;}}
SendResult send_raw36(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const SendOptions&o){int fd=socket(AF_INET,SOCK_RAW,36);if(fd<0)throw std::runtime_error(std::string("raw36 socket: ")+std::strerror(errno));try{set_timeout(fd,o.timeout_ms);if(!r.interface_name.empty()){ifreq ifr{};std::strncpy(ifr.ifr_name,r.interface_name.c_str(),IFNAMSIZ-1);if(setsockopt(fd,SOL_SOCKET,SO_BINDTODEVICE,&ifr,sizeof(ifr))<0)throw std::runtime_error(std::string("SO_BINDTODEVICE: ")+std::strerror(errno));}auto a=ipaddr(r.destination);auto pkt=first_packet(o.key,wire,o.little_endian);for(int attempt=1;attempt<=o.retries;++attempt){if(sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("raw36 sendto: ")+std::strerror(errno));for(;;){std::array<uint8_t,65536>b{};ssize_t n=recvfrom(fd,b.data(),b.size(),0,nullptr,nullptr);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK)break;if(errno==EINTR)continue;throw std::runtime_error(std::string("raw36 recvfrom: ")+std::strerror(errno));}auto pp=raw_payload(b.data(),size_t(n));if(!pp)continue;auto q=parse_cntl(pp->first,pp->second);if(!q||(q->key&0x7fffffffU)!=(o.key&0x7fffffffU))continue;validate_ack(*q,o.key,wire.size());auto x=base_result(r,logical,wire.size());x.attempts=attempt;x.rseq=q->rseq;x.dseq=q->dseq;x.alloc=q->alloc;x.peer_rate_bytes_per_sec=q->rate;x.peer_burst_bytes=q->burst;close(fd);return x;}}throw std::runtime_error("XTP L3 retries exhausted");}catch(...){close(fd);throw;}}
SendResult send_l2(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const SendOptions&o){if(r.interface_name.empty())throw std::runtime_error("L2 route has no interface");unsigned idx=if_nametoindex(r.interface_name.c_str());if(!idx)throw std::runtime_error("unknown L2 interface: "+r.interface_name);int fd=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));if(fd<0)throw std::runtime_error(std::string("AF_PACKET socket: ")+std::strerror(errno));try{sockaddr_ll bindaddr{};bindaddr.sll_family=AF_PACKET;bindaddr.sll_protocol=htons(XTP_ETHERTYPE);bindaddr.sll_ifindex=int(idx);if(bind(fd,reinterpret_cast<sockaddr*>(&bindaddr),sizeof(bindaddr))<0)throw std::runtime_error(std::string("AF_PACKET bind: ")+std::strerror(errno));set_timeout(fd,o.timeout_ms);auto dst=mac(r.destination),src=iface_mac(fd,r.interface_name);auto pkt=first_packet(o.key,wire,o.little_endian);std::vector<uint8_t>frame(14+pkt.size());std::copy(dst.begin(),dst.end(),frame.begin());std::copy(src.begin(),src.end(),frame.begin()+6);frame[12]=uint8_t(XTP_ETHERTYPE>>8);frame[13]=uint8_t(XTP_ETHERTYPE);std::copy(pkt.begin(),pkt.end(),frame.begin()+14);sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(idx);out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);for(int attempt=1;attempt<=o.retries;++attempt){if(sendto(fd,frame.data(),frame.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("AF_PACKET sendto: ")+std::strerror(errno));for(;;){std::array<uint8_t,65536>b{};ssize_t n=recvfrom(fd,b.data(),b.size(),0,nullptr,nullptr);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK)break;if(errno==EINTR)continue;throw std::runtime_error(std::string("AF_PACKET recvfrom: ")+std::strerror(errno));}if(n<14||b[12]!=uint8_t(XTP_ETHERTYPE>>8)||b[13]!=uint8_t(XTP_ETHERTYPE))continue;auto q=parse_cntl(b.data()+14,size_t(n)-14);if(!q||(q->key&0x7fffffffU)!=(o.key&0x7fffffffU))continue;validate_ack(*q,o.key,wire.size());auto x=base_result(r,logical,wire.size());x.attempts=attempt;x.rseq=q->rseq;x.dseq=q->dseq;x.alloc=q->alloc;x.peer_rate_bytes_per_sec=q->rate;x.peer_burst_bytes=q->burst;close(fd);return x;}}throw std::runtime_error("XTP L2 retries exhausted");}catch(...){close(fd);throw;}}

bool ipv4_multicast(const sockaddr_in& a){return IN_MULTICAST(ntohl(a.sin_addr.s_addr));}
bool mac_multicast(const std::array<uint8_t,6>& m){return (m[0]&1u)!=0;}
std::string ip_peer(const sockaddr_in&a,bool port){char b[INET_ADDRSTRLEN]{};inet_ntop(AF_INET,&a.sin_addr,b,sizeof(b));return port?std::string(b)+":"+std::to_string(ntohs(a.sin_port)):std::string(b);}
void set_multicast_if(int fd,const std::string&ifn){if(ifn.empty())return;ip_mreqn m{};m.imr_ifindex=int(if_nametoindex(ifn.c_str()));if(!m.imr_ifindex)throw std::runtime_error("unknown multicast interface: "+ifn);if(setsockopt(fd,IPPROTO_IP,IP_MULTICAST_IF,&m,sizeof(m))<0)throw std::runtime_error(std::string("IP_MULTICAST_IF: ")+std::strerror(errno));}
void set_multicast_opts(int fd,const MulticastOptions&o){unsigned char ttl=static_cast<unsigned char>(std::max(0,std::min(255,o.ttl)));unsigned char loop=o.loopback?1:0;if(setsockopt(fd,IPPROTO_IP,IP_MULTICAST_TTL,&ttl,sizeof(ttl))<0)throw std::runtime_error(std::string("IP_MULTICAST_TTL: ")+std::strerror(errno));if(setsockopt(fd,IPPROTO_IP,IP_MULTICAST_LOOP,&loop,sizeof(loop))<0)throw std::runtime_error(std::string("IP_MULTICAST_LOOP: ")+std::strerror(errno));}
void join_ipv4_group(int fd,const std::string&group,const std::string&ifn){ip_mreqn m{};if(inet_pton(AF_INET,group.c_str(),&m.imr_multiaddr)!=1)throw std::runtime_error("bad IPv4 multicast group");if(!IN_MULTICAST(ntohl(m.imr_multiaddr.s_addr)))throw std::runtime_error("destination is not IPv4 multicast");if(!ifn.empty()){m.imr_ifindex=int(if_nametoindex(ifn.c_str()));if(!m.imr_ifindex)throw std::runtime_error("unknown multicast interface: "+ifn);}if(setsockopt(fd,IPPROTO_IP,IP_ADD_MEMBERSHIP,&m,sizeof(m))<0)throw std::runtime_error(std::string("IP_ADD_MEMBERSHIP: ")+std::strerror(errno));}

MulticastSendResult mbase(const Route&r,size_t logical,size_t wire,const MulticastOptions&o){MulticastSendResult x;x.route=r;x.logical_bytes=logical;x.wire_bytes=wire;x.required_acknowledgements=o.reliable?o.expected_receivers:0;return x;}
void mvalidate(const MulticastOptions&o){if(o.reliable&&o.expected_receivers==0)throw std::runtime_error("reliable XTP multicast requires expected_receivers > 0");if(o.retries<1)throw std::runtime_error("multicast retries must be positive");if(o.segment_bytes<64||o.segment_bytes>60000)throw std::runtime_error("multicast segment_bytes must be between 64 and 60000");}

struct MulticastSegment{uint32_t seq=0;std::vector<uint8_t> packet;};
std::vector<MulticastSegment> multicast_segments(const std::vector<uint8_t>&wire,const MulticastOptions&o){
    std::vector<MulticastSegment> out;
    if(wire.empty()){
        out.push_back({0,payload_packet(TYPE_FIRST,o.key,0,{},o.little_endian,true,!o.reliable,true,true)});
        return out;
    }
    for(size_t pos=0;pos<wire.size();pos+=o.segment_bytes){
        const size_t n=std::min(o.segment_bytes,wire.size()-pos);
        std::vector<uint8_t> chunk(wire.begin()+pos,wire.begin()+pos+n);
        const bool first=pos==0, final_packet=pos+n==wire.size();
        // The final packet solicits receiver status. Earlier gap detection can
        // generate a reject CNTL immediately at the receiver.
        out.push_back({uint32_t(pos),payload_packet(first?TYPE_FIRST:TYPE_DATA,o.key,uint32_t(pos),chunk,o.little_endian,true,!o.reliable,final_packet,o.reliable||final_packet)});
    }
    return out;
}
size_t segment_for_rseq(const std::vector<MulticastSegment>&segs,uint32_t rseq){
    for(size_t i=0;i<segs.size();++i){
        uint32_t next=(i+1<segs.size())?segs[i+1].seq:UINT32_MAX;
        if(rseq>=segs[i].seq&&rseq<next)return i;
    }
    return segs.empty()?0:segs.size()-1;
}

template<class SendFn,class RecvFn>
MulticastSendResult multicast_engine(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const MulticastOptions&o,SendFn send_one,RecvFn recv_one){
    mvalidate(o);auto segs=multicast_segments(wire,o);auto x=mbase(r,logical,wire.size(),o);x.packets=segs.size();
    if(!o.reliable){for(const auto&s:segs)send_one(s.packet);return x;}

    struct ReceiverState{uint32_t rate=0xffffffffu,burst=0xffffffffu,rseq=0,dseq=0,alloc=0;bool complete=false;};
    std::map<std::string,ReceiverState> receivers;
    std::set<std::string> completed;
    std::vector<bool> sent_once(segs.size(),false);
    size_t next_index=0;
    uint32_t high_water=0;
    int recovery_rounds=0;
    size_t safety_rounds=0;

    struct Limits{uint32_t rseq=0,alloc=0,rate=0xffffffffu,burst=0xffffffffu;};
    auto recompute=[&](){
        Limits z;
        if(receivers.empty()) return z;
        z.rseq=uint32_t(wire.size());z.alloc=UINT32_MAX;
        for(const auto&kv:receivers){
            z.rseq=std::min(z.rseq,kv.second.rseq);
            z.alloc=std::min(z.alloc,kv.second.alloc);
            z.rate=std::min(z.rate,kv.second.rate);
            z.burst=std::min(z.burst,kv.second.burst);
        }
        if(z.alloc==UINT32_MAX)z.alloc=0;
        return z;
    };

    struct RateGate{
        using clock=std::chrono::steady_clock;
        clock::time_point burst_start=clock::now();
        uint64_t bytes=0;
        void before(size_t n,uint32_t rate,uint32_t burst,MulticastSendResult&x){
            if(rate==0xffffffffu||burst==0xffffffffu)return;
            if(rate==0||burst==0)throw std::runtime_error("invalid XTP RATE/BURST from receiver");
            if(n>burst)throw std::runtime_error("XTP information packet exceeds receiver BURST");
            if(bytes+n>burst){
                const uint64_t target_us=(uint64_t(bytes)*1000000ull+rate-1)/rate;
                const uint64_t elapsed_us=uint64_t(std::max<int64_t>(0,std::chrono::duration_cast<std::chrono::microseconds>(clock::now()-burst_start).count()));
                if(elapsed_us<target_us){const auto sleep_us=target_us-elapsed_us;std::this_thread::sleep_for(std::chrono::microseconds(sleep_us));x.rate_sleep_microseconds+=sleep_us;}
                x.rate_paced_bursts++;burst_start=clock::now();bytes=0;
            }
            bytes+=n;
        }
    } rate_gate;

    while(++safety_rounds<100000){
        if(completed.size()>=o.expected_receivers){
            x.acknowledgements=completed.size();x.responders.assign(completed.begin(),completed.end());
            x.slowest_rseq=uint32_t(wire.size());auto mm=recompute();x.slowest_alloc=mm.alloc;x.slowest_rate_bytes_per_sec=mm.rate;x.slowest_burst_bytes=mm.burst;x.attempts=1+recovery_rounds;return x;
        }
        if(recovery_rounds>=o.retries) throw std::runtime_error("XTP multicast acknowledgement quorum not reached");

        auto mm=recompute();uint32_t min_rseq=mm.rseq,min_alloc=mm.alloc;
        const bool population_known=receivers.size()>=o.expected_receivers;
        size_t burst_start=next_index;size_t burst_end=next_index;

        if(next_index<segs.size()){
            uint32_t send_limit=UINT32_MAX;
            if(o.allocation_pacing){
                if(!population_known) send_limit=segs[next_index].seq+uint32_t(std::min(o.segment_bytes,wire.size()-std::min<size_t>(wire.size(),segs[next_index].seq)));
                else send_limit=min_alloc;
            }
            while(burst_end<segs.size()){
                const uint32_t endseq=(burst_end+1<segs.size())?segs[burst_end+1].seq:uint32_t(wire.size());
                if(o.allocation_pacing && endseq>send_limit) break;
                uint32_t pace_rate=o.default_rate_bytes_per_sec,pace_burst=o.default_burst_bytes;
                if(population_known){pace_rate=mm.rate;pace_burst=mm.burst;}
                if(o.rate_pacing)rate_gate.before(segs[burst_end].packet.size(),pace_rate,pace_burst,x);
                send_one(segs[burst_end].packet);
                if(sent_once[burst_end]) x.retransmitted_packets++; else sent_once[burst_end]=true;
                high_water=std::max(high_water,endseq);burst_end++;
                if(!population_known) break; // establish the receiver population before opening the window
            }
            if(burst_end>burst_start){next_index=burst_end;x.allocation_rounds++;}
            else if(o.allocation_pacing){x.allocation_stalls++;}
        }

        bool got_any=false;
        for(;;){
            auto got=recv_one();if(!got)break;
            const auto&who=got->first;const auto&q=got->second;
            if((q.key&0x7fffffffU)!=(o.key&0x7fffffffU))continue;
            got_any=true;
            auto&st=receivers[who];
            // UDP/raw/L2 delivery preserves packet order per responder in the
            // paths supported here.  The last CNTL therefore represents that
            // receiver's current contiguous prefix and allocation.
            st.rate=q.rate;st.burst=q.burst;st.rseq=q.rseq;st.dseq=q.dseq;st.alloc=q.alloc;
            st.complete=(q.rseq>=wire.size()&&q.dseq>=wire.size());
            if(st.complete)completed.insert(who); else completed.erase(who);
        }

        mm=recompute();min_rseq=mm.rseq;min_alloc=mm.alloc;
        x.slowest_rseq=min_rseq;x.slowest_alloc=min_alloc;x.slowest_rate_bytes_per_sec=mm.rate;x.slowest_burst_bytes=mm.burst;
        if(completed.size()>=o.expected_receivers) continue;

        if(receivers.size()<o.expected_receivers){
            // Unknown/missing receiver population: solicit from the earliest
            // data again rather than running ahead of an unmeasured window.
            recovery_rounds++;next_index=0;continue;
        }

        if(min_rseq<high_water){
            // At least one receiver has not accepted the complete transmitted
            // prefix.  XTP multicast uses go-back-N from the slowest RSEQ.
            x.rollback_events++;recovery_rounds++;next_index=segment_for_rseq(segs,min_rseq);continue;
        }

        if(next_index>=segs.size()){
            // Data reached every measured receiver but a final close/status may
            // have been lost. Re-solicit with the final information segment.
            recovery_rounds++;next_index=segs.empty()?0:segs.size()-1;continue;
        }

        if(o.allocation_pacing){
            const uint32_t next_end=(next_index+1<segs.size())?segs[next_index+1].seq:uint32_t(wire.size());
            if(next_end>min_alloc){
                // No legal transmission beyond the slowest advertised ALLOC.
                // Re-solicit status at the current contiguous edge if no fresh
                // status arrived; otherwise the next loop uses the new window.
                x.allocation_stalls++;
                if(!got_any){recovery_rounds++;next_index=segment_for_rseq(segs,min_rseq?min_rseq-1:0);}
                continue;
            }
        }
    }
    throw std::runtime_error("XTP multicast flow-control safety limit reached");
}

MulticastSendResult multicast_udp(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const MulticastOptions&o){
    auto e=ep(r.destination);int fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)throw std::runtime_error(std::string("UDP multicast socket: ")+std::strerror(errno));
    try{set_timeout(fd,o.timeout_ms);set_multicast_if(fd,r.interface_name);set_multicast_opts(fd,o);auto a=ipaddr(e.host,e.port);if(!ipv4_multicast(a))throw std::runtime_error("L4 multicast route requires an IPv4 multicast destination");
        auto send_one=[&](const std::vector<uint8_t>&pkt){if(sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("UDP multicast sendto: ")+std::strerror(errno));};
        auto recv_one=[&]()->std::optional<std::pair<std::string,Cntl>>{for(;;){std::array<uint8_t,65536>b{};sockaddr_in peer{};socklen_t pl=sizeof(peer);ssize_t n=recvfrom(fd,b.data(),b.size(),0,reinterpret_cast<sockaddr*>(&peer),&pl);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK)return std::nullopt;if(errno==EINTR)continue;throw std::runtime_error(std::string("UDP multicast recvfrom: ")+std::strerror(errno));}auto q=parse_cntl(b.data(),size_t(n));if(q)return std::make_pair(ip_peer(peer,true),*q);}};
        auto out=multicast_engine(r,wire,logical,o,send_one,recv_one);close(fd);return out;
    }catch(...){close(fd);throw;}}

MulticastSendResult multicast_raw36(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const MulticastOptions&o){
    int fd=socket(AF_INET,SOCK_RAW,36);if(fd<0)throw std::runtime_error(std::string("raw36 multicast socket: ")+std::strerror(errno));
    try{set_timeout(fd,o.timeout_ms);if(!r.interface_name.empty()){ifreq ifr{};std::strncpy(ifr.ifr_name,r.interface_name.c_str(),IFNAMSIZ-1);if(setsockopt(fd,SOL_SOCKET,SO_BINDTODEVICE,&ifr,sizeof(ifr))<0)throw std::runtime_error(std::string("SO_BINDTODEVICE: ")+std::strerror(errno));}set_multicast_if(fd,r.interface_name);set_multicast_opts(fd,o);auto a=ipaddr(r.destination);if(!ipv4_multicast(a))throw std::runtime_error("L3 multicast route requires an IPv4 multicast destination");
        auto send_one=[&](const std::vector<uint8_t>&pkt){if(sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("raw36 multicast sendto: ")+std::strerror(errno));};
        auto recv_one=[&]()->std::optional<std::pair<std::string,Cntl>>{for(;;){std::array<uint8_t,65536>b{};sockaddr_in peer{};socklen_t pl=sizeof(peer);ssize_t n=recvfrom(fd,b.data(),b.size(),0,reinterpret_cast<sockaddr*>(&peer),&pl);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK)return std::nullopt;if(errno==EINTR)continue;throw std::runtime_error(std::string("raw36 multicast recvfrom: ")+std::strerror(errno));}auto pp=raw_payload(b.data(),size_t(n));if(!pp)continue;auto q=parse_cntl(pp->first,pp->second);if(q)return std::make_pair(ip_peer(peer,false),*q);}};
        auto out=multicast_engine(r,wire,logical,o,send_one,recv_one);close(fd);return out;
    }catch(...){close(fd);throw;}}

MulticastSendResult multicast_l2(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const MulticastOptions&o){
    if(r.interface_name.empty()) throw std::runtime_error("L2 multicast route has no interface");
    unsigned idx=if_nametoindex(r.interface_name.c_str());
    if(!idx) throw std::runtime_error("unknown L2 interface: "+r.interface_name);
    int fd=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));
    if(fd<0) throw std::runtime_error(std::string("AF_PACKET multicast socket: ")+std::strerror(errno));
    try{sockaddr_ll ba{};ba.sll_family=AF_PACKET;ba.sll_protocol=htons(XTP_ETHERTYPE);ba.sll_ifindex=int(idx);if(bind(fd,reinterpret_cast<sockaddr*>(&ba),sizeof(ba))<0)throw std::runtime_error(std::string("AF_PACKET bind: ")+std::strerror(errno));set_timeout(fd,o.timeout_ms);auto dst=mac(r.destination),src=iface_mac(fd,r.interface_name);if(!mac_multicast(dst))throw std::runtime_error("L2 multicast route requires a multicast MAC");sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(idx);out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);
        auto send_one=[&](const std::vector<uint8_t>&pkt){std::vector<uint8_t>frame(14+pkt.size());std::copy(dst.begin(),dst.end(),frame.begin());std::copy(src.begin(),src.end(),frame.begin()+6);frame[12]=uint8_t(XTP_ETHERTYPE>>8);frame[13]=uint8_t(XTP_ETHERTYPE);std::copy(pkt.begin(),pkt.end(),frame.begin()+14);if(sendto(fd,frame.data(),frame.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("AF_PACKET multicast sendto: ")+std::strerror(errno));};
        auto recv_one=[&]()->std::optional<std::pair<std::string,Cntl>>{for(;;){std::array<uint8_t,65536>b{};ssize_t n=recvfrom(fd,b.data(),b.size(),0,nullptr,nullptr);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK)return std::nullopt;if(errno==EINTR)continue;throw std::runtime_error(std::string("AF_PACKET multicast recvfrom: ")+std::strerror(errno));}if(n<14||b[12]!=uint8_t(XTP_ETHERTYPE>>8)||b[13]!=uint8_t(XTP_ETHERTYPE))continue;auto q=parse_cntl(b.data()+14,size_t(n)-14);if(q)return std::make_pair(mac_text(b.data()+6),*q);}};
        auto result=multicast_engine(r,wire,logical,o,send_one,recv_one);close(fd);return result;
    }catch(...){close(fd);throw;}}

} // namespace

SendResult send_message(const Route& route,const std::vector<uint8_t>&logical,const SendOptions&options){
    auto wr=WireFilterChain::parse_spec(route.wire_filters).encode(logical);
    if(route.layer==2 && route.carrier=="l2") return send_l2(route,wr.bytes,logical.size(),options);
    if(route.layer==3 && route.carrier=="raw36") return send_raw36(route,wr.bytes,logical.size(),options);
    if(route.layer==4 && route.carrier=="udp") return send_udp(route,wr.bytes,logical.size(),options);
    throw std::runtime_error("unsupported XTP route carrier/layer: "+std::to_string(route.layer)+"/"+route.carrier);
}

MulticastSendResult send_multicast(const Route& route,const std::vector<uint8_t>&logical,const MulticastOptions&options){
    if(!route.multicast) throw std::runtime_error("XTP multicast requires a route marked multicast");
    auto wr=WireFilterChain::parse_spec(route.wire_filters).encode(logical);
    if(route.layer==2 && route.carrier=="l2") return multicast_l2(route,wr.bytes,logical.size(),options);
    if(route.layer==3 && route.carrier=="raw36") return multicast_raw36(route,wr.bytes,logical.size(),options);
    if(route.layer==4 && route.carrier=="udp") return multicast_udp(route,wr.bytes,logical.size(),options);
    throw std::runtime_error("unsupported XTP multicast carrier/layer: "+std::to_string(route.layer)+"/"+route.carrier);
}

QualificationResult qualify_path(const Route& route,const SendOptions&options){
    const auto provider=qualification_provider(route);
    if(provider.first=="unknown")
        throw std::runtime_error("unsupported XTP qualification carrier/layer: "+std::to_string(route.layer)+"/"+route.carrier);
    SendOptions qopt=options;
    if((qopt.key&0x7fffffffU)==0) qopt.key=0x5155414cU;
    const auto sent=send_message(route,qualification_payload(qopt.key),qopt);
    QualificationResult q;
    q.route=route;q.provider=provider.first;q.method=provider.second;q.attempts=sent.attempts;
    return q;
}

struct Listener::Impl {
    Route route;
    ListenOptions options;
    int fd=-1;
    std::set<uint32_t> delivered;
    std::array<uint8_t,6> local_mac{};
    unsigned ifindex=0;

    Impl(const Route&r,const ListenOptions&o):route(r),options(o){
        if(route.layer==4 && route.carrier=="udp"){
            auto e=ep(route.destination);fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)throw std::runtime_error(std::string("UDP listener socket: ")+std::strerror(errno));
            try{auto a=ipaddr(e.host,e.port);if(bind(fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("UDP listener bind: ")+std::strerror(errno));set_timeout(fd,options.timeout_ms);}catch(...){::close(fd);fd=-1;throw;}
        } else if(route.layer==3 && route.carrier=="raw36"){
            fd=socket(AF_INET,SOCK_RAW,36);if(fd<0)throw std::runtime_error(std::string("raw36 listener socket: ")+std::strerror(errno));
            try{if(!route.destination.empty()){auto a=ipaddr(route.destination);if(bind(fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("raw36 listener bind: ")+std::strerror(errno));}if(!route.interface_name.empty()){ifreq ifr{};std::strncpy(ifr.ifr_name,route.interface_name.c_str(),IFNAMSIZ-1);if(setsockopt(fd,SOL_SOCKET,SO_BINDTODEVICE,&ifr,sizeof(ifr))<0)throw std::runtime_error(std::string("SO_BINDTODEVICE: ")+std::strerror(errno));}set_timeout(fd,options.timeout_ms);}catch(...){::close(fd);fd=-1;throw;}
        } else if(route.layer==2 && route.carrier=="l2"){
            if(route.interface_name.empty()) throw std::runtime_error("L2 listener route has no interface");
            ifindex=if_nametoindex(route.interface_name.c_str());
            if(!ifindex) throw std::runtime_error("unknown L2 interface: "+route.interface_name);
            fd=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));if(fd<0)throw std::runtime_error(std::string("AF_PACKET listener socket: ")+std::strerror(errno));
            try{sockaddr_ll a{};a.sll_family=AF_PACKET;a.sll_protocol=htons(XTP_ETHERTYPE);a.sll_ifindex=int(ifindex);if(bind(fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("AF_PACKET listener bind: ")+std::strerror(errno));local_mac=iface_mac(fd,route.interface_name);set_timeout(fd,options.timeout_ms);}catch(...){::close(fd);fd=-1;throw;}
        } else throw std::runtime_error("unsupported XTP listener carrier/layer: "+std::to_string(route.layer)+"/"+route.carrier);
    }
    ~Impl(){if(fd>=0)::close(fd);}
    void close(){if(fd>=0){::close(fd);fd=-1;}}

    ReceiveResult receive(){
        if(fd<0)throw std::runtime_error("XTP listener is closed");
        for(;;){
            std::array<uint8_t,65536>buf{};const uint8_t*payload=nullptr;size_t payload_len=0;std::string peer;
            sockaddr_in peer4{};socklen_t p4len=sizeof(peer4);sockaddr_ll peer2{};socklen_t p2len=sizeof(peer2);
            ssize_t n;
            if(route.layer==2){n=recvfrom(fd,buf.data(),buf.size(),0,reinterpret_cast<sockaddr*>(&peer2),&p2len);}else{n=recvfrom(fd,buf.data(),buf.size(),0,reinterpret_cast<sockaddr*>(&peer4),&p4len);}
            if(n<0){if(errno==EINTR)continue;if(errno==EAGAIN||errno==EWOULDBLOCK)throw std::runtime_error("XTP listener timeout");throw std::runtime_error(std::string("XTP listener recvfrom: ")+std::strerror(errno));}
            if(route.layer==2){if(n<14||buf[12]!=uint8_t(XTP_ETHERTYPE>>8)||buf[13]!=uint8_t(XTP_ETHERTYPE))continue;payload=buf.data()+14;payload_len=size_t(n)-14;peer=mac_text(buf.data()+6);} else if(route.layer==3){auto pp=raw_payload(buf.data(),size_t(n));if(!pp)continue;payload=pp->first;payload_len=pp->second;char a[INET_ADDRSTRLEN]{};inet_ntop(AF_INET,&peer4.sin_addr,a,sizeof(a));peer=a;} else {payload=buf.data();payload_len=size_t(n);char a[INET_ADDRSTRLEN]{};inet_ntop(AF_INET,&peer4.sin_addr,a,sizeof(a));peer=std::string(a)+":"+std::to_string(ntohs(peer4.sin_port));}
            auto f=parse_first(payload,payload_len);if(!f)continue;
            uint32_t received=uint32_t(f->seq+f->data.size());uint32_t alloc=received+options.receive_window;auto ack=control_packet(f->key,received,alloc,f->little,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes);
            if(route.layer==2){std::array<uint8_t,6>dst{};std::copy(buf.begin()+6,buf.begin()+12,dst.begin());std::vector<uint8_t>fr(14+ack.size());std::copy(dst.begin(),dst.end(),fr.begin());std::copy(local_mac.begin(),local_mac.end(),fr.begin()+6);fr[12]=uint8_t(XTP_ETHERTYPE>>8);fr[13]=uint8_t(XTP_ETHERTYPE);std::copy(ack.begin(),ack.end(),fr.begin()+14);sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(ifindex);out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);if(sendto(fd,fr.data(),fr.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("XTP L2 acknowledgement: ")+std::strerror(errno));}
            else {if(sendto(fd,ack.data(),ack.size(),0,reinterpret_cast<sockaddr*>(&peer4),p4len)<0)throw std::runtime_error(std::string("XTP acknowledgement: ")+std::strerror(errno));}
            bool replay=!delivered.insert(f->key).second;
            ReceiveResult result;result.route=route;result.key=f->key;result.sequence=f->seq;result.little_endian=f->little;result.replay=replay;result.peer_address=peer;result.wire_bytes=f->data.size();
            if(!replay){
                result.logical=WireFilterChain::decode_envelope(f->data,nullptr,options.max_logical_bytes);
                if(qualification_payload_p(result.logical)) continue;
            }
            return result;
        }
    }
};

Listener::Listener(const Route&r,const ListenOptions&o):impl_(std::make_unique<Impl>(r,o)){}
Listener::~Listener()=default;
Listener::Listener(Listener&&) noexcept=default;
Listener& Listener::operator=(Listener&&) noexcept=default;
ReceiveResult Listener::receive(){return impl_->receive();}
const Route& Listener::route() const{return impl_->route;}
void Listener::close(){if(impl_)impl_->close();}

struct MulticastListener::Impl {
    struct StreamState{uint32_t expected=0;bool little=false;bool noerr=false;bool complete=false;std::vector<uint8_t> wire;};
    struct DeferredFrame{
        std::vector<uint8_t> bytes;
        sockaddr_in peer4{};
        sockaddr_ll peer2{};
        socklen_t p4len=sizeof(sockaddr_in);
        socklen_t p2len=sizeof(sockaddr_ll);
    };
    Route route; ListenOptions options; int fd=-1; std::set<uint32_t> delivered;
    std::map<uint32_t,StreamState> streams;
    std::deque<DeferredFrame> deferred;
    MulticastListenerStats listener_stats;
    std::array<uint8_t,6> local_mac{}; unsigned ifindex=0;

    Impl(const Route&r,const ListenOptions&o):route(r),options(o){
        if(!route.multicast) throw std::runtime_error("XTP multicast listener requires route.multicast");
        if(route.layer==4 && route.carrier=="udp"){
            auto e=ep(route.destination); auto group=ipaddr(e.host,e.port); if(!ipv4_multicast(group))throw std::runtime_error("L4 multicast listener requires IPv4 multicast group");
            fd=socket(AF_INET,SOCK_DGRAM,0); if(fd<0)throw std::runtime_error(std::string("UDP multicast listener socket: ")+std::strerror(errno));
            try{int one=1;setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));
#ifdef SO_REUSEPORT
                setsockopt(fd,SOL_SOCKET,SO_REUSEPORT,&one,sizeof(one));
#endif
                auto any=ipaddr("0.0.0.0",e.port);if(bind(fd,reinterpret_cast<sockaddr*>(&any),sizeof(any))<0)throw std::runtime_error(std::string("UDP multicast listener bind: ")+std::strerror(errno));join_ipv4_group(fd,e.host,route.interface_name);set_timeout(fd,options.timeout_ms);
            }catch(...){::close(fd);fd=-1;throw;}
        } else if(route.layer==3 && route.carrier=="raw36"){
            auto group=ipaddr(route.destination); if(!ipv4_multicast(group))throw std::runtime_error("L3 multicast listener requires IPv4 multicast group");
            fd=socket(AF_INET,SOCK_RAW,36);if(fd<0)throw std::runtime_error(std::string("raw36 multicast listener socket: ")+std::strerror(errno));
            try{if(!route.interface_name.empty()){ifreq ifr{};std::strncpy(ifr.ifr_name,route.interface_name.c_str(),IFNAMSIZ-1);if(setsockopt(fd,SOL_SOCKET,SO_BINDTODEVICE,&ifr,sizeof(ifr))<0)throw std::runtime_error(std::string("SO_BINDTODEVICE: ")+std::strerror(errno));}join_ipv4_group(fd,route.destination,route.interface_name);set_timeout(fd,options.timeout_ms);}catch(...){::close(fd);fd=-1;throw;}
        } else if(route.layer==2 && route.carrier=="l2"){
            if(route.interface_name.empty()) throw std::runtime_error("L2 multicast listener route has no interface");
            ifindex=if_nametoindex(route.interface_name.c_str());
            if(!ifindex) throw std::runtime_error("unknown L2 interface: "+route.interface_name);
            auto group=mac(route.destination);if(!mac_multicast(group))throw std::runtime_error("L2 multicast listener requires multicast MAC");
            fd=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));if(fd<0)throw std::runtime_error(std::string("AF_PACKET multicast listener socket: ")+std::strerror(errno));
            try{sockaddr_ll a{};a.sll_family=AF_PACKET;a.sll_protocol=htons(XTP_ETHERTYPE);a.sll_ifindex=int(ifindex);if(bind(fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("AF_PACKET multicast bind: ")+std::strerror(errno));packet_mreq mr{};mr.mr_ifindex=int(ifindex);mr.mr_type=PACKET_MR_MULTICAST;mr.mr_alen=6;std::copy(group.begin(),group.end(),mr.mr_address);if(setsockopt(fd,SOL_PACKET,PACKET_ADD_MEMBERSHIP,&mr,sizeof(mr))<0)throw std::runtime_error(std::string("PACKET_ADD_MEMBERSHIP: ")+std::strerror(errno));local_mac=iface_mac(fd,route.interface_name);set_timeout(fd,options.timeout_ms);}catch(...){::close(fd);fd=-1;throw;}
        } else throw std::runtime_error("unsupported XTP multicast listener carrier/layer");
    }
    ~Impl(){if(fd>=0)::close(fd);} void close(){if(fd>=0){::close(fd);fd=-1;}}

    void send_control(const std::vector<uint8_t>&ack,const sockaddr_in&peer4,socklen_t p4len,const uint8_t*ethernet){
        if(route.layer==2){std::array<uint8_t,6>dst{};std::copy(ethernet+6,ethernet+12,dst.begin());std::vector<uint8_t>fr(14+ack.size());std::copy(dst.begin(),dst.end(),fr.begin());std::copy(local_mac.begin(),local_mac.end(),fr.begin()+6);fr[12]=uint8_t(XTP_ETHERTYPE>>8);fr[13]=uint8_t(XTP_ETHERTYPE);std::copy(ack.begin(),ack.end(),fr.begin()+14);sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(ifindex);out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);if(sendto(fd,fr.data(),fr.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("XTP L2 multicast control: ")+std::strerror(errno));}
        else if(sendto(fd,ack.data(),ack.size(),0,reinterpret_cast<const sockaddr*>(&peer4),p4len)<0)throw std::runtime_error(std::string("XTP multicast control: ")+std::strerror(errno));
    }

    void send_group_control(const std::vector<uint8_t>&ctl){
        if(route.layer==2){
            auto dst=mac(route.destination);std::vector<uint8_t>fr(14+ctl.size());std::copy(dst.begin(),dst.end(),fr.begin());std::copy(local_mac.begin(),local_mac.end(),fr.begin()+6);fr[12]=uint8_t(XTP_ETHERTYPE>>8);fr[13]=uint8_t(XTP_ETHERTYPE);std::copy(ctl.begin(),ctl.end(),fr.begin()+14);
            sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(ifindex);out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);
            if(sendto(fd,fr.data(),fr.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("XTP L2 multicast reject notice: ")+std::strerror(errno));
        } else if(route.layer==3){
            auto out=ipaddr(route.destination);if(sendto(fd,ctl.data(),ctl.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("XTP raw36 multicast reject notice: ")+std::strerror(errno));
        } else {
            auto e=ep(route.destination);auto out=ipaddr(e.host,e.port);if(sendto(fd,ctl.data(),ctl.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("XTP UDP multicast reject notice: ")+std::strerror(errno));
        }
    }

    DeferredFrame recv_frame(){
        if(!deferred.empty()){auto f=std::move(deferred.front());deferred.pop_front();return f;}
        DeferredFrame f;f.bytes.resize(65536);
        ssize_t n=(route.layer==2)?recvfrom(fd,f.bytes.data(),f.bytes.size(),0,reinterpret_cast<sockaddr*>(&f.peer2),&f.p2len):recvfrom(fd,f.bytes.data(),f.bytes.size(),0,reinterpret_cast<sockaddr*>(&f.peer4),&f.p4len);
        if(n<0){if(errno==EINTR)return recv_frame();if(errno==EAGAIN||errno==EWOULDBLOCK)throw std::runtime_error("XTP multicast listener timeout");throw std::runtime_error(std::string("XTP multicast listener recvfrom: ")+std::strerror(errno));}
        f.bytes.resize(size_t(n));return f;
    }

    std::optional<Cntl> control_from(const DeferredFrame&f) const{
        const uint8_t*payload=nullptr;size_t payload_len=0;
        if(route.layer==2){if(f.bytes.size()<14||f.bytes[12]!=uint8_t(XTP_ETHERTYPE>>8)||f.bytes[13]!=uint8_t(XTP_ETHERTYPE))return std::nullopt;payload=f.bytes.data()+14;payload_len=f.bytes.size()-14;}
        else if(route.layer==3){auto pp=raw_payload(f.bytes.data(),f.bytes.size());if(!pp)return std::nullopt;payload=pp->first;payload_len=pp->second;}
        else {payload=f.bytes.data();payload_len=f.bytes.size();}
        return parse_cntl(payload,payload_len);
    }

    bool wait_for_covering_reject(uint32_t key,uint32_t own_rseq){
        if(options.reject_suppression_ms<=0)return false;
        using clock=std::chrono::steady_clock;const auto deadline=clock::now()+std::chrono::milliseconds(options.reject_suppression_ms);
        while(clock::now()<deadline){
            int remain=int(std::chrono::duration_cast<std::chrono::milliseconds>(deadline-clock::now()).count());if(remain<1)remain=1;
            pollfd pfd{fd,POLLIN,0};int pr=poll(&pfd,1,remain);if(pr<0){if(errno==EINTR)continue;throw std::runtime_error(std::string("XTP multicast reject suppression poll: ")+std::strerror(errno));}if(pr==0)return false;
            DeferredFrame f;f.bytes.resize(65536);ssize_t n=(route.layer==2)?recvfrom(fd,f.bytes.data(),f.bytes.size(),0,reinterpret_cast<sockaddr*>(&f.peer2),&f.p2len):recvfrom(fd,f.bytes.data(),f.bytes.size(),0,reinterpret_cast<sockaddr*>(&f.peer4),&f.p4len);
            if(n<0){if(errno==EINTR||errno==EAGAIN||errno==EWOULDBLOCK)continue;throw std::runtime_error(std::string("XTP multicast reject suppression recvfrom: ")+std::strerror(errno));}f.bytes.resize(size_t(n));
            auto q=control_from(f);
            if(q&&(q->key&0x7fffffffU)==(key&0x7fffffffU)&&q->flags==0&&multicast_reject_covers(own_rseq,q->rseq)){
                listener_stats.reject_notices_suppressed++;std::fprintf(stderr,"XTP_MULTICAST_REJECT_SUPPRESSED key=%u own_rseq=%u observed_rseq=%u\n",key,own_rseq,q->rseq);return true;
            }
            deferred.push_back(std::move(f));
        }
        return false;
    }

    ReceiveResult receive(){
        if(fd<0)throw std::runtime_error("XTP multicast listener is closed");
        for(;;){
            auto frame=recv_frame();const uint8_t*payload=nullptr;size_t payload_len=0;std::string peer;
            auto&peer4=frame.peer4;auto p4len=frame.p4len;
            if(route.layer==2){if(frame.bytes.size()<14||frame.bytes[12]!=uint8_t(XTP_ETHERTYPE>>8)||frame.bytes[13]!=uint8_t(XTP_ETHERTYPE))continue;payload=frame.bytes.data()+14;payload_len=frame.bytes.size()-14;peer=mac_text(frame.bytes.data()+6);}
            else if(route.layer==3){auto pp=raw_payload(frame.bytes.data(),frame.bytes.size());if(!pp)continue;payload=pp->first;payload_len=pp->second;peer=ip_peer(peer4,false);}
            else{payload=frame.bytes.data();payload_len=frame.bytes.size();peer=ip_peer(peer4,true);}
            // Multicast reject notices are control packets on the group. They
            // exist for peer receiver suppression and are not application data.
            if(parse_cntl(payload,payload_len))continue;
            auto f=parse_payload_packet(payload,payload_len);if(!f||!f->multi)continue;
            auto&st=streams[f->key];
            if(f->first&&f->seq==0&&st.expected==0){st.little=f->little;st.noerr=f->noerr;st.wire.clear();st.complete=false;}
            if(st.complete){if(!f->noerr&&f->status_request){auto ack=control_packet(f->key,st.expected,st.expected+options.receive_window,f->little,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes);send_control(ack,peer4,p4len,frame.bytes.data());}continue;}
            if(f->seq>st.expected){
                if(!f->noerr){auto rej=reject_packet(f->key,st.expected,st.expected+options.receive_window,f->little,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes);if(!wait_for_covering_reject(f->key,st.expected)){send_group_control(rej);listener_stats.reject_notices_sent++;send_control(rej,peer4,p4len,frame.bytes.data());}}
                continue;
            }
            if(f->seq<st.expected){if(!f->noerr&&f->status_request){auto ack=control_packet_ex(f->key,st.expected,st.expected+options.receive_window,f->little,false,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes);send_control(ack,peer4,p4len,frame.bytes.data());}continue;}
            if(st.wire.size()+f->data.size()>options.max_logical_bytes*4u)throw std::runtime_error("XTP multicast encoded stream exceeds receive bound");
            st.wire.insert(st.wire.end(),f->data.begin(),f->data.end());st.expected+=uint32_t(f->data.size());
            if(f->status_request&&!f->noerr){auto ack=control_packet_ex(f->key,st.expected,st.expected+options.receive_window,f->little,f->final_packet,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes);send_control(ack,peer4,p4len,frame.bytes.data());}
            if(!f->final_packet)continue;
            st.complete=true;
            if(!delivered.insert(f->key).second)continue;
            ReceiveResult result;result.route=route;result.key=f->key;result.sequence=0;result.little_endian=f->little;result.replay=false;result.peer_address=peer;result.wire_bytes=st.wire.size();result.logical=WireFilterChain::decode_envelope(st.wire,nullptr,options.max_logical_bytes);return result;
        }
    }
};
MulticastListener::MulticastListener(const Route&r,const ListenOptions&o):impl_(std::make_unique<Impl>(r,o)){}
MulticastListener::~MulticastListener()=default;MulticastListener::MulticastListener(MulticastListener&&) noexcept=default;MulticastListener& MulticastListener::operator=(MulticastListener&&) noexcept=default;
ReceiveResult MulticastListener::receive(){return impl_->receive();}const Route& MulticastListener::route() const{return impl_->route;}MulticastListenerStats MulticastListener::stats() const{return impl_?impl_->listener_stats:MulticastListenerStats{};}void MulticastListener::close(){if(impl_)impl_->close();}

} // namespace xtp
