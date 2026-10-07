#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#include <array>
#include <cerrno>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <map>
#include <optional>
#include <random>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include "xtp/xtp_wire.hpp"

namespace {
constexpr uint8_t XTP_VERSION = 3;
constexpr uint8_t TYPE_DATA = 0x00;
constexpr uint8_t TYPE_CNTL = 0x01;
constexpr uint8_t TYPE_FIRST = 0x02;
constexpr uint8_t OPT_LITTLE = 0x80;
constexpr uint8_t OPT_NOCHECK = 0x40;
constexpr uint8_t TRAIL_SREQ = 0x80;
constexpr uint8_t TRAIL_DREQ = 0x40;
constexpr uint8_t TRAIL_RCLOSE = 0x20;
constexpr uint8_t TRAIL_WCLOSE = 0x10;
constexpr uint8_t TRAIL_NODCHECK = 0x08;
constexpr uint8_t TRAIL_ETAG = 0x04;
constexpr uint8_t TRAIL_EOM = 0x02;
constexpr uint8_t TRAIL_END = 0x01;
constexpr size_t HEADER = 24;
constexpr size_t TRAILER = 16;
constexpr size_t CONTROL = 40; // rate..nspan, no SPAN groups

uint16_t rol16(uint16_t v) { return uint16_t((v << 1) | (v >> 15)); }

struct Checksum { uint16_t x = 0; uint16_t rx = 0; };
Checksum xtp_checksum(const uint8_t* p, size_t n) {
    Checksum c{};
    for (size_t i = 0; i < n; i += 2) {
        uint16_t w = uint16_t(p[i]) << 8;
        if (i + 1 < n) w |= p[i + 1];
        c.x ^= w;
        c.rx = rol16(c.rx);
        c.rx ^= w;
    }
    return c;
}
uint32_t checksum32(const uint8_t* p, size_t n) {
    auto c = xtp_checksum(p, n);
    return (uint32_t(c.x) << 16) | c.rx;
}

void put32(std::vector<uint8_t>& b, size_t o, uint32_t v, bool little) {
    if (little) {
        b[o]=uint8_t(v); b[o+1]=uint8_t(v>>8); b[o+2]=uint8_t(v>>16); b[o+3]=uint8_t(v>>24);
    } else {
        b[o]=uint8_t(v>>24); b[o+1]=uint8_t(v>>16); b[o+2]=uint8_t(v>>8); b[o+3]=uint8_t(v);
    }
}
void put16(std::vector<uint8_t>& b, size_t o, uint16_t v, bool little) {
    if (little) { b[o]=uint8_t(v); b[o+1]=uint8_t(v>>8); }
    else { b[o]=uint8_t(v>>8); b[o+1]=uint8_t(v); }
}
uint32_t get32(const uint8_t* b, size_t o, bool little) {
    if (little) return uint32_t(b[o]) | (uint32_t(b[o+1])<<8) | (uint32_t(b[o+2])<<16) | (uint32_t(b[o+3])<<24);
    return (uint32_t(b[o])<<24) | (uint32_t(b[o+1])<<16) | (uint32_t(b[o+2])<<8) | uint32_t(b[o+3]);
}
uint16_t get16(const uint8_t* b, size_t o, bool little) {
    if (little) return uint16_t(b[o]) | uint16_t(uint16_t(b[o+1])<<8);
    return uint16_t(uint16_t(b[o])<<8) | uint16_t(b[o+1]);
}

bool host_little() { uint16_t x=1; return *reinterpret_cast<uint8_t*>(&x)==1; }

uint8_t cmd0(uint8_t type, bool little) {
    return uint8_t((little ? 0x80 : 0x00) | ((XTP_VERSION & 0x03) << 5) | (type & 0x1f));
}

struct Parsed {
    bool little = false;
    uint8_t type = 0;
    uint32_t key = 0;
    uint32_t seq = 0;
    uint32_t route = 0;
    uint32_t dseq = 0;
    uint8_t flags = 0;
    uint16_t ttl = 0;
    std::vector<uint8_t> data;
    uint32_t rate = 0, burst = 0, rseq = 0, alloc = 0, xkey = 0, xroute = 0, nspan = 0;
};

std::vector<uint8_t> build_info(uint8_t type, uint32_t key, uint32_t seq,
                                const std::vector<uint8_t>& data, uint8_t trailer_flags,
                                bool little, uint32_t route=0, uint32_t dseq=0) {
    size_t pad = (8 - (data.size() % 8)) % 8;
    size_t body = data.size() + pad;
    std::vector<uint8_t> b(HEADER + body + TRAILER, 0);
    b[0] = cmd0(type, little);
    b[1] = 0; // OFFSET
    b[2] = 0;
    b[3] = little ? OPT_LITTLE : 0;
    put32(b,4,key,little); put32(b,8,0,little); put32(b,12,0,little);
    put32(b,16,seq,little); put32(b,20,route,little);
    std::copy(data.begin(),data.end(),b.begin()+HEADER);
    size_t t = HEADER + body;
    put32(b,t,checksum32(b.data()+HEADER, body),little);
    put32(b,t+4,dseq,little);
    b[t+8] = uint8_t(pad & 0x3f);
    b[t+9] = trailer_flags;
    put16(b,t+10,64,little);
    // HTCHECK calculated over header + trailer with field zero.
    std::vector<uint8_t> ht;
    ht.insert(ht.end(), b.begin(), b.begin()+HEADER);
    ht.insert(ht.end(), b.begin()+t, b.end());
    put32(ht, HEADER+12, 0, little);
    put32(b,t+12,checksum32(ht.data(),ht.size()),little);
    return b;
}

std::vector<uint8_t> build_cntl(uint32_t key, uint32_t seq, uint32_t received,
                                uint32_t alloc, uint8_t trailer_flags, bool little,
                                uint32_t xkey=0) {
    std::vector<uint8_t> b(HEADER + CONTROL + TRAILER, 0);
    b[0]=cmd0(TYPE_CNTL,little); b[3]=little?OPT_LITTLE:0;
    put32(b,4,key,little); put32(b,16,seq,little);
    size_t c=HEADER;
    put32(b,c+0,1000000000u,little); // RATE
    put32(b,c+4,65536u,little);      // BURST
    put32(b,c+8,received,little);    // RSEQ
    put32(b,c+12,alloc,little);      // ALLOC
    put32(b,c+16,0,little);          // ECHO
    put32(b,c+20,1,little);          // SYNC
    put32(b,c+24,0,little);          // TIME
    put32(b,c+28,xkey,little);       // XKEY
    put32(b,c+32,0,little);          // XROUTE
    put32(b,c+36,0,little);          // NSPAN
    size_t t=HEADER+CONTROL;
    put32(b,t,checksum32(b.data()+HEADER,CONTROL),little);
    put32(b,t+4,received,little); // DSEQ
    b[t+8]=0; b[t+9]=trailer_flags; put16(b,t+10,64,little);
    std::vector<uint8_t> ht;
    ht.insert(ht.end(),b.begin(),b.begin()+HEADER);
    ht.insert(ht.end(),b.begin()+t,b.end());
    put32(ht,HEADER+12,0,little);
    put32(b,t+12,checksum32(ht.data(),ht.size()),little);
    return b;
}

std::optional<Parsed> parse(const uint8_t* p, size_t n, std::string& why) {
    if (n < HEADER+TRAILER || (n % 8)!=0) { why="bad length/alignment"; return std::nullopt; }
    bool little = (p[0] & 0x80)!=0;
    bool little2 = (p[3] & 0x80)!=0;
    if (little != little2) { why="LITTLE markers disagree"; return std::nullopt; }
    uint8_t version = uint8_t((p[0]>>5)&0x03);
    if (version != XTP_VERSION) { why="unsupported XTP version"; return std::nullopt; }
    uint8_t type = uint8_t(p[0]&0x1f);
    size_t control_len = (type==TYPE_CNTL) ? CONTROL : 0;
    if (n < HEADER+control_len+TRAILER) { why="truncated packet"; return std::nullopt; }
    size_t t=n-TRAILER;
    uint8_t align = uint8_t(p[t+8]&0x3f);
    if (type != TYPE_CNTL && align > n-HEADER-TRAILER) { why="bad align"; return std::nullopt; }
    // Header/trailer checksum
    std::vector<uint8_t> ht;
    ht.insert(ht.end(),p,p+HEADER);
    ht.insert(ht.end(),p+t,p+n);
    uint32_t given_ht=get32(p,t+12,little);
    put32(ht,HEADER+12,0,little);
    if (checksum32(ht.data(),ht.size())!=given_ht) { why="HTCHECK mismatch"; return std::nullopt; }
    size_t body_len = t-HEADER;
    uint32_t given_d=get32(p,t,little);
    if (!(p[t+9] & TRAIL_NODCHECK) && checksum32(p+HEADER,body_len)!=given_d) { why="DCHECK mismatch"; return std::nullopt; }
    Parsed q{}; q.little=little; q.type=type; q.key=get32(p,4,little); q.seq=get32(p,16,little); q.route=get32(p,20,little);
    q.dseq=get32(p,t+4,little); q.flags=p[t+9]; q.ttl=get16(p,t+10,little);
    if (type==TYPE_CNTL) {
        size_t c=HEADER;
        q.rate=get32(p,c+0,little); q.burst=get32(p,c+4,little); q.rseq=get32(p,c+8,little); q.alloc=get32(p,c+12,little);
        q.xkey=get32(p,c+28,little); q.xroute=get32(p,c+32,little); q.nspan=get32(p,c+36,little);
        if(q.nspan!=0){ why="SPAN subset not implemented"; return std::nullopt; }
    } else {
        size_t payload_len=body_len-align;
        q.data.assign(p+HEADER,p+HEADER+payload_len);
    }
    return q;
}

struct Endpoint { std::string host; uint16_t port; };
Endpoint ep(const std::string& s) {
    auto k=s.rfind(':'); if(k==std::string::npos) throw std::runtime_error("endpoint must host:port");
    return {s.substr(0,k),uint16_t(std::stoul(s.substr(k+1)))};
}
sockaddr_in addr(const Endpoint& e){ sockaddr_in a{}; a.sin_family=AF_INET; a.sin_port=htons(e.port); if(inet_pton(AF_INET,e.host.c_str(),&a.sin_addr)!=1) throw std::runtime_error("IPv4 only in dev2"); return a; }
sockaddr_in ipaddr(const std::string& host){ sockaddr_in a{}; a.sin_family=AF_INET; if(inet_pton(AF_INET,host.c_str(),&a.sin_addr)!=1) throw std::runtime_error("IPv4 only in dev2"); return a; }

std::optional<std::pair<const uint8_t*,size_t>> raw36_payload(const uint8_t* p,size_t n,std::string& why){
    if(n<20){why="short IPv4 raw packet";return std::nullopt;}
    uint8_t ver=uint8_t(p[0]>>4), ihl=uint8_t((p[0]&0x0f)*4);
    if(ver!=4 || ihl<20 || n<ihl){why="bad IPv4 header";return std::nullopt;}
    if(p[9]!=36){why="not protocol 36";return std::nullopt;}
    return std::make_pair(p+ihl,n-ihl);
}

int raw36_socket(const std::optional<std::string>& bind_ip){
    int fd=socket(AF_INET,SOCK_RAW,36); if(fd<0) return -1;
    if(bind_ip){ auto a=ipaddr(*bind_ip); if(bind(fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0){int e=errno;close(fd);errno=e;return -1;} }
    return fd;
}

std::array<uint8_t,6> parse_mac(const std::string& s){
    std::array<uint8_t,6> m{}; unsigned v[6];
    if(std::sscanf(s.c_str(),"%x:%x:%x:%x:%x:%x",&v[0],&v[1],&v[2],&v[3],&v[4],&v[5])!=6) throw std::runtime_error("bad MAC address");
    for(size_t i=0;i<6;i++){if(v[i]>255)throw std::runtime_error("bad MAC address");m[i]=uint8_t(v[i]);} return m;
}
std::string mac_text(const uint8_t* m){ char b[32]; std::snprintf(b,sizeof(b),"%02x:%02x:%02x:%02x:%02x:%02x",m[0],m[1],m[2],m[3],m[4],m[5]); return b; }
std::array<uint8_t,6> iface_mac(int fd,const std::string& ifn){
    ifreq r{}; std::strncpy(r.ifr_name,ifn.c_str(),IFNAMSIZ-1); if(ioctl(fd,SIOCGIFHWADDR,&r)<0) throw std::runtime_error(std::string("SIOCGIFHWADDR: ")+std::strerror(errno));
    std::array<uint8_t,6> m{}; std::memcpy(m.data(),r.ifr_hwaddr.sa_data,6); return m;
}
constexpr uint16_t XTP_ETHERTYPE=0x817D; // Assigned XTP EtherType.
int packet_socket(const std::string& ifn){
    int fd=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE)); if(fd<0)return -1;
    unsigned idx=if_nametoindex(ifn.c_str()); if(!idx){int e=errno?errno:ENODEV;close(fd);errno=e;return -1;}
    sockaddr_ll ll{};ll.sll_family=AF_PACKET;ll.sll_protocol=htons(XTP_ETHERTYPE);ll.sll_ifindex=int(idx);
    if(bind(fd,reinterpret_cast<sockaddr*>(&ll),sizeof(ll))<0){int e=errno;close(fd);errno=e;return -1;} return fd;
}
std::vector<uint8_t> eth_frame(const std::array<uint8_t,6>& dst,const std::array<uint8_t,6>& src,const std::vector<uint8_t>& xtp){
    std::vector<uint8_t>b(14+xtp.size());std::copy(dst.begin(),dst.end(),b.begin());std::copy(src.begin(),src.end(),b.begin()+6);b[12]=uint8_t(XTP_ETHERTYPE>>8);b[13]=uint8_t(XTP_ETHERTYPE);std::copy(xtp.begin(),xtp.end(),b.begin()+14);return b;
}

