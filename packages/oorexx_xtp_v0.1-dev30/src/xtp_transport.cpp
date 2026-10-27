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
#include <atomic>
#include <tuple>
#include <random>

namespace xtp {

bool multicast_reject_covers(uint32_t own_rseq,uint32_t observed_rseq){ return own_rseq>=observed_rseq; }

namespace {
constexpr uint8_t XTP_VERSION=3, TYPE_DATA=0x00, TYPE_CNTL=0x01, TYPE_FIRST=0x02;
// dev29: DIAG uses the XTP 4.0 packet type code (8); no verified 3.4 code is held.
constexpr uint8_t TYPE_DIAG=0x08;
constexpr uint8_t OPT_SORT=0x02, OPT_DEADLINE=0x01;
constexpr uint8_t TRAIL_SREQ=0x80, TRAIL_RCLOSE=0x20, TRAIL_WCLOSE=0x10, TRAIL_EOM=0x02, TRAIL_END=0x01, TRAIL_NODCHECK=0x08;
constexpr size_t HEADER=24, TRAILER=16, CONTROL=40;
constexpr uint16_t XTP_ETHERTYPE=0x817D;
constexpr std::array<uint8_t,8> QUAL_MAGIC{{'X','T','P','Q','1',0x00,0x36,0x7d}};

uint32_t next_context_key(){
    static std::atomic<uint32_t> next([]{
        const auto now=std::chrono::steady_clock::now().time_since_epoch().count();
        uint32_t seed=uint32_t(now)^uint32_t(now>>32)^uint32_t(::getpid()*2654435761u);
        seed&=0x7fffffffu; if(seed==0)seed=1; return seed;
    }());
    for(;;){
        uint32_t k=next.fetch_add(1,std::memory_order_relaxed)&0x7fffffffu;
        if(k!=0)return k;
    }
}

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
void pace_send_bytes(size_t bytes,uint64_t bytes_per_sec){
    if(bytes_per_sec==0||bytes==0)return;
    const long double us=(static_cast<long double>(bytes)*1000000.0L)/static_cast<long double>(bytes_per_sec);
    if(us<=0)return;
    std::this_thread::sleep_for(std::chrono::microseconds(static_cast<int64_t>(us)));
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
uint8_t priority_flags(const PrioritySpec&p){if(p.mode==PriorityMode::Disabled)return 0;if(p.mode==PriorityMode::Static)return OPT_SORT;return uint8_t(OPT_SORT|OPT_DEADLINE);}
PrioritySpec parse_priority(const uint8_t*p,bool l){PrioritySpec x;const bool sort=(p[3]&OPT_SORT)!=0,deadline=(p[3]&OPT_DEADLINE)!=0;if(deadline&&!sort)throw std::runtime_error("XTP DEADLINE flag without SORT");if(!sort)return x;x.mode=deadline?PriorityMode::Deadline:PriorityMode::Static;x.sort=get32(p,8,l);return x;}

std::vector<uint8_t> payload_packet(uint8_t type,uint32_t key,uint32_t seq,const std::vector<uint8_t>&data,bool little,bool multi=false,bool noerr=false,bool final_packet=true,bool status_request=true,const PrioritySpec&priority={},uint32_t route_value=0){
    size_t pad=(8-(data.size()%8))%8,body=data.size()+pad;
    std::vector<uint8_t>b(HEADER+body+TRAILER,0);
    b[0]=cmd0(type,little);
    b[3]=uint8_t((little?0x80:0)|(noerr?0x10:0)|(multi?0x08:0)|priority_flags(priority));
    put32(b,4,key&0x7fffffffU,little);
    put32(b,8,priority.mode==PriorityMode::Disabled?0u:priority.sort,little);
    put32(b,16,seq,little);
    put32(b,20,route_value,little);
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

std::vector<uint8_t> first_packet(uint32_t key,const std::vector<uint8_t>&data,bool little,bool multi=false,bool noerr=false,const PrioritySpec&priority={},uint32_t route_value=0,const std::string&service_name={}){
    std::vector<uint8_t> body;
    if(!service_name.empty()){auto sd=encode_named_service(service_name,little);body.reserve(sd.size()+data.size());body.insert(body.end(),sd.begin(),sd.end());body.insert(body.end(),data.begin(),data.end());}
    else body=data;
    return payload_packet(TYPE_FIRST,key,0,body,little,multi,noerr,true,true,priority,route_value);
}


// dev28: SPAN = a received byte range [start,end) beyond RSEQ (XTP 3.4 CNTL
// NSPAN at control-segment offset +36, SPAN pairs after the 40-byte segment).
using Span=std::pair<uint32_t,uint32_t>;
using Clock_tp=std::chrono::steady_clock::time_point;
constexpr uint32_t MAX_SPANS=64;
// dev29: echo = control-segment +16 (ECHO), sync = +20 (SYNC).
struct Cntl{uint32_t key=0,route_value=0,xroute=0,rate=0xffffffffu,burst=0xffffffffu,rseq=0,dseq=0,alloc=0,echo=0,sync=0;uint8_t flags=0;PrioritySpec priority{};std::vector<Span> spans;};
std::optional<Cntl> parse_cntl(const uint8_t*p,size_t n){
    if(n<HEADER+CONTROL+TRAILER||(n%8)!=0) return std::nullopt;
    bool l=(p[0]&0x80)!=0;
    if(((p[3]&0x80)!=0)!=l) return std::nullopt;
    if(((p[0]>>5)&3)!=XTP_VERSION||(p[0]&0x1f)!=TYPE_CNTL) return std::nullopt;
    size_t t=n-TRAILER;std::vector<uint8_t>ht;ht.insert(ht.end(),p,p+HEADER);ht.insert(ht.end(),p+t,p+n);uint32_t given=get32(p,t+12,l);put32(ht,HEADER+12,0,l);if(checksum32(ht.data(),ht.size())!=given)return std::nullopt;if(!(p[t+9]&TRAIL_NODCHECK)&&checksum32(p+HEADER,t-HEADER)!=get32(p,t,l))return std::nullopt;
    Cntl q;q.key=get32(p,4,l);q.route_value=get32(p,20,l);q.rate=get32(p,HEADER+0,l);q.burst=get32(p,HEADER+4,l);q.rseq=get32(p,HEADER+8,l);q.alloc=get32(p,HEADER+12,l);q.xroute=get32(p,HEADER+32,l);q.echo=get32(p,HEADER+16,l);q.sync=get32(p,HEADER+20,l);q.dseq=get32(p,t+4,l);q.flags=p[t+9];
    // dev28: NSPAN.  dev27 and earlier always sent 0 here and never read it.
    // A count that does not fit the packet, or exceeds MAX_SPANS, is malformed.
    const uint32_t nspan=get32(p,HEADER+36,l);
    if(nspan){
        if(nspan>MAX_SPANS||HEADER+CONTROL+size_t(nspan)*8u>t)return std::nullopt;
        for(uint32_t i=0;i<nspan;++i){const uint32_t a=get32(p,HEADER+CONTROL+8*i,l),z=get32(p,HEADER+CONTROL+8*i+4,l);if(z<=a)return std::nullopt;q.spans.emplace_back(a,z);}
    }
    try{q.priority=parse_priority(p,l);}catch(const std::exception&){return std::nullopt;}
    return q;
}

struct PayloadPacket { bool little=false; bool multi=false; bool noerr=false; bool first=false; bool final_packet=false; bool status_request=false; uint32_t key=0,seq=0,route_value=0; PrioritySpec priority{}; std::string service_name; std::vector<uint8_t> data; };
std::optional<PayloadPacket> parse_payload_packet(const uint8_t*p,size_t n){
    if(n<HEADER+TRAILER||(n%8)!=0)return std::nullopt;
    bool l=(p[0]&0x80)!=0;if(((p[3]&0x80)!=0)!=l)return std::nullopt;
    uint8_t type=uint8_t(p[0]&0x1f);
    if(((p[0]>>5)&3)!=XTP_VERSION||(type!=TYPE_FIRST&&type!=TYPE_DATA))return std::nullopt;
    size_t t=n-TRAILER;uint8_t pad=uint8_t(p[t+8]&0x3f);if(pad>t-HEADER)return std::nullopt;
    std::vector<uint8_t>ht;ht.insert(ht.end(),p,p+HEADER);ht.insert(ht.end(),p+t,p+n);uint32_t hgiven=get32(p,t+12,l);put32(ht,HEADER+12,0,l);if(checksum32(ht.data(),ht.size())!=hgiven)return std::nullopt;
    if(!(p[t+9]&TRAIL_NODCHECK)&&checksum32(p+HEADER,t-HEADER)!=get32(p,t,l))return std::nullopt;
    PayloadPacket f;f.little=l;f.multi=(p[3]&0x08)!=0;f.noerr=(p[3]&0x10)!=0;f.first=type==TYPE_FIRST;f.key=get32(p,4,l)&0x7fffffffU;f.seq=get32(p,16,l);f.route_value=get32(p,20,l);f.final_packet=(p[t+9]&TRAIL_EOM)!=0;f.status_request=(p[t+9]&TRAIL_SREQ)!=0;
    // dev26 (E6): a malformed SORT/DEADLINE option or named-service segment is a
    // bad frame, not a listener failure.  Drop it; never throw out of receive().
    try{
        f.priority=parse_priority(p,l);f.data.assign(p+HEADER,p+t-pad);
        if(f.first){NamedServiceDescriptor sd;if(decode_named_service(f.data,l,sd))f.service_name=sd.name;}
    }catch(const std::exception&e){
        std::fprintf(stderr,"XTP_DROP_MALFORMED key=%u reason=%s\n",unsigned(f.key),e.what());
        return std::nullopt;
    }
    return f;
}

using First = PayloadPacket;
[[maybe_unused]] std::optional<First> parse_first(const uint8_t*p,size_t n){auto f=parse_payload_packet(p,n);if(!f||!f->first)return std::nullopt;return f;}

std::vector<uint8_t> control_packet_ex(uint32_t key,uint32_t received,uint32_t alloc,bool little,bool close_context,uint32_t rate=0xffffffffu,uint32_t burst=0xffffffffu,const PrioritySpec&priority={},uint32_t route_value=0,uint32_t xroute=0,const std::vector<Span>&spans={},uint32_t echo=0){
    if(rate==0) throw std::runtime_error("XTP RATE must be positive or 0xffffffff (disabled)");
    if(burst==0) throw std::runtime_error("XTP BURST must be positive");
    const size_t nspan=std::min<size_t>(spans.size(),MAX_SPANS);
    const size_t CTL=CONTROL+nspan*8u;
    std::vector<uint8_t>b(HEADER+CTL+TRAILER,0);b[0]=cmd0(TYPE_CNTL,little);b[3]=uint8_t((little?0x80:0)|priority_flags(priority));put32(b,4,(key&0x7fffffffU)|0x80000000U,little);put32(b,8,priority.mode==PriorityMode::Disabled?0u:priority.sort,little);put32(b,20,route_value,little);
    size_t c=HEADER;put32(b,c+0,rate,little);put32(b,c+4,burst,little);put32(b,c+8,received,little);put32(b,c+12,alloc,little);put32(b,c+16,echo,little);put32(b,c+20,1,little);put32(b,c+28,(key&0x7fffffffU)|0x80000000U,little);put32(b,c+32,xroute,little);put32(b,c+36,uint32_t(nspan),little);
    for(size_t i=0;i<nspan;++i){put32(b,c+CONTROL+8*i,spans[i].first,little);put32(b,c+CONTROL+8*i+4,spans[i].second,little);}
    size_t t=HEADER+CTL;put32(b,t,checksum32(b.data()+HEADER,CTL),little);put32(b,t+4,received,little);b[t+9]=close_context?uint8_t(TRAIL_WCLOSE|TRAIL_RCLOSE|TRAIL_END):0;put16(b,t+10,64,little);
    std::vector<uint8_t>ht;ht.insert(ht.end(),b.begin(),b.begin()+HEADER);ht.insert(ht.end(),b.begin()+t,b.end());put32(ht,HEADER+12,0,little);put32(b,t+12,checksum32(ht.data(),ht.size()),little);return b;
}
std::vector<uint8_t> control_packet(uint32_t key,uint32_t received,uint32_t alloc,bool little,uint32_t rate=0xffffffffu,uint32_t burst=0xffffffffu,const PrioritySpec&priority={},uint32_t route_value=0,uint32_t xroute=0){return control_packet_ex(key,received,alloc,little,true,rate,burst,priority,route_value,xroute);}
// dev29: sender status request.  A CNTL from the sending end (KEY without the
// return bit) carrying SYNC at control +20 and SREQ in the trailer.  A dev29
// receiver answers with its status and ECHO = SYNC; dev28 and earlier ignore it.
std::vector<uint8_t> sync_request_packet(uint32_t key,uint32_t sync,bool little){
    std::vector<uint8_t>b(HEADER+CONTROL+TRAILER,0);b[0]=cmd0(TYPE_CNTL,little);b[3]=uint8_t(little?0x80:0);put32(b,4,key&0x7fffffffU,little);
    size_t c=HEADER;put32(b,c+0,0xffffffffu,little);put32(b,c+4,0xffffffffu,little);put32(b,c+20,sync,little);put32(b,c+28,key&0x7fffffffU,little);
    size_t t=HEADER+CONTROL;put32(b,t,checksum32(b.data()+HEADER,CONTROL),little);b[t+9]=TRAIL_SREQ;put16(b,t+10,64,little);
    std::vector<uint8_t>ht;ht.insert(ht.end(),b.begin(),b.begin()+HEADER);ht.insert(ht.end(),b.begin()+t,b.end());put32(ht,HEADER+12,0,little);put32(b,t+12,checksum32(ht.data(),ht.size()),little);return b;
}
bool is_sync_request(const Cntl&q){return (q.key&0x80000000U)==0&&(q.flags&TRAIL_SREQ)!=0&&q.sync!=0;}

// dev29: DIAG.  Data segment = CODE(4) VALUE(4) then an ASCII reason (the XTP
// 4.0 shape).  Sent by a listener that refuses a context; KEY carries the
// return bit, like any reply.
enum DiagCode:uint32_t{DIAG_CONTEXT_REFUSED=1};
// dev30: VALUEs 16-23 are reserved for refusals by an XTP gateway
// (docs/XTP_GATEWAY_SPEC.md; registry in docs/DIAG_REGISTRY.md).  libxtp
// itself never sends them; it names them so that a sender's error says why.
enum DiagValue:uint32_t{DIAG_SERVICE_NOT_ADMITTED=1,DIAG_OVERSIZE=2,DIAG_MALFORMED=3,
    DIAG_POLICY_DENIED=16,DIAG_AUTH_REQUIRED=17,DIAG_FACILITY_UNSUPPORTED=18,DIAG_QUOTA_EXCEEDED=19,
    DIAG_LOOP_DETECTED=20,DIAG_INSPECTION_DENIED=21,DIAG_NOT_READY=22,DIAG_EMERGENCY_VETO=23};
const char* diag_value_name(uint32_t v){switch(v){
    case DIAG_SERVICE_NOT_ADMITTED:return "SERVICE_NOT_ADMITTED";case DIAG_OVERSIZE:return "OVERSIZE";case DIAG_MALFORMED:return "MALFORMED";
    case DIAG_POLICY_DENIED:return "POLICY_DENIED";case DIAG_AUTH_REQUIRED:return "AUTH_REQUIRED";case DIAG_FACILITY_UNSUPPORTED:return "FACILITY_UNSUPPORTED";
    case DIAG_QUOTA_EXCEEDED:return "QUOTA_EXCEEDED";case DIAG_LOOP_DETECTED:return "LOOP_DETECTED";case DIAG_INSPECTION_DENIED:return "INSPECTION_DENIED";
    case DIAG_NOT_READY:return "NOT_READY";case DIAG_EMERGENCY_VETO:return "EMERGENCY_VETO";default:return "UNKNOWN";}}
std::vector<uint8_t> diag_packet(uint32_t key,uint32_t code,uint32_t value,const std::string&reason,bool little){
    std::vector<uint8_t> d(8,0);put32(d,0,code,little);put32(d,4,value,little);
    const std::string r=reason.substr(0,200);d.insert(d.end(),r.begin(),r.end());
    auto b=payload_packet(TYPE_DIAG,key,0,d,little,false,false,true,false);
    put32(b,4,(key&0x7fffffffU)|0x80000000U,little);
    // re-seal the header/trailer checksum after setting the return bit
    const size_t t=b.size()-TRAILER;std::vector<uint8_t>ht(b.begin(),b.begin()+HEADER);ht.insert(ht.end(),b.begin()+long(t),b.end());put32(ht,HEADER+12,0,little);put32(b,t+12,checksum32(ht.data(),ht.size()),little);
    return b;
}
struct Diag{uint32_t key=0,code=0,value=0;std::string reason;};
std::optional<Diag> parse_diag(const uint8_t*p,size_t n){
    if(n<HEADER+TRAILER+8||(n%8)!=0)return std::nullopt;
    const bool l=(p[0]&0x80)!=0;if(((p[3]&0x80)!=0)!=l)return std::nullopt;
    if(((p[0]>>5)&3)!=XTP_VERSION||(p[0]&0x1f)!=TYPE_DIAG)return std::nullopt;
    const size_t t=n-TRAILER;const uint8_t pad=uint8_t(p[t+8]&0x3f);if(pad>t-HEADER||t-HEADER-pad<8)return std::nullopt;
    std::vector<uint8_t>ht(p,p+HEADER);ht.insert(ht.end(),p+t,p+n);const uint32_t hgiven=get32(p,t+12,l);put32(ht,HEADER+12,0,l);if(checksum32(ht.data(),ht.size())!=hgiven)return std::nullopt;
    if(checksum32(p+HEADER,t-HEADER)!=get32(p,t,l))return std::nullopt;
    Diag d;d.key=get32(p,4,l);d.code=get32(p,HEADER,l);d.value=get32(p,HEADER+4,l);
    for(size_t i=HEADER+8;i<t-pad;++i){const char c=char(p[i]);d.reason.push_back(c>=0x20&&c<0x7f?c:'?');}
    return d;
}
// Throws when a DIAG answers our context: a refused context fails fast.
void raise_if_diag(const uint8_t*p,size_t n,uint32_t key){
    auto d=parse_diag(p,n);
    if(!d||(d->key&0x7fffffffU)!=(key&0x7fffffffU)||(d->key&0x80000000U)==0)return;
    throw std::runtime_error(std::string("XTP context refused by peer: ")+diag_value_name(d->value)+" (code="+std::to_string(d->code)+" value="+std::to_string(d->value)+(d->reason.empty()?"":" reason="+d->reason)+")");
}
std::vector<uint8_t> reject_packet(uint32_t key,uint32_t rseq,uint32_t alloc,bool little,uint32_t rate=0xffffffffu,uint32_t burst=0xffffffffu,const PrioritySpec&priority={},uint32_t route_value=0,uint32_t xroute=0){return control_packet_ex(key,rseq,alloc,little,false,rate,burst,priority,route_value,xroute);}

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

// dev26 (R-07): a close-ACK is accepted only from the route destination.  This
// is source binding, not authentication: it defeats an off-path forger that
// cannot spoof the destination's address, and a forger sending from another
// port on the destination host.  Authenticated ACKs are the gateway's job
// (independent review 2026-10-23, gateway contract step 6).
std::string ip_peer(const sockaddr_in&a,bool port);
bool same_ipv4_endpoint(const sockaddr_in&from,const sockaddr_in&dest,bool match_port){
    if(from.sin_family!=AF_INET||from.sin_addr.s_addr!=dest.sin_addr.s_addr)return false;
    return !match_port||from.sin_port==dest.sin_port;
}
void note_foreign_ack(const char*carrier,const std::string&from){
    std::fprintf(stderr,"XTP_FOREIGN_CONTROL_IGNORED carrier=%s from=%s\n",carrier,from.c_str());
}

SendResult send_udp(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const SendOptions&o){auto e=ep(r.destination);int fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)throw std::runtime_error(std::string("UDP socket: ")+std::strerror(errno));try{set_timeout(fd,o.timeout_ms);auto a=ipaddr(e.host,e.port);auto pkt=first_packet(o.key,wire,o.little_endian,false,false,o.priority,o.route_value,o.service_name);for(int attempt=1;attempt<=o.retries;++attempt){pace_send_bytes(pkt.size(),o.max_rate_bytes_per_sec);if(sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("UDP sendto: ")+std::strerror(errno));std::array<uint8_t,65536>b{};sockaddr_in from{};socklen_t fl=sizeof(from);ssize_t n=recvfrom(fd,b.data(),b.size(),0,reinterpret_cast<sockaddr*>(&from),&fl);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK||errno==EINTR)continue;throw std::runtime_error(std::string("UDP recvfrom: ")+std::strerror(errno));}if(!same_ipv4_endpoint(from,a,true)){note_foreign_ack("udp",ip_peer(from,true));continue;}raise_if_diag(b.data(),size_t(n),o.key);auto q=parse_cntl(b.data(),size_t(n));if(!q||(q->key&0x7fffffffU)!=(o.key&0x7fffffffU)||(q->key&0x80000000U)==0)continue;validate_ack(*q,o.key,wire.size());auto x=base_result(r,logical,wire.size());x.attempts=attempt;x.rseq=q->rseq;x.dseq=q->dseq;x.alloc=q->alloc;x.peer_rate_bytes_per_sec=q->rate;x.peer_burst_bytes=q->burst;x.route_value=o.route_value;x.peer_return_route=q->route_value;x.peer_xroute=q->xroute;close(fd);return x;}throw std::runtime_error("XTP L4 retries exhausted");}catch(...){close(fd);throw;}}
SendResult send_raw36(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const SendOptions&o){int fd=socket(AF_INET,SOCK_RAW,36);if(fd<0)throw std::runtime_error(std::string("raw36 socket: ")+std::strerror(errno));try{set_timeout(fd,o.timeout_ms);if(!r.interface_name.empty()){ifreq ifr{};std::strncpy(ifr.ifr_name,r.interface_name.c_str(),IFNAMSIZ-1);if(setsockopt(fd,SOL_SOCKET,SO_BINDTODEVICE,&ifr,sizeof(ifr))<0)throw std::runtime_error(std::string("SO_BINDTODEVICE: ")+std::strerror(errno));}auto a=ipaddr(r.destination);auto pkt=first_packet(o.key,wire,o.little_endian,false,false,o.priority,o.route_value,o.service_name);for(int attempt=1;attempt<=o.retries;++attempt){pace_send_bytes(pkt.size(),o.max_rate_bytes_per_sec);if(sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("raw36 sendto: ")+std::strerror(errno));for(;;){std::array<uint8_t,65536>b{};sockaddr_in from{};socklen_t fl=sizeof(from);ssize_t n=recvfrom(fd,b.data(),b.size(),0,reinterpret_cast<sockaddr*>(&from),&fl);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK)break;if(errno==EINTR)continue;throw std::runtime_error(std::string("raw36 recvfrom: ")+std::strerror(errno));}if(!same_ipv4_endpoint(from,a,false)){continue;}auto pp=raw_payload(b.data(),size_t(n));if(!pp)continue;raise_if_diag(pp->first,pp->second,o.key);auto q=parse_cntl(pp->first,pp->second);if(!q||(q->key&0x7fffffffU)!=(o.key&0x7fffffffU)||(q->key&0x80000000U)==0)continue;validate_ack(*q,o.key,wire.size());auto x=base_result(r,logical,wire.size());x.attempts=attempt;x.rseq=q->rseq;x.dseq=q->dseq;x.alloc=q->alloc;x.peer_rate_bytes_per_sec=q->rate;x.peer_burst_bytes=q->burst;x.route_value=o.route_value;x.peer_return_route=q->route_value;x.peer_xroute=q->xroute;close(fd);return x;}}throw std::runtime_error("XTP L3 retries exhausted");}catch(...){close(fd);throw;}}
SendResult send_l2(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const SendOptions&o){if(r.interface_name.empty())throw std::runtime_error("L2 route has no interface");unsigned idx=if_nametoindex(r.interface_name.c_str());if(!idx)throw std::runtime_error("unknown L2 interface: "+r.interface_name);int fd=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));if(fd<0)throw std::runtime_error(std::string("AF_PACKET socket: ")+std::strerror(errno));try{sockaddr_ll bindaddr{};bindaddr.sll_family=AF_PACKET;bindaddr.sll_protocol=htons(XTP_ETHERTYPE);bindaddr.sll_ifindex=int(idx);if(bind(fd,reinterpret_cast<sockaddr*>(&bindaddr),sizeof(bindaddr))<0)throw std::runtime_error(std::string("AF_PACKET bind: ")+std::strerror(errno));set_timeout(fd,o.timeout_ms);auto dst=mac(r.destination),src=iface_mac(fd,r.interface_name);auto pkt=first_packet(o.key,wire,o.little_endian,false,false,o.priority,o.route_value,o.service_name);std::vector<uint8_t>frame(14+pkt.size());std::copy(dst.begin(),dst.end(),frame.begin());std::copy(src.begin(),src.end(),frame.begin()+6);frame[12]=uint8_t(XTP_ETHERTYPE>>8);frame[13]=uint8_t(XTP_ETHERTYPE);std::copy(pkt.begin(),pkt.end(),frame.begin()+14);sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(idx);out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);for(int attempt=1;attempt<=o.retries;++attempt){pace_send_bytes(frame.size(),o.max_rate_bytes_per_sec);if(sendto(fd,frame.data(),frame.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("AF_PACKET sendto: ")+std::strerror(errno));for(;;){std::array<uint8_t,65536>b{};ssize_t n=recvfrom(fd,b.data(),b.size(),0,nullptr,nullptr);if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK)break;if(errno==EINTR)continue;throw std::runtime_error(std::string("AF_PACKET recvfrom: ")+std::strerror(errno));}if(n<14||b[12]!=uint8_t(XTP_ETHERTYPE>>8)||b[13]!=uint8_t(XTP_ETHERTYPE))continue;if(!std::equal(src.begin(),src.end(),b.begin())||!std::equal(dst.begin(),dst.end(),b.begin()+6)){if(std::equal(src.begin(),src.end(),b.begin()))note_foreign_ack("l2",mac_text(b.data()+6));continue;}raise_if_diag(b.data()+14,size_t(n)-14,o.key);auto q=parse_cntl(b.data()+14,size_t(n)-14);if(!q||(q->key&0x7fffffffU)!=(o.key&0x7fffffffU)||(q->key&0x80000000U)==0)continue;validate_ack(*q,o.key,wire.size());auto x=base_result(r,logical,wire.size());x.attempts=attempt;x.rseq=q->rseq;x.dseq=q->dseq;x.alloc=q->alloc;x.peer_rate_bytes_per_sec=q->rate;x.peer_burst_bytes=q->burst;x.route_value=o.route_value;x.peer_return_route=q->route_value;x.peer_xroute=q->xroute;close(fd);return x;}}throw std::runtime_error("XTP L2 retries exhausted");}catch(...){close(fd);throw;}}

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
        out.push_back({0,first_packet(o.key,{},o.little_endian,true,!o.reliable,o.priority,0,o.service_name)});
        return out;
    }
    for(size_t pos=0;pos<wire.size();pos+=o.segment_bytes){
        const size_t n=std::min(o.segment_bytes,wire.size()-pos);
        std::vector<uint8_t> chunk(wire.begin()+pos,wire.begin()+pos+n);
        const bool first=pos==0, final_packet=pos+n==wire.size();
        // The final packet solicits receiver status. Earlier gap detection can
        // generate a reject CNTL immediately at the receiver.
        if(first){std::vector<uint8_t> body=chunk;if(!o.service_name.empty()){auto sd=encode_named_service(o.service_name,o.little_endian);body.insert(body.begin(),sd.begin(),sd.end());}out.push_back({uint32_t(pos),payload_packet(TYPE_FIRST,o.key,uint32_t(pos),body,o.little_endian,true,!o.reliable,final_packet,o.reliable||final_packet,o.priority)});}else out.push_back({uint32_t(pos),payload_packet(TYPE_DATA,o.key,uint32_t(pos),chunk,o.little_endian,true,!o.reliable,final_packet,o.reliable||final_packet,o.priority)});
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

// dev27: the go-back-N engine takes a prepared segment list so unicast streams
// (one receiver, MULTI clear) reuse exactly the multicast flow/rate control.
template<class SendFn,class RecvFn>
MulticastSendResult segment_engine(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const MulticastOptions&o,const std::vector<MulticastSegment>&segs,SendFn send_one,RecvFn recv_one,bool reset_on_progress=false){
    // dev27: for unicast streams, retries bound CONSECUTIVE rounds without
    // progress; a transfer that keeps advancing is not killed by a round count.
    uint32_t best_rseq=0;int rounds_before_progress=0;
    auto x=mbase(r,logical,wire.size(),o);x.packets=segs.size();
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
            x.slowest_rseq=uint32_t(wire.size());auto mm=recompute();x.slowest_alloc=mm.alloc;x.slowest_rate_bytes_per_sec=mm.rate;x.slowest_burst_bytes=mm.burst;x.attempts=1+recovery_rounds+rounds_before_progress;return x;
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
        if(reset_on_progress&&min_rseq>best_rseq){best_rseq=min_rseq;rounds_before_progress+=recovery_rounds;recovery_rounds=0;}
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

template<class SendFn,class RecvFn>
MulticastSendResult multicast_engine(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const MulticastOptions&o,SendFn send_one,RecvFn recv_one){
    mvalidate(o);return segment_engine(r,wire,logical,o,multicast_segments(wire,o),send_one,recv_one);
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

// ---------------------------------------------------------------------------
// dev27: unicast FIRST+DATA segmentation.
// ---------------------------------------------------------------------------
size_t iface_mtu(const std::string&ifn){
    if(ifn.empty())return 1500;
    int s=socket(AF_INET,SOCK_DGRAM,0);if(s<0)return 1500;
    ifreq q{};std::strncpy(q.ifr_name,ifn.c_str(),IFNAMSIZ-1);
    size_t mtu=1500;if(ioctl(s,SIOCGIFMTU,&q)==0&&q.ifr_mtu>0)mtu=size_t(q.ifr_mtu);
    ::close(s);return mtu;
}
// Largest data bytes per packet.  L2 has no fragmentation, so it is MTU bound.
// raw36 and UDP default to one maximal IP datagram: everything that worked
// before dev27 (IP fragmentation carried it) keeps the single-FIRST path.
size_t segment_budget(const Route&r,const SendOptions&o){
    size_t seg=0;
    if(o.segment_bytes){if(o.segment_bytes<64)throw std::runtime_error("XTP segment_bytes must be at least 64");seg=o.segment_bytes;}
    else if(r.layer==2)seg=iface_mtu(r.interface_name)>HEADER+TRAILER+64?iface_mtu(r.interface_name)-HEADER-TRAILER:64;
    else if(r.layer==3)seg=65535-20-HEADER-TRAILER;
    else seg=65507-HEADER-TRAILER;
    seg&=~size_t(7);
    if(seg<64)seg=64;
    return seg;
}
std::vector<MulticastSegment> unicast_segments(const std::vector<uint8_t>&wire,const SendOptions&o,size_t seg){
    std::vector<uint8_t> sd;
    if(!o.service_name.empty())sd=encode_named_service(o.service_name,o.little_endian);
    // The named-service segment travels in FIRST, so FIRST carries that much
    // less data and still fits the same packet budget.
    const size_t first_room=seg>sd.size()+64?seg-sd.size():64;
    std::vector<MulticastSegment> out;
    for(size_t pos=0;pos<wire.size();){
        const size_t room=pos==0?first_room:seg;
        const size_t n=std::min(room,wire.size()-pos);
        std::vector<uint8_t> chunk(wire.begin()+long(pos),wire.begin()+long(pos+n));
        const bool final_packet=pos+n==wire.size();
        if(pos==0){chunk.insert(chunk.begin(),sd.begin(),sd.end());out.push_back({0,payload_packet(TYPE_FIRST,o.key,0,chunk,o.little_endian,false,false,final_packet,true,o.priority,o.route_value)});}
        else out.push_back({uint32_t(pos),payload_packet(TYPE_DATA,o.key,uint32_t(pos),chunk,o.little_endian,false,false,final_packet,true,o.priority,o.route_value)});
        pos+=n;
    }
    return out;
}
bool fits_single_first(const std::vector<uint8_t>&wire,const SendOptions&o,size_t seg){
    size_t sd=0;if(!o.service_name.empty())sd=encode_named_service(o.service_name,o.little_endian).size();
    return wire.size()+sd<=seg;
}

// dev28: selective-repeat engine for unicast streams.
//  - New segments go out in order within the receiver's ALLOC (and RATE).
//  - Each CNTL advances RSEQ and marks segments covered by its SPANs.
//  - A sent, unacknowledged segment below the highest SPAN end is a hole; it is
//    resent once 2xSRTT has passed since it was last sent.
//  - A receiver that never reports SPANs (dev27) gets go-back-N after three
//    duplicate CNTLs.
// dev29: SYNC/ECHO (the XTP 3.4 status handshake).
//  - The sender issues status requests (CNTL, SREQ, SYNC) after its first burst,
//    after first sending the final segment, and on every timeout.  SYNC values
//    start at a random base per context.
//  - Once the peer has echoed one, only CNTLs whose ECHO is a SYNC of THIS
//    context are believed; a stale or duplicated CNTL from another context with
//    the same KEY cannot advance or complete the transfer.
//  - The reply to SYNC k reports the receiver's state after every packet sent
//    before k, so any segment sent before k and still not covered is lost and is
//    resent at once (exact tail-loss repair, no timeout needed).
//  - The wait timer is 2 x the SYNC/ECHO round trip (floor 10 ms), doubling on
//    each consecutive timeout (cap 8 x timeout_ms).  A peer that never echoes
//    (dev28 and earlier) keeps the dev28 rules and the fixed timeout_ms.
//  - retries bounds consecutive timeouts without progress.
template<class SendFrame,class RecvCntl>
SendResult selective_engine(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const SendOptions&o,const std::vector<MulticastSegment>&segs,SendFrame send_frame,RecvCntl recv_cntl){
    using Clock=std::chrono::steady_clock;
    struct Seg{uint32_t seq=0,end=0;int sent=0;Clock::time_point last{};bool acked=false;};
    const uint32_t total=uint32_t(wire.size());
    std::vector<Seg> sg(segs.size());
    for(size_t i=0;i<segs.size();++i){sg[i].seq=segs[i].seq;sg[i].end=(i+1<segs.size())?segs[i+1].seq:total;}
    uint32_t rseq=0,alloc=std::max<uint32_t>(65536u,sg.empty()?0u:sg[0].end),high_span=0;
    uint32_t peer_rate=0xffffffffu;
    bool peer_spans=false,peer_echoes=false,final_synced=false;int dup=0,no_progress=0,attempts=1,backoff=0;size_t retransmitted=0,stale=0;
    double srtt_ms=-1,echo_rtt_ms=-1;Cntl last{};
    std::random_device rd;
    const uint32_t sync0=((uint32_t(rd())^uint32_t(Clock::now().time_since_epoch().count()))&0x7fffffffU)|1u;
    uint32_t sync=sync0-1;bool any_sync=false;
    std::map<uint32_t,Clock::time_point> sync_sent;
    const auto t0=Clock::now();uint64_t bytes_out=0;
    auto ms_since=[](Clock::time_point a){return std::chrono::duration<double,std::milli>(Clock::now()-a).count();};
    auto pace=[&](size_t n){
        bytes_out+=n;
        if(peer_rate==0xffffffffu||peer_rate==0)return;
        const double due_ms=double(bytes_out)*1000.0/double(peer_rate);
        const double now_ms=ms_since(t0);
        if(due_ms>now_ms)std::this_thread::sleep_for(std::chrono::microseconds(int64_t((due_ms-now_ms)*1000.0)));
    };
    auto transmit=[&](size_t i,bool re){pace(segs[i].packet.size());send_frame(segs[i].packet);sg[i].sent++;sg[i].last=Clock::now();if(re)retransmitted++;};
    auto send_sync=[&]{
        ++sync;any_sync=true;sync_sent[sync]=Clock::now();
        while(sync_sent.size()>64)sync_sent.erase(sync_sent.begin());
        send_frame(sync_request_packet(o.key,sync,o.little_endian));
    };
    auto in_context=[&](uint32_t e){return any_sync&&e!=0&&uint32_t(e-sync0)<=uint32_t(sync-sync0);};
    auto rtt=[&]{return peer_echoes&&echo_rtt_ms>=0?echo_rtt_ms:srtt_ms;};
    auto hole_rto_ms=[&]{const double r0=rtt();double v=r0<0?double(o.timeout_ms)/4.0:2.0*r0+1.0;return std::min(std::max(v,1.0),double(std::max(1,o.timeout_ms)));};
    auto wtimer_ms=[&]{
        double base=double(o.timeout_ms);
        if(peer_echoes&&echo_rtt_ms>=0)base=std::max(10.0,2.0*echo_rtt_ms);
        for(int b=0;b<backoff;++b)base*=2.0;
        return int(std::max(1.0,std::min(base,8.0*double(std::max(1,o.timeout_ms)))));
    };
    auto mark=[&](uint32_t a,uint32_t z)->bool{
        bool progressed=false;
        for(auto&x:sg){
            if(x.acked||x.seq<a||x.end>z)continue;
            x.acked=true;progressed=true;
            if(x.sent==1){const double sample=ms_since(x.last);srtt_ms=srtt_ms<0?sample:0.875*srtt_ms+0.125*sample;}
        }
        return progressed;
    };
    auto absorb=[&](const Cntl&q){
        // Context binding (dev29).
        std::optional<Clock::time_point> answered;
        if(q.echo!=0){
            if(!in_context(q.echo)){stale++;return;}
            peer_echoes=true;
            auto it=sync_sent.find(q.echo);
            if(it!=sync_sent.end()){
                const double sample=ms_since(it->second);
                echo_rtt_ms=echo_rtt_ms<0?sample:0.875*echo_rtt_ms+0.125*sample;
                answered=it->second;sync_sent.erase(it);
            }
        }else if(peer_echoes){stale++;return;}
        last=q;bool progressed=false;
        if(q.rseq>rseq){rseq=std::min(q.rseq,total);progressed=true;dup=0;}
        progressed|=mark(0,rseq);
        for(const auto&sp:q.spans){peer_spans=true;if(sp.second>high_span)high_span=std::min(sp.second,total);progressed|=mark(sp.first,std::min(sp.second,total));}
        if(q.alloc>alloc)alloc=q.alloc;
        peer_rate=q.rate;
        if(progressed){no_progress=0;backoff=0;}
        else if(q.rseq==rseq&&q.spans.empty())dup++;
        // Exact repair: this status postdates every segment sent before the SYNC.
        if(answered&&!(rseq>=total)){
            for(size_t i=0;i<sg.size();++i){if(sg[i].acked||sg[i].sent==0)continue;if(sg[i].end>alloc)break;if(sg[i].last<*answered)transmit(i,true);}
        }
    };
    auto finished=[&]{return rseq>=total&&(last.flags&(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END))==(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END);};
    auto result=[&]{
        if(stale)std::fprintf(stderr,"XTP_STALE_CONTROL_IGNORED key=%u count=%zu\n",unsigned(o.key&0x7fffffffU),stale);
        auto x=base_result(r,logical,wire.size());x.attempts=attempts;x.rseq=last.rseq;x.dseq=last.dseq;x.alloc=last.alloc;
        x.peer_rate_bytes_per_sec=last.rate;x.peer_burst_bytes=last.burst;x.route_value=o.route_value;x.peer_return_route=last.route_value;x.peer_xroute=last.xroute;
        x.segments=segs.size();x.retransmitted_packets=retransmitted;return x;
    };
    for(;;){
        // 1. selective repeat of holes the receiver has proved missing
        if(peer_spans){
            const double rto=hole_rto_ms();
            for(size_t i=0;i<sg.size();++i){
                if(sg[i].end>high_span)break;
                if(!sg[i].acked&&sg[i].sent>0&&ms_since(sg[i].last)>=rto)transmit(i,true);
            }
        }
        // 1b. go-back-N for a receiver that never reports SPANs
        if(!peer_spans&&dup>=3){
            for(size_t i=0;i<sg.size();++i){if(sg[i].acked||sg[i].sent==0)continue;if(sg[i].end>alloc)break;transmit(i,true);}
            dup=0;attempts++;
        }
        // 2. new data inside ALLOC; status requests after the first burst and the final segment
        bool sent_new=false;
        for(size_t i=0;i<sg.size();++i){if(sg[i].sent)continue;if(sg[i].end>alloc&&i>0)break;transmit(i,false);sent_new=true;}
        if(sent_new&&!any_sync)send_sync();
        if(!final_synced&&!sg.empty()&&sg.back().sent>0){final_synced=true;if(sync_sent.empty()||sg.back().last>sync_sent.rbegin()->second)send_sync();}
        if(finished())return result();
        // 3. wait for status; wake early if a hole will become due
        const int full=wtimer_ms();
        int wait=full;
        if(peer_spans){
            const double rto=hole_rto_ms();
            for(size_t i=0;i<sg.size();++i){if(sg[i].end>high_span)break;if(!sg[i].acked&&sg[i].sent>0){wait=std::max(1,std::min(wait,int(rto-ms_since(sg[i].last))+1));break;}}
        }
        auto q=recv_cntl(wait);
        if(!q){
            if(wait<full)continue;                                   // early wake for a hole, not a timeout
            if(++no_progress>o.retries)throw std::runtime_error("no progress after "+std::to_string(o.retries)+" timeouts");
            attempts++;if(backoff<10)backoff++;
            send_sync();
            if(!peer_echoes){
                // dev28 rule for a peer that does not echo: everything in flight is lost or its CNTL was.
                bool any=false;
                for(size_t i=0;i<sg.size();++i){if(sg[i].acked||sg[i].sent==0)continue;if(sg[i].end>alloc&&any)break;transmit(i,true);any=true;}
                if(!any&&!sg.empty())transmit(sg.size()-1,true);     // all acked but the close was lost: solicit it again
            }
            continue;
        }
        absorb(*q);
        while(auto more=recv_cntl(0))absorb(*more);
    }
}

SendResult stream_send(const Route&r,const std::vector<uint8_t>&wire,size_t logical,const SendOptions&o,size_t seg){
    if(wire.size()>0xffffffffULL)throw std::runtime_error("XTP stream exceeds the 32-bit sequence space");
    const auto segs=unicast_segments(wire,o,seg);
    const char* carrier=r.layer==2?"L2":(r.layer==3?"L3":"L4");
    int fd=-1;
    auto ours=[&](const std::optional<Cntl>&q){return q&&(q->key&0x7fffffffU)==(o.key&0x7fffffffU)&&(q->key&0x80000000U)!=0;};
    // Wait up to wait_ms for one CNTL of this context from the destination.
    auto wait_readable=[&](Clock_tp deadline)->bool{
        for(;;){const auto left=std::chrono::duration_cast<std::chrono::milliseconds>(deadline-std::chrono::steady_clock::now()).count();
            pollfd p{fd,POLLIN,0};const int pr=poll(&p,1,left>0?int(left):0);
            if(pr<0&&errno==EINTR)continue;
            return pr>0;}
    };
    try{
        if(r.layer==4){
            auto e=ep(r.destination);fd=socket(AF_INET,SOCK_DGRAM,0);if(fd<0)throw std::runtime_error(std::string("UDP socket: ")+std::strerror(errno));
            auto a=ipaddr(e.host,e.port);
            auto send_frame=[&](const std::vector<uint8_t>&pkt){pace_send_bytes(pkt.size(),o.max_rate_bytes_per_sec);if(sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("UDP sendto: ")+std::strerror(errno));};
            auto recv_cntl=[&](int wait_ms)->std::optional<Cntl>{const auto dl=std::chrono::steady_clock::now()+std::chrono::milliseconds(wait_ms);
                for(;;){if(!wait_readable(dl))return std::nullopt;std::array<uint8_t,65536>b{};sockaddr_in from{};socklen_t fl=sizeof(from);ssize_t n=recvfrom(fd,b.data(),b.size(),MSG_DONTWAIT,reinterpret_cast<sockaddr*>(&from),&fl);
                    if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK||errno==EINTR)continue;throw std::runtime_error(std::string("UDP recvfrom: ")+std::strerror(errno));}
                    if(!same_ipv4_endpoint(from,a,true)){note_foreign_ack("udp",ip_peer(from,true));continue;}
                    raise_if_diag(b.data(),size_t(n),o.key);
                    auto q=parse_cntl(b.data(),size_t(n));if(ours(q))return q;}};
            auto x=selective_engine(r,wire,logical,o,segs,send_frame,recv_cntl);::close(fd);return x;
        }
        if(r.layer==3){
            fd=socket(AF_INET,SOCK_RAW,36);if(fd<0)throw std::runtime_error(std::string("raw36 socket: ")+std::strerror(errno));
            if(!r.interface_name.empty()){ifreq ifr{};std::strncpy(ifr.ifr_name,r.interface_name.c_str(),IFNAMSIZ-1);if(setsockopt(fd,SOL_SOCKET,SO_BINDTODEVICE,&ifr,sizeof(ifr))<0)throw std::runtime_error(std::string("SO_BINDTODEVICE: ")+std::strerror(errno));}
            auto a=ipaddr(r.destination);
            auto send_frame=[&](const std::vector<uint8_t>&pkt){pace_send_bytes(pkt.size(),o.max_rate_bytes_per_sec);if(sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)throw std::runtime_error(std::string("raw36 sendto: ")+std::strerror(errno));};
            auto recv_cntl=[&](int wait_ms)->std::optional<Cntl>{const auto dl=std::chrono::steady_clock::now()+std::chrono::milliseconds(wait_ms);
                for(;;){if(!wait_readable(dl))return std::nullopt;std::array<uint8_t,65536>b{};sockaddr_in from{};socklen_t fl=sizeof(from);ssize_t n=recvfrom(fd,b.data(),b.size(),MSG_DONTWAIT,reinterpret_cast<sockaddr*>(&from),&fl);
                    if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK||errno==EINTR)continue;throw std::runtime_error(std::string("raw36 recvfrom: ")+std::strerror(errno));}
                    if(!same_ipv4_endpoint(from,a,false))continue;
                    auto pp=raw_payload(b.data(),size_t(n));if(!pp)continue;
                    raise_if_diag(pp->first,pp->second,o.key);
                    auto q=parse_cntl(pp->first,pp->second);if(ours(q))return q;}};
            auto x=selective_engine(r,wire,logical,o,segs,send_frame,recv_cntl);::close(fd);return x;
        }
        if(r.interface_name.empty())throw std::runtime_error("L2 route has no interface");
        unsigned idx=if_nametoindex(r.interface_name.c_str());if(!idx)throw std::runtime_error("unknown L2 interface: "+r.interface_name);
        fd=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));if(fd<0)throw std::runtime_error(std::string("AF_PACKET socket: ")+std::strerror(errno));
        sockaddr_ll ba{};ba.sll_family=AF_PACKET;ba.sll_protocol=htons(XTP_ETHERTYPE);ba.sll_ifindex=int(idx);if(bind(fd,reinterpret_cast<sockaddr*>(&ba),sizeof(ba))<0)throw std::runtime_error(std::string("AF_PACKET bind: ")+std::strerror(errno));
        auto dst=mac(r.destination),src=iface_mac(fd,r.interface_name);
        sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(idx);out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);
        auto send_frame=[&](const std::vector<uint8_t>&pkt){pace_send_bytes(pkt.size()+14,o.max_rate_bytes_per_sec);std::vector<uint8_t>frame(14+pkt.size());std::copy(dst.begin(),dst.end(),frame.begin());std::copy(src.begin(),src.end(),frame.begin()+6);frame[12]=uint8_t(XTP_ETHERTYPE>>8);frame[13]=uint8_t(XTP_ETHERTYPE);std::copy(pkt.begin(),pkt.end(),frame.begin()+14);if(sendto(fd,frame.data(),frame.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("AF_PACKET sendto: ")+std::strerror(errno));};
        auto recv_cntl=[&](int wait_ms)->std::optional<Cntl>{const auto dl=std::chrono::steady_clock::now()+std::chrono::milliseconds(wait_ms);
            for(;;){if(!wait_readable(dl))return std::nullopt;std::array<uint8_t,65536>b{};ssize_t n=recvfrom(fd,b.data(),b.size(),MSG_DONTWAIT,nullptr,nullptr);
                if(n<0){if(errno==EAGAIN||errno==EWOULDBLOCK||errno==EINTR)continue;throw std::runtime_error(std::string("AF_PACKET recvfrom: ")+std::strerror(errno));}
                if(n<14||b[12]!=uint8_t(XTP_ETHERTYPE>>8)||b[13]!=uint8_t(XTP_ETHERTYPE))continue;
                if(!std::equal(src.begin(),src.end(),b.begin())||!std::equal(dst.begin(),dst.end(),b.begin()+6))continue;
                raise_if_diag(b.data()+14,size_t(n)-14,o.key);
                auto q=parse_cntl(b.data()+14,size_t(n)-14);if(ours(q))return q;}};
        auto x=selective_engine(r,wire,logical,o,segs,send_frame,recv_cntl);::close(fd);return x;
    }catch(const std::exception&e){
        if(fd>=0)::close(fd);
        const std::string w=e.what();
        if(w.find("no progress")!=std::string::npos)throw std::runtime_error(std::string("XTP ")+carrier+" stream not acknowledged ("+std::to_string(segs.size())+" segments): "+w);
        throw;
    }
}

} // namespace