int udp_server(const Endpoint& bind_ep, int max_deliveries) {
    int fd=socket(AF_INET,SOCK_DGRAM,0); if(fd<0){perror("socket"); return 2;}
    auto a=addr(bind_ep); if(bind(fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0){perror("bind"); return 2;}
    std::map<uint32_t,std::vector<uint8_t>> delivered;
    std::cerr << "XTP_SERVER_READY udp " << bind_ep.host << ':' << bind_ep.port << "\n";
    int fresh=0;
    while(max_deliveries<=0 || fresh<max_deliveries){
        std::array<uint8_t,65536> buf{}; sockaddr_in peer{}; socklen_t pl=sizeof(peer);
        ssize_t n=recvfrom(fd,buf.data(),buf.size(),0,reinterpret_cast<sockaddr*>(&peer),&pl); if(n<0){ if(errno==EINTR)continue; perror("recvfrom"); return 2; }
        std::string why; auto q=parse(buf.data(),size_t(n),why);
        if(!q){ std::cerr<<"XTP_REJECT "<<why<<"\n"; continue; }
        if(q->type!=TYPE_FIRST){ continue; }
        uint32_t basekey=q->key & 0x7fffffffU; bool replay=delivered.count(basekey)!=0; auto appdata=xtp::WireFilterChain::decode_envelope(q->data);
        if(!replay){ delivered.emplace(basekey,appdata); fresh++; std::cout<<"DELIVER carrier=udp key="<<basekey<<" bytes="<<appdata.size()<<" wire_bytes="<<q->data.size()<<" data="<<std::string(appdata.begin(),appdata.end())<<"\n"; std::cout.flush(); }
        else std::cerr<<"XTP_REPLAY_SUPPRESSED key="<<basekey<<"\n";
        uint32_t recv=uint32_t(q->seq+q->data.size()); auto c=build_cntl(basekey|0x80000000U,0,recv,recv+1024*1024,TRAIL_WCLOSE|TRAIL_RCLOSE|TRAIL_END,q->little,basekey|0x80000000U);
        sendto(fd,c.data(),c.size(),0,reinterpret_cast<sockaddr*>(&peer),pl);
    } close(fd); return 0;
}

int raw36_server(const std::string& bind_ip,int max_deliveries){
    int fd=raw36_socket(bind_ip); if(fd<0){perror("raw36 socket/bind");return 4;}
    std::map<uint32_t,std::vector<uint8_t>> delivered; std::cerr<<"XTP_SERVER_READY raw36 "<<bind_ip<<" protocol=36\n"; int fresh=0;
    while(max_deliveries<=0||fresh<max_deliveries){
        std::array<uint8_t,65536>buf{};sockaddr_in peer{};socklen_t pl=sizeof(peer);ssize_t n=recvfrom(fd,buf.data(),buf.size(),0,reinterpret_cast<sockaddr*>(&peer),&pl);if(n<0){if(errno==EINTR)continue;perror("raw36 recvfrom");return 2;}
        std::string why;auto pp=raw36_payload(buf.data(),size_t(n),why);if(!pp)continue;auto q=parse(pp->first,pp->second,why);if(!q){std::cerr<<"XTP_REJECT "<<why<<"\n";continue;}if(q->type!=TYPE_FIRST)continue;
        uint32_t basekey=q->key&0x7fffffffU;bool replay=delivered.count(basekey)!=0;auto appdata=xtp::WireFilterChain::decode_envelope(q->data);if(!replay){delivered.emplace(basekey,appdata);fresh++;char ip[INET_ADDRSTRLEN];inet_ntop(AF_INET,&peer.sin_addr,ip,sizeof(ip));std::cout<<"DELIVER carrier=raw36 from="<<ip<<" key="<<basekey<<" bytes="<<appdata.size()<<" wire_bytes="<<q->data.size()<<" data="<<std::string(appdata.begin(),appdata.end())<<"\n";std::cout.flush();}else std::cerr<<"XTP_REPLAY_SUPPRESSED key="<<basekey<<"\n";
        uint32_t recv=uint32_t(q->seq+q->data.size());auto c=build_cntl(basekey|0x80000000U,0,recv,recv+1024*1024,TRAIL_WCLOSE|TRAIL_RCLOSE|TRAIL_END,q->little,basekey|0x80000000U);if(sendto(fd,c.data(),c.size(),0,reinterpret_cast<sockaddr*>(&peer),pl)<0)perror("raw36 sendto");
    }close(fd);return 0;
}

int l2_server(const std::string& ifn,int max_deliveries){
    int fd=packet_socket(ifn);if(fd<0){perror("packet socket/bind");return 4;}auto my=iface_mac(fd,ifn);std::map<uint32_t,std::vector<uint8_t>>delivered;std::cerr<<"XTP_SERVER_READY l2 iface="<<ifn<<" mac="<<mac_text(my.data())<<" ethertype=0x817d\n";int fresh=0;
    while(max_deliveries<=0||fresh<max_deliveries){std::array<uint8_t,65536>buf{};sockaddr_ll peer{};socklen_t pl=sizeof(peer);ssize_t n=recvfrom(fd,buf.data(),buf.size(),0,reinterpret_cast<sockaddr*>(&peer),&pl);if(n<14){if(n<0&&errno==EINTR)continue;if(n<0)perror("packet recvfrom");continue;}if(buf[12]!=uint8_t(XTP_ETHERTYPE>>8)||buf[13]!=uint8_t(XTP_ETHERTYPE))continue;std::string why;auto q=parse(buf.data()+14,size_t(n)-14,why);if(!q){std::cerr<<"XTP_REJECT "<<why<<"\n";continue;}if(q->type!=TYPE_FIRST)continue;
        uint32_t basekey=q->key&0x7fffffffU;bool replay=delivered.count(basekey)!=0;auto appdata=xtp::WireFilterChain::decode_envelope(q->data);if(!replay){delivered.emplace(basekey,appdata);fresh++;std::cout<<"DELIVER carrier=l2 from="<<mac_text(buf.data()+6)<<" key="<<basekey<<" bytes="<<appdata.size()<<" wire_bytes="<<q->data.size()<<" data="<<std::string(appdata.begin(),appdata.end())<<"\n";std::cout.flush();}else std::cerr<<"XTP_REPLAY_SUPPRESSED key="<<basekey<<"\n";
        uint32_t recv=uint32_t(q->seq+q->data.size());auto c=build_cntl(basekey|0x80000000U,0,recv,recv+1024*1024,TRAIL_WCLOSE|TRAIL_RCLOSE|TRAIL_END,q->little,basekey|0x80000000U);std::array<uint8_t,6>dst{};std::copy(buf.begin()+6,buf.begin()+12,dst.begin());auto fr=eth_frame(dst,my,c);sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(if_nametoindex(ifn.c_str()));out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);if(sendto(fd,fr.data(),fr.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)perror("packet sendto");
    }close(fd);return 0;
}

int udp_client(const Endpoint& dst, const std::string& msg, int timeout_ms, int retries, uint32_t key, bool little, const std::string& filter_spec) {
    int fd=socket(AF_INET,SOCK_DGRAM,0); if(fd<0){perror("socket"); return 2;} timeval tv{timeout_ms/1000,(timeout_ms%1000)*1000}; setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv)); auto a=addr(dst);
    std::vector<uint8_t> logical(msg.begin(),msg.end()); auto wr=xtp::WireFilterChain::parse_spec(filter_spec).encode(logical); auto data=wr.bytes; auto first=build_info(TYPE_FIRST,key&0x7fffffffU,0,data,TRAIL_SREQ|TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_EOM,little);
    for(int attempt=1;attempt<=retries;attempt++){if(sendto(fd,first.data(),first.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0){perror("sendto");return 2;}std::array<uint8_t,65536>buf{};ssize_t n=recvfrom(fd,buf.data(),buf.size(),0,nullptr,nullptr);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK){std::cerr<<"XTP_TIMEOUT attempt="<<attempt<<"\n";continue;}perror("recvfrom");return 2;}std::string why;auto q=parse(buf.data(),size_t(n),why);if(!q||q->type!=TYPE_CNTL||(q->key&0x7fffffffU)!=(key&0x7fffffffU))continue;if((q->flags&(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END))!=(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END)||q->rseq<data.size()||q->dseq<data.size())continue;std::cout<<"XTP_OK carrier=udp key="<<(key&0x7fffffffU)<<" attempts="<<attempt<<" bytes="<<logical.size()<<" wire_bytes="<<data.size()<<" rseq="<<q->rseq<<" dseq="<<q->dseq<<" alloc="<<q->alloc<<" rate="<<q->rate<<" burst="<<q->burst<<" endian="<<(little?"little":"big")<<"\n";close(fd);return 0;}std::cerr<<"XTP_FAILED retries_exhausted\n";close(fd);return 3;
}

int raw36_client(const std::string& dst,const std::optional<std::string>& from,const std::string& msg,int timeout_ms,int retries,uint32_t key,bool little,const std::string& filter_spec){
    int fd=raw36_socket(from);if(fd<0){perror("raw36 socket/bind");return 4;}timeval tv{timeout_ms/1000,(timeout_ms%1000)*1000};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));auto a=ipaddr(dst);std::vector<uint8_t>logical(msg.begin(),msg.end());auto wr=xtp::WireFilterChain::parse_spec(filter_spec).encode(logical);auto data=wr.bytes;auto first=build_info(TYPE_FIRST,key&0x7fffffffU,0,data,TRAIL_SREQ|TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_EOM,little);
    for(int attempt=1;attempt<=retries;attempt++){if(sendto(fd,first.data(),first.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0){perror("raw36 sendto");return 2;}for(;;){std::array<uint8_t,65536>buf{};sockaddr_in peer{};socklen_t pl=sizeof(peer);ssize_t n=recvfrom(fd,buf.data(),buf.size(),0,reinterpret_cast<sockaddr*>(&peer),&pl);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK){std::cerr<<"XTP_TIMEOUT attempt="<<attempt<<"\n";break;}if(errno==EINTR)continue;perror("raw36 recvfrom");return 2;}std::string why;auto pp=raw36_payload(buf.data(),size_t(n),why);if(!pp)continue;auto q=parse(pp->first,pp->second,why);if(!q||q->type!=TYPE_CNTL||(q->key&0x7fffffffU)!=(key&0x7fffffffU))continue;if((q->flags&(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END))!=(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END)||q->rseq<data.size()||q->dseq<data.size())continue;std::cout<<"XTP_OK carrier=raw36 key="<<(key&0x7fffffffU)<<" attempts="<<attempt<<" bytes="<<logical.size()<<" wire_bytes="<<data.size()<<" rseq="<<q->rseq<<" dseq="<<q->dseq<<" alloc="<<q->alloc<<" endian="<<(little?"little":"big")<<"\n";close(fd);return 0;}}
    std::cerr<<"XTP_FAILED retries_exhausted\n";close(fd);return 3;
}