SendResult send_message(const Route& route,const std::vector<uint8_t>&logical,const SendOptions&options){
    auto wr=WireFilterChain::parse_spec(route.wire_filters).encode(logical);
    SendOptions effective=options;
    if((effective.key&0x7fffffffu)==0) effective.key=next_context_key();
    const bool known=(route.layer==2&&route.carrier=="l2")||(route.layer==3&&route.carrier=="raw36")||(route.layer==4&&route.carrier=="udp");
    if(known){
        // dev27: a message that fits one segment keeps the dev26 single-FIRST
        // exchange byte for byte; only larger ones become FIRST+DATA streams.
        const size_t seg=segment_budget(route,effective);
        if(!fits_single_first(wr.bytes,effective,seg)) return stream_send(route,wr.bytes,logical.size(),effective,seg);
    }
    if(route.layer==2 && route.carrier=="l2") return send_l2(route,wr.bytes,logical.size(),effective);
    if(route.layer==3 && route.carrier=="raw36") return send_raw36(route,wr.bytes,logical.size(),effective);
    if(route.layer==4 && route.carrier=="udp") return send_udp(route,wr.bytes,logical.size(),effective);
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
    // dev26 (E7): bounded replay window keyed by (peer host, KEY, payload digest).
    // The digest separates a genuine retransmission (identical FIRST data) from
    // a different context whose 31-bit KEY happens to collide, for example two
    // XMP1 multipath chunks of different transfers.  dev25 ACKed and silently
    // dropped the second one.
    using ReplayId=std::tuple<std::string,uint32_t,uint64_t>;
    std::set<ReplayId> delivered;
    std::deque<ReplayId> delivered_order;
    std::array<uint8_t,6> local_mac{};
    unsigned ifindex=0;

    static uint64_t payload_digest(const std::vector<uint8_t>&d){uint64_t h=1469598103934665603ull;for(uint8_t c:d){h^=c;h*=1099511628211ull;}return h;}
    bool seen(const ReplayId&id) const{return delivered.count(id)!=0;}
    void remember(const ReplayId&id){
        if(!delivered.insert(id).second)return;
        delivered_order.push_back(id);
        while(delivered_order.size()>options.replay_window_entries){delivered.erase(delivered_order.front());delivered_order.pop_front();}
    }

    Impl(const Route&r,const ListenOptions&o):route(r),options(o){
        if(options.replay_window_entries==0) throw std::runtime_error("XTP replay_window_entries must be positive");
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
        // dev27: a stream's ALLOC never exceeds what the socket can actually
        // queue, or a full-window burst would overflow it and force go-back.
        int want=int(std::min<uint64_t>(uint64_t(options.receive_window)*2u,uint64_t(64u)*1024u*1024u));
        if(setsockopt(fd,SOL_SOCKET,SO_RCVBUFFORCE,&want,sizeof(want))<0)setsockopt(fd,SOL_SOCKET,SO_RCVBUF,&want,sizeof(want));
        int have=0;socklen_t hl=sizeof(have);
        if(getsockopt(fd,SOL_SOCKET,SO_RCVBUF,&have,&hl)==0&&have>0)stream_window=std::max<uint32_t>(65536u,std::min<uint32_t>(options.receive_window,uint32_t(have)/4u));
        else stream_window=std::min<uint32_t>(options.receive_window,65536u);
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
            std::string peer_host;
            if(route.layer==2){if(n<14||buf[12]!=uint8_t(XTP_ETHERTYPE>>8)||buf[13]!=uint8_t(XTP_ETHERTYPE))continue;
                // dev26 (R-08): a unicast listener accepts only frames addressed to
                // its own MAC.  On a promiscuous bridge it would otherwise ACK and
                // deliver traffic meant for a neighbouring MI.
                if(!std::equal(local_mac.begin(),local_mac.end(),buf.begin())){continue;}
                payload=buf.data()+14;payload_len=size_t(n)-14;peer=mac_text(buf.data()+6);peer_host=peer;} else if(route.layer==3){auto pp=raw_payload(buf.data(),size_t(n));if(!pp)continue;payload=pp->first;payload_len=pp->second;char a[INET_ADDRSTRLEN]{};inet_ntop(AF_INET,&peer4.sin_addr,a,sizeof(a));peer=a;peer_host=peer;} else {payload=buf.data();payload_len=size_t(n);char a[INET_ADDRSTRLEN]{};inet_ntop(AF_INET,&peer4.sin_addr,a,sizeof(a));peer=std::string(a)+":"+std::to_string(ntohs(peer4.sin_port));peer_host=a;}
            trigger_bytes=payload_len;trigger_peer=peer_host;   // dev30: bounds any DIAG this packet causes
            // dev29: a status request (CNTL from the sending end) for a stream.
            if(auto sc=parse_cntl(payload,payload_len)){if(is_sync_request(*sc))answer_sync(*sc,peer_host,buf.data(),peer4,p4len);continue;}
            auto f=parse_payload_packet(payload,payload_len);if(!f)continue;
            if(!(f->first&&f->seq==0&&f->final_packet)){
                // dev27: FIRST without EOM, or DATA: part of a unicast stream.
                auto done=stream_packet(*f,peer,peer_host,buf.data(),peer4,p4len);
                if(done) return std::move(*done);
                continue;
            }
            if(!admitted(*f)){refuse(f->key,f->little,DIAG_SERVICE_NOT_ADMITTED,"named service not admitted: "+f->service_name,buf.data(),peer4,p4len);continue;}
            // dev26 (E6): decode before acknowledging.  A FIRST whose envelope
            // cannot be decoded is dropped unacknowledged, so the sender never
            // records it as delivered.
            const ReplayId replay_id{peer_host,f->key,payload_digest(f->data)};
            const bool replay=seen(replay_id);
            std::vector<uint8_t> logical;
            if(!replay){
                try{logical=WireFilterChain::decode_envelope(f->data,nullptr,options.max_logical_bytes);}
                catch(const std::exception&e){std::fprintf(stderr,"XTP_DROP_MALFORMED key=%u peer=%s reason=%s\n",unsigned(f->key),peer.c_str(),e.what());refuse(f->key,f->little,DIAG_MALFORMED,e.what(),buf.data(),peer4,p4len);continue;}
            }
            uint32_t received=uint32_t(f->seq+f->data.size());uint32_t alloc=received+options.receive_window;uint32_t return_route=f->route_value?((f->route_value&0x7fffffffU)|0x80000000U):0u;auto ack=control_packet(f->key,received,alloc,f->little,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes,f->priority,return_route,options.exchange_route_value);
            send_ctl(ack,buf.data(),peer4,p4len);
            remember(replay_id);
            ReceiveResult result;result.route=route;result.key=f->key;result.sequence=f->seq;result.route_value=f->route_value;result.little_endian=f->little;result.replay=replay;result.priority=f->priority;result.peer_address=peer;result.service_name=f->service_name;result.wire_bytes=f->data.size();
            if(!replay){
                result.logical=std::move(logical);
                if(qualification_payload_p(result.logical)) continue;
            }
            return result;
        }
    }

    bool admitted(const PayloadPacket&f) const{
        if(options.allowed_services.empty())return true;
        if(f.service_name.empty())return false;
        return std::find(options.allowed_services.begin(),options.allowed_services.end(),f.service_name)!=options.allowed_services.end();
    }

    void send_ctl(const std::vector<uint8_t>&ack,const uint8_t*frame,const sockaddr_in&peer4,socklen_t p4len){
        if(route.layer==2){std::array<uint8_t,6>dst{};std::copy(frame+6,frame+12,dst.begin());std::vector<uint8_t>fr(14+ack.size());std::copy(dst.begin(),dst.end(),fr.begin());std::copy(local_mac.begin(),local_mac.end(),fr.begin()+6);fr[12]=uint8_t(XTP_ETHERTYPE>>8);fr[13]=uint8_t(XTP_ETHERTYPE);std::copy(ack.begin(),ack.end(),fr.begin()+14);sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(ifindex);out.sll_halen=6;std::copy(dst.begin(),dst.end(),out.sll_addr);if(sendto(fd,fr.data(),fr.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))<0)throw std::runtime_error(std::string("XTP L2 acknowledgement: ")+std::strerror(errno));}
        else {if(sendto(fd,ack.data(),ack.size(),0,reinterpret_cast<const sockaddr*>(&peer4),p4len)<0)throw std::runtime_error(std::string("XTP acknowledgement: ")+std::strerror(errno));}
    }

    // dev27: unicast stream reassembly, keyed by (peer host, KEY).
    // dev28: out-of-order segments are kept within the window and reported to
    // the sender as SPANs, so only the holes are retransmitted.
    struct Stream{uint32_t expected=0;bool little=true;uint32_t route_value=0;PrioritySpec priority{};std::string service_name,peer;std::vector<uint8_t> wire;
                  uint64_t first_digest=0;std::map<uint32_t,std::vector<uint8_t>> ooo;size_t ooo_bytes=0;bool have_final=false;uint32_t final_end=0;uint32_t last_sync=0;};
    struct Finished{uint32_t length=0;uint64_t first_digest=0;bool little=true;PrioritySpec priority{};uint32_t route_value=0;uint32_t last_sync=0;};
    using StreamId=std::pair<std::string,uint32_t>;
    std::map<StreamId,Stream> streams;
    std::deque<StreamId> stream_order;
    std::map<StreamId,Finished> finished;            // completed stream, to re-ACK a lost final close
    std::deque<StreamId> finished_order;
    static constexpr size_t MAX_OPEN_STREAMS=256;
    uint32_t stream_window=1024u*1024u;              // set from the real receive buffer in the constructor

    static std::vector<Span> spans_of(const Stream&st){
        std::vector<Span> v;
        for(const auto&kv:st.ooo){
            const uint32_t a=kv.first,z=a+uint32_t(kv.second.size());
            if(!v.empty()&&a<=v.back().second){v.back().second=std::max(v.back().second,z);continue;}
            if(v.size()==MAX_SPANS)break;
            v.emplace_back(a,z);
        }
        return v;
    }
    std::vector<uint8_t> stream_ack(uint32_t key,uint32_t received,bool little,const PrioritySpec&priority,uint32_t route_value,bool close_context,const std::vector<Span>&spans={},uint32_t echo=0){
        const uint32_t return_route=route_value?((route_value&0x7fffffffU)|0x80000000U):0u;
        return control_packet_ex(key,received,received+stream_window,little,close_context,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes,priority,return_route,options.exchange_route_value,spans,echo);
    }
    void status(const PayloadPacket&f,const Stream&st,const uint8_t*frame,const sockaddr_in&peer4,socklen_t p4len){
        send_ctl(stream_ack(f.key,st.expected,st.little,st.priority,st.route_value,false,spans_of(st),st.last_sync),frame,peer4,p4len);
    }
    void reclose(const PayloadPacket&f,const Finished&fin,const uint8_t*frame,const sockaddr_in&peer4,socklen_t p4len){
        if(f.status_request)send_ctl(stream_ack(f.key,fin.length,fin.little,fin.priority,fin.route_value,true,{},fin.last_sync),frame,peer4,p4len);
    }
    // dev29: answer a sender's status request; the reply echoes its SYNC.
    void answer_sync(const Cntl&q,const std::string&peer_host,const uint8_t*frame,const sockaddr_in&peer4,socklen_t p4len){
        const StreamId id{peer_host,q.key&0x7fffffffU};
        auto it=streams.find(id);
        if(it!=streams.end()){Stream&st=it->second;st.last_sync=q.sync;send_ctl(stream_ack(id.second,st.expected,st.little,st.priority,st.route_value,false,spans_of(st),st.last_sync),frame,peer4,p4len);return;}
        auto fin=finished.find(id);
        if(fin!=finished.end()){fin->second.last_sync=q.sync;send_ctl(stream_ack(id.second,fin->second.length,fin->second.little,fin->second.priority,fin->second.route_value,true,{},q.sync),frame,peer4,p4len);}
    }
    // dev29: tell the sender why its context was refused, instead of silence.
    // dev30: the source of a refused packet is unauthenticated, and on UDP it
    // can be forged, so a DIAG must not be usable as a reflector:
    //  - the reason on the wire is only the VALUE name.  The detail (the
    //    requested service name, a parser message) stays in the local log;
    //    dev29 echoed both to whoever asked.
    //  - a DIAG is never larger than the packet that caused it.  If the
    //    named reason does not fit it is dropped; if even a bare DIAG does
    //    not fit, none is sent.
    //  - DIAGs are rate limited per peer host and in total (token buckets,
    //    ListenOptions::diag_*).  A refused peer that is over its limit gets
    //    silence, exactly as from dev28.
    void refuse(uint32_t key,bool little,uint32_t value,const std::string&detail,const uint8_t*frame,const sockaddr_in&peer4,socklen_t p4len){
        auto pkt=diag_packet(key,DIAG_CONTEXT_REFUSED,value,diag_value_name(value),little);
        if(pkt.size()>trigger_bytes)pkt=diag_packet(key,DIAG_CONTEXT_REFUSED,value,std::string(),little);
        const char*why=nullptr;
        if(pkt.size()>trigger_bytes)why="size";
        else if(!diag_allowed(trigger_peer))why="rate";
        if(why){
            ++diag_suppressed;
            std::fprintf(stderr,"XTP_DIAG_SUPPRESSED key=%u peer=%s reason=%s detail=%s cause=%s\n",unsigned(key),trigger_peer.c_str(),diag_value_name(value),detail.c_str(),why);
            return;
        }
        ++diag_sent;
        std::fprintf(stderr,"XTP_DIAG_SENT key=%u peer=%s reason=%s detail=%s\n",unsigned(key),trigger_peer.c_str(),diag_value_name(value),detail.c_str());
        send_ctl(pkt,frame,peer4,p4len);
    }
    struct DiagBucket{double tokens=0;Clock_tp at{};};
    std::map<std::string,DiagBucket> diag_buckets;
    DiagBucket diag_global;
    bool diag_global_ready=false;
    size_t trigger_bytes=0;std::string trigger_peer;
    size_t diag_sent=0,diag_suppressed=0;
    static void refill(DiagBucket&b,double rate,double burst,Clock_tp now){
        b.tokens=std::min(burst,b.tokens+rate*std::chrono::duration<double>(now-b.at).count());b.at=now;
    }
    bool diag_allowed(const std::string&peer){
        if(options.diag_rate_per_sec==0||options.diag_global_rate_per_sec==0)return false;
        const auto now=std::chrono::steady_clock::now();
        const double rate=options.diag_rate_per_sec,burst=std::max<double>(1.0,options.diag_burst);
        const double grate=options.diag_global_rate_per_sec,gburst=2.0*grate;
        if(!diag_global_ready){diag_global={gburst,now};diag_global_ready=true;}
        refill(diag_global,grate,gburst,now);
        auto it=diag_buckets.find(peer);
        if(it==diag_buckets.end()){
            if(diag_buckets.size()>=MAX_DIAG_PEERS){
                // forget peers whose bucket has refilled: they are idle
                for(auto j=diag_buckets.begin();j!=diag_buckets.end();){refill(j->second,rate,burst,now);if(j->second.tokens>=burst)j=diag_buckets.erase(j);else ++j;}
                if(diag_buckets.size()>=MAX_DIAG_PEERS)return false;   // too many active refused peers: fail quiet
            }
            it=diag_buckets.emplace(peer,DiagBucket{burst,now}).first;
        }
        refill(it->second,rate,burst,now);
        if(it->second.tokens<1.0||diag_global.tokens<1.0)return false;
        it->second.tokens-=1.0;diag_global.tokens-=1.0;
        return true;
    }
    static constexpr size_t MAX_DIAG_PEERS=4096;
    void drop_stream(const StreamId&id){streams.erase(id);}
    void mark_finished(const StreamId&id,const Finished&fin){
        if(finished.count(id)==0)finished_order.push_back(id);
        finished[id]=fin;
        while(finished_order.size()>options.replay_window_entries){finished.erase(finished_order.front());finished_order.pop_front();}
    }
    bool too_big(const Stream&st,size_t more,const PayloadPacket&f,const std::string&peer){
        if(st.wire.size()+more<=options.max_logical_bytes*4u+65536u)return false;
        std::fprintf(stderr,"XTP_DROP_OVERSIZE key=%u peer=%s bytes=%zu\n",unsigned(f.key),peer.c_str(),st.wire.size()+more);
        return true;
    }

    std::optional<ReceiveResult> stream_packet(PayloadPacket&f,const std::string&peer,const std::string&peer_host,const uint8_t*frame,const sockaddr_in&peer4,socklen_t p4len){
        const StreamId id{peer_host,f.key};
        const uint32_t s0=f.seq,len=uint32_t(f.data.size()),e0=s0+len;
        if(e0<s0)return std::nullopt;                                 // sequence wrap: malformed
        if(f.first&&f.seq==0){
            if(!admitted(f)){refuse(f.key,f.little,DIAG_SERVICE_NOT_ADMITTED,"named service not admitted: "+f.service_name,frame,peer4,p4len);return std::nullopt;}
            const uint64_t fd=payload_digest(f.data);
            // dev28: a FIRST identical to one already seen is a retransmission
            // (its CNTL was lost): it must not reset progress, and after
            // completion it only re-sends the close.  A different FIRST with
            // the same (peer, KEY) is a new context.
            auto fin=finished.find(id);
            if(fin!=finished.end()&&fin->second.first_digest==fd){reclose(f,fin->second,frame,peer4,p4len);return std::nullopt;}
            auto ex=streams.find(id);
            if(ex==streams.end()||ex->second.first_digest!=fd){
                finished.erase(id);
                Stream st;st.little=f.little;st.route_value=f.route_value;st.priority=f.priority;st.service_name=f.service_name;st.peer=peer;st.first_digest=fd;
                if(ex==streams.end())stream_order.push_back(id);
                streams[id]=std::move(st);
                while(streams.size()>MAX_OPEN_STREAMS&&!stream_order.empty()){streams.erase(stream_order.front());stream_order.pop_front();}
                while(!stream_order.empty()&&streams.count(stream_order.front())==0)stream_order.pop_front();
            }
        }
        auto it=streams.find(id);
        if(it==streams.end()){
            // DATA for a stream already completed: the sender lost our close-ACK.
            auto fin=finished.find(id);
            if(fin!=finished.end())reclose(f,fin->second,frame,peer4,p4len);
            return std::nullopt;   // otherwise an unknown context: drop
        }
        Stream&st=it->second;
        if(f.little!=st.little)return std::nullopt;
        if(f.final_packet){st.have_final=true;st.final_end=e0;}
        if(e0<=st.expected){if(f.status_request)status(f,st,frame,peer4,p4len);return std::nullopt;}     // duplicate
        if(s0>st.expected){
            // Out of order: keep it if it lies inside the advertised window.
            if(e0<=st.expected+stream_window&&st.ooo.count(s0)==0&&st.ooo_bytes+len<=stream_window){st.ooo.emplace(s0,f.data);st.ooo_bytes+=len;}
            status(f,st,frame,peer4,p4len);                           // gap report with SPANs
            return std::nullopt;
        }
        // In order (possibly overlapping what we have): take the new tail.
        if(too_big(st,e0-st.expected,f,peer)){refuse(f.key,st.little,DIAG_OVERSIZE,"stream exceeds the listener bound",frame,peer4,p4len);drop_stream(id);return std::nullopt;}
        st.wire.insert(st.wire.end(),f.data.begin()+long(st.expected-s0),f.data.end());st.expected=e0;
        while(!st.ooo.empty()){
            auto b=st.ooo.begin();const uint32_t a=b->first,z=a+uint32_t(b->second.size());
            if(a>st.expected)break;
            if(z>st.expected){
                if(too_big(st,z-st.expected,f,peer)){refuse(f.key,st.little,DIAG_OVERSIZE,"stream exceeds the listener bound",frame,peer4,p4len);drop_stream(id);return std::nullopt;}
                st.wire.insert(st.wire.end(),b->second.begin()+long(st.expected-a),b->second.end());st.expected=z;
            }
            st.ooo_bytes-=b->second.size();st.ooo.erase(b);
        }
        if(!(st.have_final&&st.expected>=st.final_end)){if(f.status_request)status(f,st,frame,peer4,p4len);return std::nullopt;}
        // Complete: decode before the close-ACK (dev26 E6 rule).
        const ReplayId rid{peer_host,f.key,payload_digest(st.wire)};
        const bool replay=seen(rid);
        std::vector<uint8_t> logical;
        if(!replay){
            try{logical=WireFilterChain::decode_envelope(st.wire,nullptr,options.max_logical_bytes);}
            catch(const std::exception&e){std::fprintf(stderr,"XTP_DROP_MALFORMED key=%u peer=%s reason=%s\n",unsigned(f.key),peer.c_str(),e.what());refuse(f.key,st.little,DIAG_MALFORMED,e.what(),frame,peer4,p4len);drop_stream(id);return std::nullopt;}
        }
        send_ctl(stream_ack(f.key,st.expected,st.little,st.priority,st.route_value,true,{},st.last_sync),frame,peer4,p4len);
        Finished fin;fin.length=st.expected;fin.first_digest=st.first_digest;fin.little=st.little;fin.priority=st.priority;fin.route_value=st.route_value;fin.last_sync=st.last_sync;
        remember(rid);mark_finished(id,fin);
        ReceiveResult result;result.route=route;result.key=f.key;result.sequence=0;result.route_value=st.route_value;result.little_endian=st.little;result.replay=replay;result.priority=st.priority;result.peer_address=st.peer;result.service_name=st.service_name;result.wire_bytes=st.wire.size();
        drop_stream(id);
        if(replay)return result;
        result.logical=std::move(logical);
        if(qualification_payload_p(result.logical))return std::nullopt;
        return result;
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
            if(st.complete){if(!f->noerr&&f->status_request){auto ack=control_packet(f->key,st.expected,st.expected+options.receive_window,f->little,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes,f->priority);send_control(ack,peer4,p4len,frame.bytes.data());}continue;}
            if(f->seq>st.expected){
                if(!f->noerr){auto rej=reject_packet(f->key,st.expected,st.expected+options.receive_window,f->little,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes,f->priority);if(!wait_for_covering_reject(f->key,st.expected)){send_group_control(rej);listener_stats.reject_notices_sent++;send_control(rej,peer4,p4len,frame.bytes.data());}}
                continue;
            }
            if(f->seq<st.expected){if(!f->noerr&&f->status_request){auto ack=control_packet_ex(f->key,st.expected,st.expected+options.receive_window,f->little,false,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes,f->priority);send_control(ack,peer4,p4len,frame.bytes.data());}continue;}
            if(st.wire.size()+f->data.size()>options.max_logical_bytes*4u)throw std::runtime_error("XTP multicast encoded stream exceeds receive bound");
            st.wire.insert(st.wire.end(),f->data.begin(),f->data.end());st.expected+=uint32_t(f->data.size());
            if(f->status_request&&!f->noerr){auto ack=control_packet_ex(f->key,st.expected,st.expected+options.receive_window,f->little,f->final_packet,options.advertised_rate_bytes_per_sec,options.advertised_burst_bytes,f->priority);send_control(ack,peer4,p4len,frame.bytes.data());}
            if(!f->final_packet)continue;
            st.complete=true;
            if(!delivered.insert(f->key).second)continue;
            ReceiveResult result;result.route=route;result.key=f->key;result.sequence=0;result.little_endian=f->little;result.replay=false;result.priority=f->priority;result.peer_address=peer;result.wire_bytes=st.wire.size();result.logical=WireFilterChain::decode_envelope(st.wire,nullptr,options.max_logical_bytes);return result;
        }
    }
};
MulticastListener::MulticastListener(const Route&r,const ListenOptions&o):impl_(std::make_unique<Impl>(r,o)){}
MulticastListener::~MulticastListener()=default;MulticastListener::MulticastListener(MulticastListener&&) noexcept=default;MulticastListener& MulticastListener::operator=(MulticastListener&&) noexcept=default;
ReceiveResult MulticastListener::receive(){return impl_->receive();}const Route& MulticastListener::route() const{return impl_->route;}MulticastListenerStats MulticastListener::stats() const{return impl_?impl_->listener_stats:MulticastListenerStats{};}void MulticastListener::close(){if(impl_)impl_->close();}

} // namespace xtp