int l2_client(const std::string& ifn,const std::string& dstmac,const std::string& msg,int timeout_ms,int retries,uint32_t key,bool little,const std::string& filter_spec){
    int fd=packet_socket(ifn);if(fd<0){perror("packet socket/bind");return 4;}timeval tv{timeout_ms/1000,(timeout_ms%1000)*1000};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof(tv));auto src=iface_mac(fd,ifn),dst=parse_mac(dstmac);std::vector<uint8_t>logical(msg.begin(),msg.end());auto wr=xtp::WireFilterChain::parse_spec(filter_spec).encode(logical);auto data=wr.bytes;auto first=build_info(TYPE_FIRST,key&0x7fffffffU,0,data,TRAIL_SREQ|TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_EOM,little);auto fr=eth_frame(dst,src,first);sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(if_nametoindex(ifn.c_str()));out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);
    for(int attempt=1;attempt<=retries;attempt++){if(sendto(fd,fr.data(),fr.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0){perror("packet sendto");return 2;}for(;;){std::array<uint8_t,65536>buf{};ssize_t n=recvfrom(fd,buf.data(),buf.size(),0,nullptr,nullptr);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK){std::cerr<<"XTP_TIMEOUT attempt="<<attempt<<"\n";break;}if(errno==EINTR)continue;perror("packet recvfrom");return 2;}if(n<14||buf[12]!=uint8_t(XTP_ETHERTYPE>>8)||buf[13]!=uint8_t(XTP_ETHERTYPE))continue;std::string why;auto q=parse(buf.data()+14,size_t(n)-14,why);if(!q||q->type!=TYPE_CNTL||(q->key&0x7fffffffU)!=(key&0x7fffffffU))continue;std::cout<<"XTP_OK carrier=l2 key="<<(key&0x7fffffffU)<<" attempts="<<attempt<<" bytes="<<logical.size()<<" wire_bytes="<<data.size()<<" endian="<<(little?"little":"big")<<"\n";close(fd);return 0;}}
    std::cerr<<"XTP_FAILED retries_exhausted\n";close(fd);return 3;
}

int probe(){
    int fd=socket(AF_INET,SOCK_RAW,36);if(fd<0){std::cout<<"RAW36 unavailable errno="<<errno<<" "<<std::strerror(errno)<<"\n";}else{std::cout<<"RAW36 available\n";close(fd);}int p=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));if(p<0){std::cout<<"L2_RAW unavailable errno="<<errno<<" "<<std::strerror(errno)<<"\n";}else{std::cout<<"L2_RAW available\n";close(p);}return 0;
}

void usage(){
 std::cerr<<"usage:\n"
          <<"  xtp-local probe\n"
          <<"  xtp-local server --carrier udp --bind HOST:PORT [--max N]\n"
          <<"  xtp-local client --carrier udp --to HOST:PORT --message TEXT [...]\n"
          <<"  xtp-local server --carrier raw36 --bind IP [--max N]\n"
          <<"  xtp-local client --carrier raw36 --to IP [--from IP] --message TEXT [...]\n"
          <<"  xtp-local server --carrier l2 --interface IFACE [--max N]\n"
          <<"  xtp-local client --carrier l2 --interface IFACE --to-mac MAC --message TEXT [...]\n";
}
}

int main(int argc,char**argv){
 try{
  if(argc<2){usage();return 2;} std::string mode=argv[1]; if(mode=="probe")return probe();
  std::map<std::string,std::string> o; for(int i=2;i<argc;i++){std::string k=argv[i]; if(k.rfind("--",0)!=0||i+1>=argc){usage();return 2;} o[k]=argv[++i];}
  std::string carrier=o.count("--carrier")?o["--carrier"]:"udp";int max=o.count("--max")?std::stoi(o["--max"]):0;
  if(mode=="server"){
    if(carrier=="udp"){if(!o.count("--bind")){usage();return 2;}return udp_server(ep(o["--bind"]),max);}
    if(carrier=="raw36"){if(!o.count("--bind")){usage();return 2;}return raw36_server(o["--bind"],max);}
    if(carrier=="l2"){if(!o.count("--interface")){usage();return 2;}return l2_server(o["--interface"],max);}
  }
  if(mode=="client"){
    if(!o.count("--message")){usage();return 2;}int timeout=o.count("--timeout-ms")?std::stoi(o["--timeout-ms"]):250;int retries=o.count("--retries")?std::stoi(o["--retries"]):12;uint32_t key=o.count("--key")?uint32_t(std::stoul(o["--key"])):0x1234567u;bool little=o.count("--endian")?o["--endian"]!="big":host_little();std::string filters=o.count("--filters")?o["--filters"]:"none";
    if(carrier=="udp"){if(!o.count("--to")){usage();return 2;}return udp_client(ep(o["--to"]),o["--message"],timeout,retries,key,little,filters);}
    if(carrier=="raw36"){if(!o.count("--to")){usage();return 2;}std::optional<std::string> from;if(o.count("--from"))from=o["--from"];return raw36_client(o["--to"],from,o["--message"],timeout,retries,key,little,filters);}
    if(carrier=="l2"){if(!o.count("--interface")||!o.count("--to-mac")){usage();return 2;}return l2_client(o["--interface"],o["--to-mac"],o["--message"],timeout,retries,key,little,filters);}
  }
  usage();return 2;
 }catch(const std::exception&e){std::cerr<<"error: "<<e.what()<<"\n";return 2;}
}
