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
#include <unordered_map>
#include <unordered_set>
#include <random>
#include <mutex>
#include <condition_variable>
#include "xtp/xtp_session.hpp"
#include "xtp/xtp_security.hpp"
#include <openssl/crypto.h>

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

// dev31: return_bit, trailer (all trailer flags) and service_flags are for interactive contexts.
struct PayloadPacket { bool little=false; bool multi=false; bool noerr=false; bool first=false; bool final_packet=false; bool status_request=false; bool return_bit=false; uint8_t trailer=0; uint8_t service_flags=0; uint32_t key=0,seq=0,route_value=0; PrioritySpec priority{}; std::string service_name; std::vector<uint8_t> data; };
std::optional<PayloadPacket> parse_payload_packet(const uint8_t*p,size_t n){
    if(n<HEADER+TRAILER||(n%8)!=0)return std::nullopt;
    bool l=(p[0]&0x80)!=0;if(((p[3]&0x80)!=0)!=l)return std::nullopt;
    uint8_t type=uint8_t(p[0]&0x1f);
    if(((p[0]>>5)&3)!=XTP_VERSION||(type!=TYPE_FIRST&&type!=TYPE_DATA))return std::nullopt;
    size_t t=n-TRAILER;uint8_t pad=uint8_t(p[t+8]&0x3f);if(pad>t-HEADER)return std::nullopt;
    std::vector<uint8_t>ht;ht.insert(ht.end(),p,p+HEADER);ht.insert(ht.end(),p+t,p+n);uint32_t hgiven=get32(p,t+12,l);put32(ht,HEADER+12,0,l);if(checksum32(ht.data(),ht.size())!=hgiven)return std::nullopt;
    if(!(p[t+9]&TRAIL_NODCHECK)&&checksum32(p+HEADER,t-HEADER)!=get32(p,t,l))return std::nullopt;
    PayloadPacket f;f.little=l;f.multi=(p[3]&0x08)!=0;f.noerr=(p[3]&0x10)!=0;f.first=type==TYPE_FIRST;f.key=get32(p,4,l)&0x7fffffffU;f.seq=get32(p,16,l);f.route_value=get32(p,20,l);f.final_packet=(p[t+9]&TRAIL_EOM)!=0;f.status_request=(p[t+9]&TRAIL_SREQ)!=0;f.return_bit=(get32(p,4,l)&0x80000000U)!=0;f.trailer=p[t+9];
    // dev26 (E6): a malformed SORT/DEADLINE option or named-service segment is a
    // bad frame, not a listener failure.  Drop it; never throw out of receive().
    try{
        f.priority=parse_priority(p,l);f.data.assign(p+HEADER,p+t-pad);
        if(f.first){NamedServiceDescriptor sd;if(decode_named_service(f.data,l,sd)){f.service_name=sd.name;f.service_flags=sd.flags;}}
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
// names them so that a sender's error says why.  dev31: VALUE 4
// MODE_UNSUPPORTED is new, and a SessionListener sends 19 QUOTA_EXCEEDED.
enum DiagValue:uint32_t{DIAG_SERVICE_NOT_ADMITTED=1,DIAG_OVERSIZE=2,DIAG_MALFORMED=3,DIAG_MODE_UNSUPPORTED=4,
    DIAG_POLICY_DENIED=16,DIAG_AUTH_REQUIRED=17,DIAG_FACILITY_UNSUPPORTED=18,DIAG_QUOTA_EXCEEDED=19,
    DIAG_LOOP_DETECTED=20,DIAG_INSPECTION_DENIED=21,DIAG_NOT_READY=22,DIAG_EMERGENCY_VETO=23};
const char* diag_value_name(uint32_t v){switch(v){
    case DIAG_SERVICE_NOT_ADMITTED:return "SERVICE_NOT_ADMITTED";case DIAG_OVERSIZE:return "OVERSIZE";case DIAG_MALFORMED:return "MALFORMED";case DIAG_MODE_UNSUPPORTED:return "MODE_UNSUPPORTED";
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
    // dev31: a hard limit on time without progress.  The early wake for a
    // SPAN hole (step 3) is not a timeout, so a peer that reported a SPAN and
    // then went silent was resent to for ever (seen once in about 35 runs of
    // test S3, when the listener had delivered and stopped reading).
    const double progress_budget_ms=double(o.retries+1)*8.0*double(std::max(1,o.timeout_ms));
    Clock::time_point progress_at=t0;
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
        if(progressed){no_progress=0;backoff=0;progress_at=Clock::now();}
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
        if(ms_since(progress_at)>progress_budget_ms)throw std::runtime_error("no progress for "+std::to_string(int64_t(progress_budget_ms))+" ms");
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

namespace detail {
// dev30 DIAG rate limit: token buckets per peer host (rate, bursts up to
// burst) and in total (global_rate, bursts up to twice that).  At most
// MAX_PEERS peers are tracked; idle ones (bucket full again) are forgotten,
// and beyond that DIAG is withheld.  dev31 moved it here from Listener::Impl
// so that SessionListener shares it.
struct DiagLimiter{
    struct Bucket{double tokens=0;std::chrono::steady_clock::time_point at{};};
    std::map<std::string,Bucket> peers;
    Bucket global;
    bool ready=false;
    static constexpr size_t MAX_PEERS=4096;
    static void refill(Bucket&b,double rate,double cap,std::chrono::steady_clock::time_point now){
        b.tokens=std::min(cap,b.tokens+rate*std::chrono::duration<double>(now-b.at).count());b.at=now;
    }
    bool allow(const std::string&peer,uint32_t peer_rate,uint32_t peer_burst,uint32_t global_rate){
        if(peer_rate==0||global_rate==0)return false;
        const auto now=std::chrono::steady_clock::now();
        const double rate=peer_rate,burst=std::max<double>(1.0,peer_burst);
        const double grate=global_rate,gburst=2.0*grate;
        if(!ready){global={gburst,now};ready=true;}
        refill(global,grate,gburst,now);
        auto it=peers.find(peer);
        if(it==peers.end()){
            if(peers.size()>=MAX_PEERS){
                for(auto j=peers.begin();j!=peers.end();){refill(j->second,rate,burst,now);if(j->second.tokens>=burst)j=peers.erase(j);else ++j;}
                if(peers.size()>=MAX_PEERS)return false;
            }
            it=peers.emplace(peer,Bucket{burst,now}).first;
        }
        refill(it->second,rate,burst,now);
        if(it->second.tokens<1.0||global.tokens<1.0)return false;
        it->second.tokens-=1.0;global.tokens-=1.0;
        return true;
    }
};
} // namespace detail

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
    // dev31: the dev30 token buckets now live in detail::DiagLimiter, shared with SessionListener.
    detail::DiagLimiter diag_limiter;
    size_t trigger_bytes=0;std::string trigger_peer;
    size_t diag_sent=0,diag_suppressed=0;
    bool diag_allowed(const std::string&peer){return diag_limiter.allow(peer,options.diag_rate_per_sec,options.diag_burst,options.diag_global_rate_per_sec);}
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

// ===========================================================================
// dev31: persistent interactive contexts (include/xtp/xtp_session.hpp).
// Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).  See docs/SESSIONS.md.
//
// Wire, all within the libxtp 3.4 profile:
//   open    initiator FIRST, KEY without the return bit, seq 0, named-service
//           descriptor with flag INTERACTIVE; then a CNTL with SREQ.
//   accept  responder FIRST with the return bit, seq 0, the same descriptor
//           and flag; then a CNTL with SREQ.  An older listener never sends
//           this, so the opener fails at its timeout instead of guessing.
//   refuse  DIAG (code 1): SERVICE_NOT_ADMITTED, MODE_UNSUPPORTED (a FIRST
//           without the flag) or QUOTA_EXCEEDED (context table or backlog full).
//   data    DATA in each direction; the initiator's KEY lacks the return bit,
//           the responder's has it.  Sequence counts user bytes per direction.
//           Trailer: EOM ends a message, WCLOSE ends the direction.
//   status  CNTL from either end reports that end's receive side: RSEQ, ALLOC
//           (= bytes its application has read + receive window), DSEQ (= bytes
//           its application has read), SPANs, ECHO of the peer's last SYNC.
//           SREQ + SYNC asks the peer for its status.  RCLOSE: the peer's
//           WCLOSE and everything before it has arrived.  WCLOSE: our WCLOSE
//           has been sent.
//   close   when our WCLOSE is acknowledged (RCLOSE) and the peer's has arrived,
//           CNTL RCLOSE|WCLOSE|END.  END alone is an abort.
// ===========================================================================
namespace xtp {
namespace detail {

using SClock=std::chrono::steady_clock;
using STime=SClock::time_point;

struct SPeer{sockaddr_in in{};std::array<uint8_t,6> mac{};std::string host;std::string text;};

bool same_session_peer(int layer,const SPeer&a,const SPeer&b){
    if(layer==2)return a.mac==b.mac;
    if(layer==3)return a.in.sin_addr.s_addr==b.in.sin_addr.s_addr;
    return a.in.sin_addr.s_addr==b.in.sin_addr.s_addr&&a.in.sin_port==b.in.sin_port;
}

// One carrier socket.  A listening carrier binds the route's own address; an
// opening carrier binds an ephemeral one (UDP) or the interface (raw36, L2).
struct SCarrier{
    int layer=4;int fd=-1;unsigned ifindex=0;std::array<uint8_t,6> local_mac{};
    ~SCarrier(){if(fd>=0)::close(fd);}
    static std::unique_ptr<SCarrier> open(const Route&r,bool listen){
        auto c=std::make_unique<SCarrier>();c->layer=r.layer;
        auto fail=[&](const char*what){throw std::runtime_error(std::string(what)+std::strerror(errno));};
        if(r.layer==4&&r.carrier=="udp"){
            c->fd=socket(AF_INET,SOCK_DGRAM,0);if(c->fd<0)fail("XTP session UDP socket: ");
            sockaddr_in a{};a.sin_family=AF_INET;
            if(listen){auto e=ep(r.destination);a=ipaddr(e.host,e.port);}else{a.sin_addr.s_addr=htonl(INADDR_ANY);a.sin_port=0;}
            if(bind(c->fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)fail("XTP session UDP bind: ");
        }else if(r.layer==3&&r.carrier=="raw36"){
            c->fd=socket(AF_INET,SOCK_RAW,36);if(c->fd<0)fail("XTP session raw36 socket: ");
            if(listen&&!r.destination.empty()){auto a=ipaddr(r.destination);if(bind(c->fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)fail("XTP session raw36 bind: ");}
            if(!r.interface_name.empty()){ifreq ifr{};std::strncpy(ifr.ifr_name,r.interface_name.c_str(),IFNAMSIZ-1);if(setsockopt(c->fd,SOL_SOCKET,SO_BINDTODEVICE,&ifr,sizeof(ifr))<0)fail("SO_BINDTODEVICE: ");}
        }else if(r.layer==2&&r.carrier=="l2"){
            if(r.interface_name.empty())throw std::runtime_error("XTP L2 session route has no interface");
            c->ifindex=if_nametoindex(r.interface_name.c_str());if(!c->ifindex)throw std::runtime_error("unknown L2 interface: "+r.interface_name);
            c->fd=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));if(c->fd<0)fail("XTP session AF_PACKET socket: ");
            sockaddr_ll a{};a.sll_family=AF_PACKET;a.sll_protocol=htons(XTP_ETHERTYPE);a.sll_ifindex=int(c->ifindex);
            if(bind(c->fd,reinterpret_cast<sockaddr*>(&a),sizeof(a))<0)fail("XTP session AF_PACKET bind: ");
            c->local_mac=iface_mac(c->fd,r.interface_name);
        }else throw std::runtime_error("unsupported XTP session carrier/layer: "+std::to_string(r.layer)+"/"+r.carrier);
        int want=4*1024*1024;if(setsockopt(c->fd,SOL_SOCKET,SO_RCVBUFFORCE,&want,sizeof(want))<0)setsockopt(c->fd,SOL_SOCKET,SO_RCVBUF,&want,sizeof(want));
        return c;
    }
    // A send that fails is treated as a lost packet; retransmission covers it.
    bool send(const std::vector<uint8_t>&pkt,const SPeer&to){
        if(layer==2){
            std::vector<uint8_t> fr(14+pkt.size());std::copy(to.mac.begin(),to.mac.end(),fr.begin());std::copy(local_mac.begin(),local_mac.end(),fr.begin()+6);
            fr[12]=uint8_t(XTP_ETHERTYPE>>8);fr[13]=uint8_t(XTP_ETHERTYPE);std::copy(pkt.begin(),pkt.end(),fr.begin()+14);
            sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(ifindex);out.sll_halen=6;std::copy(to.mac.begin(),to.mac.end(),out.sll_addr);
            return sendto(fd,fr.data(),fr.size(),0,reinterpret_cast<sockaddr*>(&out),sizeof(out))>=0;
        }
        return sendto(fd,pkt.data(),pkt.size(),0,reinterpret_cast<const sockaddr*>(&to.in),sizeof(to.in))>=0;
    }
    // Waits up to timeout_ms.  False if nothing usable arrived.
    bool recv(std::vector<uint8_t>&out,SPeer&from,int timeout_ms){
        pollfd p{fd,POLLIN,0};if(poll(&p,1,timeout_ms)<=0)return false;
        // 64 KB packet plus the 14-byte Ethernet header (lo has a 64 KB MTU).
        std::array<uint8_t,65536+64> b;ssize_t n;
        if(layer==2){
            sockaddr_ll sl{};socklen_t sll=sizeof(sl);
            n=recvfrom(fd,b.data(),b.size(),MSG_DONTWAIT,reinterpret_cast<sockaddr*>(&sl),&sll);
            if(n<14||sl.sll_pkttype==PACKET_OUTGOING)return false;
            if(b[12]!=uint8_t(XTP_ETHERTYPE>>8)||b[13]!=uint8_t(XTP_ETHERTYPE))return false;
            if(!std::equal(local_mac.begin(),local_mac.end(),b.begin()))return false;
            std::copy(b.begin()+6,b.begin()+12,from.mac.begin());from.text=mac_text(b.data()+6);from.host=from.text;
            out.assign(b.begin()+14,b.begin()+n);return true;
        }
        sockaddr_in a{};socklen_t al=sizeof(a);
        n=recvfrom(fd,b.data(),b.size(),MSG_DONTWAIT,reinterpret_cast<sockaddr*>(&a),&al);
        if(n<=0)return false;
        from.in=a;from.host=ip_peer(a,false);
        if(layer==3){auto pp=raw_payload(b.data(),size_t(n));if(!pp)return false;out.assign(pp->first,pp->first+pp->second);from.text=from.host;}
        else{out.assign(b.begin(),b.begin()+n);from.text=ip_peer(a,true);}
        return true;
    }
};

SPeer route_peer(const Route&r){
    SPeer p;
    if(r.layer==4){auto e=ep(r.destination);p.in=ipaddr(e.host,e.port);p.host=ip_peer(p.in,false);p.text=ip_peer(p.in,true);}
    else if(r.layer==3){p.in=ipaddr(r.destination);p.host=ip_peer(p.in,false);p.text=p.host;}
    else{p.mac=mac(r.destination);p.text=mac_text(p.mac.data());p.host=p.text;}
    return p;
}
size_t session_segment(const Route&r,const SessionTuning&t){
    size_t seg=t.segment_bytes;
    size_t most=r.layer==2?(iface_mtu(r.interface_name)>HEADER+TRAILER+64?iface_mtu(r.interface_name)-HEADER-TRAILER:64):r.layer==3?65535-20-HEADER-TRAILER:65507-HEADER-TRAILER;
    if(seg){if(seg<64)throw std::runtime_error("XTP segment_bytes must be at least 64");if(seg>most)throw std::runtime_error("XTP segment_bytes "+std::to_string(seg)+" exceeds the carrier maximum "+std::to_string(most));}
    else if(r.layer==2){const size_t mtu=iface_mtu(r.interface_name);seg=mtu>HEADER+TRAILER+64?mtu-HEADER-TRAILER:64;}
    else seg=1408;
    seg&=~size_t(7);return seg<64?64:seg;
}

void seal(std::vector<uint8_t>&b,size_t t,bool little){
    std::vector<uint8_t>ht(b.begin(),b.begin()+HEADER);ht.insert(ht.end(),b.begin()+long(t),b.end());put32(ht,HEADER+12,0,little);put32(b,t+12,checksum32(ht.data(),ht.size()),little);
}
std::vector<uint8_t> s_payload(uint8_t type,uint32_t wkey,uint32_t seq,const uint8_t*d,size_t n,uint8_t flags,bool little,const PrioritySpec&pr){
    const size_t pad=(8-(n%8))%8,body=n+pad;
    std::vector<uint8_t>b(HEADER+body+TRAILER,0);
    b[0]=cmd0(type,little);b[3]=uint8_t((little?0x80:0)|priority_flags(pr));
    put32(b,4,wkey,little);put32(b,8,pr.mode==PriorityMode::Disabled?0u:pr.sort,little);put32(b,16,seq,little);
    if(n)std::copy(d,d+n,b.begin()+HEADER);
    const size_t t=HEADER+body;put32(b,t,checksum32(b.data()+HEADER,body),little);b[t+8]=uint8_t(pad);b[t+9]=flags;put16(b,t+10,64,little);
    seal(b,t,little);return b;
}
uint32_t clamp32(uint64_t v){return v>0xffffffffull?0xffffffffu:uint32_t(v);}
std::vector<uint8_t> s_cntl(uint32_t wkey,uint64_t rseq,uint64_t alloc,uint64_t dseq,uint32_t echo,uint32_t sync,const std::vector<Span>&spans,uint8_t flags,bool little,const PrioritySpec&pr,size_t extra=0){
    // extra: zero bytes after the SPANs, before the trailer (dev32: room for the protection tail)
    const size_t nspan=std::min<size_t>(spans.size(),MAX_SPANS),CTL=CONTROL+nspan*8u+extra;
    std::vector<uint8_t>b(HEADER+CTL+TRAILER,0);
    b[0]=cmd0(TYPE_CNTL,little);b[3]=uint8_t((little?0x80:0)|priority_flags(pr));put32(b,4,wkey,little);put32(b,8,pr.mode==PriorityMode::Disabled?0u:pr.sort,little);
    const size_t c=HEADER;put32(b,c,0xffffffffu,little);put32(b,c+4,0xffffffffu,little);put32(b,c+8,clamp32(rseq),little);put32(b,c+12,clamp32(alloc),little);
    put32(b,c+16,echo,little);put32(b,c+20,sync,little);put32(b,c+28,wkey,little);put32(b,c+36,uint32_t(nspan),little);
    for(size_t i=0;i<nspan;++i){put32(b,c+CONTROL+8*i,spans[i].first,little);put32(b,c+CONTROL+8*i+4,spans[i].second,little);}
    const size_t t=HEADER+CTL;put32(b,t,checksum32(b.data()+HEADER,CTL),little);put32(b,t+4,clamp32(dseq),little);b[t+9]=flags;put16(b,t+10,64,little);
    seal(b,t,little);return b;
}

// ---------------------------------------------------------------------------
// dev32: protection tail (docs/SECURITY.md).  A protected packet ends its
// segment with 24 bytes: an 8-byte big-endian packet counter and a 16-byte AEAD
// tag.  The tag covers the header, the clear part of the segment, the trailer
// fields that are not checksums (DSEQ, pad, flags, TTL) and the counter.  In
// encrypt mode the data bytes are the AEAD ciphertext; otherwise they are
// covered as clear.  Checksums are recomputed afterwards so the wire stays a
// valid 3.4 packet.
constexpr size_t TAIL=24;
constexpr uint8_t DIR_I2R=0x01,DIR_R2I=0x02,DIR_OPEN=0x03,DIR_REFUSE=0x04;
constexpr std::array<uint8_t,4> XSEC_MAGIC{{'X','S','E','C'}};
constexpr size_t OPEN_BLOCK=40,ACCEPT_BLOCK=24;
constexpr int64_t OPEN_CLOCK_WINDOW_MS=30000;
constexpr int64_t OPEN_NONCE_TTL_MS=2*OPEN_CLOCK_WINDOW_MS;    // a nonce is replayable only within the window
constexpr size_t OPEN_NONCE_CAP=65536,OPEN_NONCE_CAP_PER_KEY=16384;
constexpr int MAX_ACCEPT_RESENDS=8;
constexpr int UNCONFIRMED_TIMEOUT_MS=10000;   // a protected context never confirmed by its opener is dropped silently

void be64(uint8_t*p,uint64_t v){for(int i=7;i>=0;--i){p[i]=uint8_t(v);v>>=8;}}
uint64_t from_be64(const uint8_t*p){uint64_t v=0;for(int i=0;i<8;++i)v=(v<<8)|p[i];return v;}
std::vector<uint8_t> tail_aad(const std::vector<uint8_t>&pkt,size_t tail_off,size_t enc_off,size_t enc_len,uint64_t ctr){
    const size_t t=pkt.size()-TRAILER;
    std::vector<uint8_t> aad(pkt.begin(),pkt.begin()+HEADER);
    for(size_t i=HEADER;i<tail_off;++i)if(i<enc_off||i>=enc_off+enc_len)aad.push_back(pkt[i]);
    aad.insert(aad.end(),pkt.begin()+long(t+4),pkt.begin()+long(t+12));
    uint8_t c[8];be64(c,ctr);aad.insert(aad.end(),c,c+8);
    return aad;
}
void tail_nonce(uint8_t n[12],uint8_t dir,uint64_t ctr){std::memset(n,0,12);n[0]=dir;be64(n+4,ctr);}
// Seal pkt in place.  pkt already holds TAIL zero bytes at tail_off.  When
// enc_len > 0, bytes [enc_off, enc_off+enc_len) are encrypted.
void protect(std::vector<uint8_t>&pkt,bool little,CipherSuite suite,const uint8_t key[32],uint8_t dir,uint64_t ctr,size_t tail_off,size_t enc_off,size_t enc_len){
    auto aad=tail_aad(pkt,tail_off,enc_off,enc_len,ctr);
    uint8_t nonce[12];tail_nonce(nonce,dir,ctr);
    be64(pkt.data()+tail_off,ctr);
    security::seal(suite,key,nonce,aad,pkt.data()+enc_off,enc_len,pkt.data()+enc_off,pkt.data()+tail_off+8);
    const size_t t=pkt.size()-TRAILER;
    put32(pkt,t,checksum32(pkt.data()+HEADER,t-HEADER),little);
    seal(pkt,t,little);
}
// Verify in place (decrypting [enc_off, enc_off+enc_len) when enc_len > 0).
// Returns the counter, or nullopt if the tag does not verify.
std::optional<uint64_t> unprotect(std::vector<uint8_t>&pkt,CipherSuite suite,const uint8_t key[32],uint8_t dir,size_t tail_off,size_t enc_off,size_t enc_len){
    if(tail_off+TAIL>pkt.size()-TRAILER||tail_off<HEADER)return std::nullopt;
    const uint64_t ctr=from_be64(pkt.data()+tail_off);
    auto aad=tail_aad(pkt,tail_off,enc_off,enc_len,ctr);
    uint8_t nonce[12];tail_nonce(nonce,dir,ctr);
    std::vector<uint8_t> plain(enc_len);
    if(!security::open(suite,key,nonce,aad,pkt.data()+enc_off,enc_len,pkt.data()+tail_off+8,plain.data()))return std::nullopt;
    if(enc_len)std::copy(plain.begin(),plain.end(),pkt.begin()+long(enc_off));
    return ctr;
}
// Where the tail sits in a received FIRST, DATA or DIAG: the last TAIL bytes of
// the information segment, before the pad.
std::optional<size_t> payload_tail_off(const std::vector<uint8_t>&pkt){
    if(pkt.size()<HEADER+TAIL+TRAILER)return std::nullopt;
    const size_t t=pkt.size()-TRAILER;const size_t pad=pkt[t+8]&0x3f;
    if(pad>t-HEADER||t-pad<HEADER+TAIL)return std::nullopt;
    return t-pad-TAIL;
}
// 1024-packet anti-replay window, as IPsec.
struct ReplayWindow{
    uint64_t top=0;std::array<uint64_t,16> bits{};
    bool seen(uint64_t c) const{if(c>top)return false;const uint64_t d=top-c;if(d>=1024)return true;return (bits[d/64]>>(d%64))&1u;}
    bool accept(uint64_t c){
        if(c==0||seen(c))return false;
        if(c>top){
            const uint64_t shift=c-top;
            if(shift>=1024)bits.fill(0);
            else for(uint64_t s=0;s<shift;++s){for(int w=15;w>0;--w)bits[w]=(bits[w]<<1)|(bits[w-1]>>63);bits[0]<<=1;}
            top=c;bits[0]|=1u;return true;
        }
        const uint64_t d=top-c;bits[d/64]|=uint64_t(1)<<(d%64);return true;
    }
};
std::vector<uint8_t> label(const char*what,const std::string&service,uint32_t key,const std::vector<uint8_t>&extra={}){
    std::vector<uint8_t> v(what,what+std::strlen(what));v.push_back(0);v.insert(v.end(),service.begin(),service.end());v.push_back(0);
    uint8_t k[4]={uint8_t(key>>24),uint8_t(key>>16),uint8_t(key>>8),uint8_t(key)};v.insert(v.end(),k,k+4);v.insert(v.end(),extra.begin(),extra.end());
    return v;
}
uint8_t protection_flags(Protection p){return p==Protection::Encrypt?uint8_t(XTP_SERVICE_FLAG_AUTHENTICATED|XTP_SERVICE_FLAG_ENCRYPTED):p==Protection::Authenticate?XTP_SERVICE_FLAG_AUTHENTICATED:uint8_t(0);}
Protection protection_of(uint8_t flags){return (flags&XTP_SERVICE_FLAG_ENCRYPTED)?Protection::Encrypt:(flags&XTP_SERVICE_FLAG_AUTHENTICATED)?Protection::Authenticate:Protection::None;}

constexpr uint64_t SESSION_MAX_OFFSET=0xffffffffull;   // 32-bit sequence space per direction
constexpr size_t MAX_OOO_SEGMENTS=1024;                  // out-of-order segments held per context
// SYNC bases come from the system random source, not the sequential KEY
// counter, so a peer cannot predict the next context's SYNC values.
uint32_t random31(){
    static std::mutex m;static std::random_device rd;
    std::lock_guard<std::mutex> g(m);
    for(;;){const uint32_t v=uint32_t(rd())&0x7fffffffU;if(v)return v;}
}

struct SOut{uint64_t a=0,z=0;uint8_t flags=0;STime sent{};uint32_t sync=0;};

// Review M1: protected opens are rate limited before any cryptography.  One
// token bucket per sending address and one in total; O(1) per open.  When the
// per-address table is full only the total applies, and the table is swept of
// idle addresses once a second, never per packet.
struct OpenLimiter{
    struct Bucket{double tokens=0;STime at{};};
    std::unordered_map<std::string,Bucket> peers;Bucket total;bool ready=false;STime swept{};
    static constexpr size_t MAX_PEERS=4096;
    static void refill(Bucket&b,double rate,double cap,STime now){b.tokens=std::min(cap,b.tokens+rate*std::chrono::duration<double>(now-b.at).count());b.at=now;}
    bool allow(const std::string&peer,uint32_t rate,uint32_t burst,uint32_t global_rate,STime now){
        if(rate==0||global_rate==0)return false;
        const double cap=std::max<double>(1.0,burst),gcap=2.0*global_rate;
        if(!ready){total={gcap,now};ready=true;swept=now;}
        refill(total,global_rate,gcap,now);
        if(now-swept>=std::chrono::seconds(1)){
            swept=now;
            for(auto it=peers.begin();it!=peers.end();){refill(it->second,rate,cap,now);if(it->second.tokens>=cap)it=peers.erase(it);else ++it;}
        }
        auto it=peers.find(peer);
        if(it==peers.end()&&peers.size()<MAX_PEERS)it=peers.emplace(peer,Bucket{cap,now}).first;
        if(it!=peers.end()){refill(it->second,rate,cap,now);if(it->second.tokens<1.0)return false;}
        if(total.tokens<1.0)return false;
        if(it!=peers.end())it->second.tokens-=1.0;
        total.tokens-=1.0;return true;
    }
};

// One context.  Every field is guarded by the owning endpoint's mutex.
struct SCore:std::enable_shared_from_this<SCore>{
    uint32_t key=0;bool initiator=false;bool little=true;PrioritySpec prio{};SPeer peer;std::string service;
    SessionTuning tun;size_t seg=1408;
    enum St{OPENING,OPEN,DONE,FAILED} st=OPENING;std::string error;bool accepted=false;bool abort_sent=false;
    STime created{},last_heard{},last_ka{},open_retry_at{},done_at{};int open_backoff=0;int open_timeout_ms=3000;
    // sending direction
    std::deque<uint8_t> sbuf;uint64_t sbase=0,written=0,snd_nxt=0;std::set<uint64_t> eoms;
    bool wclose_req=false,wclose_sent=false,wclose_acked=false;STime abort_at{},end_retry_at{};
    uint64_t peer_alloc=0,peer_rseq=0;std::vector<Span> peer_spans;
    std::map<uint64_t,SOut> inflight;
    uint32_t sync_base=0,sync_last=0;std::map<uint32_t,STime> sync_times;bool peer_echoed=false;
    double srtt=-1;int backoff=0;STime rto_at{},progress_at{},probe_at{};bool rto_armed=false;
    // receiving direction
    uint64_t rcv_nxt=0,delivered=0,rseq_adv=0,alloc_adv=0;
    std::map<uint64_t,std::pair<std::vector<uint8_t>,uint8_t>> ooo;size_t ooo_bytes=0;
    std::deque<SessionChunk> ready;size_t ready_bytes=0;
    bool peer_wclose=false;uint64_t peer_wclose_at=0;bool peer_end=false;
    uint32_t peer_sync=0;bool need_cntl=false;
    SessionStats stats;
    size_t stale_ignored=0;
    // dev32 protection
    Protection prot=Protection::None;CipherSuite suite=CipherSuite::Aes256Gcm;uint64_t key_id=0;std::string key_principal;
    std::array<uint8_t,32> tx_key{},rx_key{},open_key{};std::array<uint8_t,16> nonce_i{},nonce_r{};
    uint64_t tx_ctr=0;ReplayWindow rx_win;std::vector<uint8_t> first_pkt;
    std::array<uint8_t,32> lt_secret{};std::string unauthenticated_refusal;   // initiator: long-term key until accepted
    // responder (review M2, M3): a protected context is unconfirmed until a
    // packet verifies under the opener's context key.  Until then it is not
    // offered to accept(), a duplicate open must be byte-identical to the one
    // that opened it, and the accept is resent at most MAX_ACCEPT_RESENDS times.
    bool confirmed=true;std::vector<uint8_t> open_pkt;int accept_resends=0;
    // initiator: the accept that opened the context; a byte-identical copy
    // (the responder resending it) is answered with a CNTL, a bounded number of times
    std::vector<uint8_t> accept_pkt;int accept_answers=0;
    bool guarded() const{return prot!=Protection::None;}
    uint8_t tx_dir() const{return initiator?DIR_I2R:DIR_R2I;}
    uint8_t rx_dir() const{return initiator?DIR_R2I:DIR_I2R;}
    ~SCore(){OPENSSL_cleanse(tx_key.data(),32);OPENSSL_cleanse(rx_key.data(),32);OPENSSL_cleanse(open_key.data(),32);OPENSSL_cleanse(lt_secret.data(),32);}

    uint32_t wkey() const{return initiator?(key&0x7fffffffU):((key&0x7fffffffU)|0x80000000U);}
    uint32_t issue_sync(){if(++sync_last==0)++sync_last;return sync_last;}
    // An ECHO belongs to this context only if it is a SYNC we have issued.
    bool in_context(uint32_t e) const{return e!=0&&uint32_t(e-sync_base)>=1u&&uint32_t(e-sync_base)<=uint32_t(sync_last-sync_base);}
    bool sync_le(uint32_t a,uint32_t b) const{return uint32_t(a-sync_base)<=uint32_t(b-sync_base);}
    int rto_ms() const{
        const double base=srtt<0?200.0:std::max<double>(tun.rto_min_ms,2.0*srtt);
        const double r=base*double(1u<<std::min(backoff,16));
        return int(std::min<double>(r,tun.rto_max_ms));
    }
    bool covered(const SOut&s) const{
        if(s.a==s.z)return wclose_acked;
        if(s.z<=peer_rseq)return true;
        for(const auto&sp:peer_spans)if(sp.first<=s.a&&s.z<=sp.second)return true;
        return false;
    }
    bool peer_input_complete() const{return peer_wclose&&rcv_nxt>=peer_wclose_at;}
    std::vector<Span> spans() const{
        std::vector<Span> v;
        for(const auto&kv:ooo){
            const uint32_t a=uint32_t(kv.first),z=uint32_t(kv.first+kv.second.first.size());
            if(z<=a)continue;
            if(!v.empty()&&a<=v.back().second){if(z>v.back().second)v.back().second=z;}
            else{if(v.size()==MAX_SPANS)break;v.emplace_back(a,z);}
        }
        return v;
    }
    void deliver(const uint8_t*p,size_t n,bool eom){
        if(n==0){if(eom&&!ready.empty()&&!ready.back().eom)ready.back().eom=true;return;}
        if(ready.empty()||ready.back().eom)ready.emplace_back();
        ready.back().data.insert(ready.back().data.end(),p,p+n);ready_bytes+=n;
        if(eom)ready.back().eom=true;
    }
};

struct SEndpoint{
    Route route;std::unique_ptr<SCarrier> car;bool listening=false;SessionListenOptions lo;SPeer initiator_peer;
    mutable std::mutex m;std::condition_variable cv;std::thread th;std::atomic<bool> stop{false};
    std::map<std::pair<std::string,uint32_t>,std::shared_ptr<SCore>> cores;
    std::deque<std::shared_ptr<SCore>> backlog;bool accepting=true;
    DiagLimiter diag;size_t diag_sent=0,diag_suppressed=0;
    // dev32: nonces of protected opens accepted, for OPEN_NONCE_TTL_MS.  Hash
    // set plus an expiry queue in arrival order (review M1: O(1) per open, not
    // a scan), with a share per key id so one key holder cannot fill it.
    std::unordered_set<std::string> open_nonces;std::deque<std::tuple<int64_t,std::string,uint64_t>> open_nonce_q;
    std::unordered_map<uint64_t,size_t> open_nonces_per_key;STime keys_checked{};
    OpenLimiter open_limit;size_t opens_rate_limited=0;
    STime last_log{};size_t unlogged=0;bool log_ready=false;

    SEndpoint(const Route&r,bool listen,const SessionListenOptions&o):route(r),car(SCarrier::open(r,listen)),listening(listen),lo(o){}
    ~SEndpoint(){stop=true;if(th.joinable())th.join();}
    void start(){th=std::thread([this]{run();});}

    void send(SCore&c,const std::vector<uint8_t>&pkt){car->send(pkt,c.peer);c.stats.packets_sent++;}
    // The FIRST that opens (initiator) or accepts (responder) the context.
    // dev32: a protected open carries an open block (key id, initiator nonce,
    // time) under the open key; a protected accept carries the responder nonce
    // under the new context key.  Either is built once and resent unchanged.
    void send_first(SCore&c){
        if(!c.first_pkt.empty()){send(c,c.first_pkt);return;}
        const uint8_t flags=uint8_t(XTP_SERVICE_FLAG_INTERACTIVE|protection_flags(c.prot));
        auto sd=encode_named_service(c.service,c.little,flags);
        if(!c.guarded()){
            send(c,s_payload(TYPE_FIRST,c.wkey(),0,sd.data(),sd.size(),c.initiator?TRAIL_SREQ:0,c.little,c.prio));
            return;
        }
        std::vector<uint8_t> body=sd;
        body.insert(body.end(),XSEC_MAGIC.begin(),XSEC_MAGIC.end());
        body.push_back(1);body.push_back(uint8_t(c.suite));body.push_back(uint8_t(c.prot));body.push_back(0);
        if(c.initiator){
            uint8_t id[8];be64(id,c.key_id);body.insert(body.end(),id,id+8);
            body.insert(body.end(),c.nonce_i.begin(),c.nonce_i.end());
            uint8_t ts[8];be64(ts,uint64_t(security::now_ms()));body.insert(body.end(),ts,ts+8);
        }else body.insert(body.end(),c.nonce_r.begin(),c.nonce_r.end());
        const size_t tail_at=HEADER+body.size();
        body.resize(body.size()+TAIL,0);
        auto pkt=s_payload(TYPE_FIRST,c.wkey(),0,body.data(),body.size(),c.initiator?TRAIL_SREQ:0,c.little,c.prio);
        if(c.initiator)protect(pkt,c.little,c.suite,c.open_key.data(),DIR_OPEN,0,tail_at,tail_at,0);
        else protect(pkt,c.little,c.suite,c.tx_key.data(),c.tx_dir(),++c.tx_ctr,tail_at,tail_at,0);
        c.first_pkt=pkt;send(c,pkt);
    }
    // A CNTL, with the protection tail when the context is protected.
    void send_cntl_packet(SCore&c,uint64_t rseq,uint64_t alloc,uint64_t dseq,uint32_t echo,uint32_t sync,const std::vector<Span>&spans,uint8_t fl){
        if(!c.guarded()){send(c,s_cntl(c.wkey(),rseq,alloc,dseq,echo,sync,spans,fl,c.little,c.prio));return;}
        if(c.st==SCore::OPENING)return;   // no context key yet: the open FIRST carries everything
        auto pkt=s_cntl(c.wkey(),rseq,alloc,dseq,echo,sync,spans,fl,c.little,c.prio,TAIL);
        const size_t tail_at=pkt.size()-TRAILER-TAIL;
        protect(pkt,c.little,c.suite,c.tx_key.data(),c.tx_dir(),++c.tx_ctr,tail_at,tail_at,0);
        send(c,pkt);
    }
    void send_cntl(SCore&c,bool sreq,STime now){
        uint32_t sync=0;uint8_t fl=0;
        if(sreq){sync=c.issue_sync();c.sync_times[sync]=now;while(c.sync_times.size()>64)c.sync_times.erase(c.sync_times.begin());fl|=TRAIL_SREQ;}
        if(c.peer_input_complete())fl|=TRAIL_RCLOSE;
        if(c.wclose_sent)fl|=TRAIL_WCLOSE;
        if(c.st==SCore::DONE)fl|=TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END;
        const uint64_t alloc=c.delivered+c.tun.receive_window;
        send_cntl_packet(c,c.rcv_nxt,alloc,c.delivered,c.peer_sync,sync,c.spans(),fl);
        c.rseq_adv=c.rcv_nxt;c.alloc_adv=alloc;c.need_cntl=false;
    }
    void send_abort(SCore&c){
        if(c.abort_sent)return;
        c.abort_sent=true;c.abort_at=SClock::now();
        send_cntl_packet(c,c.rcv_nxt,c.delivered+c.tun.receive_window,c.delivered,c.peer_sync,0,{},TRAIL_END);
    }
    // A peer still sending to a context we aborted gets the abort again (at
    // most every 200 ms), so a lost END does not leave it waiting for dead_after_ms.
    void resend_abort(SCore&c,STime now){
        if(!c.abort_sent||now-c.abort_at<std::chrono::milliseconds(200))return;
        c.abort_sent=false;send_abort(c);
    }
    // At most one diagnostic line per second per endpoint; the rest are counted.
    void log_line(const std::string&line,STime now){
        if(log_ready&&now-last_log<std::chrono::seconds(1)){++unlogged;return;}
        if(unlogged)std::fprintf(stderr,"%s (and %zu more lines not shown)\n",line.c_str(),unlogged);
        else std::fprintf(stderr,"%s\n",line.c_str());
        unlogged=0;last_log=now;log_ready=true;
    }
    void fail(SCore&c,const std::string&why,bool tell_peer,STime now){
        if(c.st==SCore::FAILED||c.st==SCore::DONE)return;
        if(tell_peer)send_abort(c);
        c.st=SCore::FAILED;c.error=why;c.done_at=now;c.rto_armed=false;
        cv.notify_all();
    }
    void send_seg(SCore&c,SOut&s,STime now){
        if(s.a<c.sbase||s.z>c.written)return;   // cannot happen after the RSEQ rule in on_cntl; never index outside sbuf
        const size_t off=size_t(s.a-c.sbase),n=size_t(s.z-s.a);
        std::vector<uint8_t> tmp(n+(c.guarded()?TAIL:0));for(size_t i=0;i<n;++i)tmp[i]=c.sbuf[off+i];
        auto pkt=s_payload(TYPE_DATA,c.wkey(),uint32_t(s.a),tmp.data(),tmp.size(),s.flags,c.little,c.prio);
        // dev32: each send, retransmissions included, gets a fresh counter.
        if(c.guarded())protect(pkt,c.little,c.suite,c.tx_key.data(),c.tx_dir(),++c.tx_ctr,HEADER+n,HEADER,c.prot==Protection::Encrypt?n:0);
        send(c,pkt);
        s.sent=now;s.sync=c.sync_last+1;
    }
    void check_done(SCore&c,STime now){
        if(c.st!=SCore::OPEN)return;
        if(c.wclose_acked&&c.peer_input_complete()){c.st=SCore::DONE;c.done_at=now;c.rto_armed=false;send_cntl(c,false,now);c.end_retry_at=now+std::chrono::milliseconds(c.rto_ms());cv.notify_all();}
    }
    // Send what the window allows; finish a burst with a status request.
    void transmit(SCore&c,STime now){
        if(c.st!=SCore::OPEN){if(c.need_cntl&&c.st==SCore::DONE)send_cntl(c,false,now);return;}
        const uint64_t limit=std::min(c.written,c.peer_alloc);
        size_t burst=0;const bool was_idle=c.inflight.empty();
        while(c.snd_nxt<limit){
            uint64_t z=std::min<uint64_t>(c.snd_nxt+c.seg,limit);
            auto e=c.eoms.upper_bound(c.snd_nxt);if(e!=c.eoms.end()&&*e<z)z=*e;
            SOut s;s.a=c.snd_nxt;s.z=z;
            if(c.eoms.count(z))s.flags|=TRAIL_EOM;
            if(c.wclose_req&&z==c.written){s.flags|=TRAIL_WCLOSE;c.wclose_sent=true;}
            send_seg(c,s,now);c.inflight[s.a]=s;c.snd_nxt=z;++burst;
        }
        if(c.wclose_req&&!c.wclose_sent&&c.snd_nxt==c.written){
            SOut s;s.a=s.z=c.written;s.flags=TRAIL_WCLOSE;send_seg(c,s,now);c.inflight[s.a]=s;c.wclose_sent=true;++burst;
        }
        c.eoms.erase(c.eoms.begin(),c.eoms.upper_bound(c.snd_nxt));   // sent segments carry their own EOM flag
        if(burst){
            send_cntl(c,true,now);
            if(was_idle)c.progress_at=now;
            if(!c.rto_armed){c.rto_at=now+std::chrono::milliseconds(c.rto_ms());c.rto_armed=true;}
        }else if(c.need_cntl)send_cntl(c,false,now);
        cv.notify_all();
    }
    // A DIAG refusal.  For a protected open whose key we hold (okey), the DIAG
    // carries a tail under the open key, so the opener can tell it is genuine.
    void refuse(const PayloadPacket&f,const SPeer&from,uint32_t value,const std::string&detail,size_t trigger,const uint8_t*okey=nullptr,CipherSuite suite=CipherSuite::Aes256Gcm){
        auto build=[&](const std::string&reason){
            if(!okey)return diag_packet(f.key,DIAG_CONTEXT_REFUSED,value,reason,f.little);
            std::vector<uint8_t> d(8,0);put32(d,0,DIAG_CONTEXT_REFUSED,f.little);put32(d,4,value,f.little);
            d.insert(d.end(),reason.begin(),reason.end());const size_t tail_at=HEADER+d.size();d.resize(d.size()+TAIL,0);
            auto p=s_payload(TYPE_DIAG,(f.key&0x7fffffffU)|0x80000000U,0,d.data(),d.size(),TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_EOM,f.little,{});
            protect(p,f.little,suite,okey,DIR_REFUSE,0,tail_at,tail_at,0);
            return p;
        };
        auto pkt=build(diag_value_name(value));
        if(pkt.size()>trigger)pkt=build(std::string());
        const char*why=nullptr;
        if(pkt.size()>trigger)why="size";else if(!diag.allow(from.host,lo.diag_rate_per_sec,lo.diag_burst,lo.diag_global_rate_per_sec))why="rate";
        const STime now=SClock::now();
        if(why){++diag_suppressed;log_line("XTP_DIAG_SUPPRESSED key="+std::to_string(f.key)+" peer="+from.text+" value="+std::to_string(value)+" detail="+detail+" cause="+why,now);return;}
        ++diag_sent;log_line("XTP_DIAG_SENT key="+std::to_string(f.key)+" peer="+from.text+" value="+std::to_string(value)+" detail="+detail+(okey?" authenticated":""),now);
        car->send(pkt,from);
    }
    bool admitted(const std::string&name) const{
        if(lo.allowed_services.empty())return true;
        return std::find(lo.allowed_services.begin(),lo.allowed_services.end(),name)!=lo.allowed_services.end();
    }
    void expire_open_nonces(int64_t nowms){
        while(!open_nonce_q.empty()&&std::get<0>(open_nonce_q.front())<nowms){
            auto&e=open_nonce_q.front();open_nonces.erase(std::get<1>(e));
            auto it=open_nonces_per_key.find(std::get<2>(e));if(it!=open_nonces_per_key.end()&&--it->second==0)open_nonces_per_key.erase(it);
            open_nonce_q.pop_front();
        }
    }
    // A responder's protected context is confirmed by the first packet that
    // verifies under the opener's context key: only a holder of the key can
    // send one, so a replayed open never reaches accept() (review M2).
    void confirm(SCore&c,STime now){
        if(c.confirmed)return;
        c.confirmed=true;c.open_pkt.clear();c.open_pkt.shrink_to_fit();
        if(!accepting||backlog.size()>=lo.accept_backlog){fail(c,"XTP session listener closed or accept backlog full",true,now);return;}
        backlog.push_back(c.shared_from_this());cv.notify_all();
    }
    // dev32: a protected open is checked before anything else is believed:
    // a known key for this service, a valid open tag, a timestamp within
    // OPEN_CLOCK_WINDOW_MS, and a nonce not seen before.  Anything that fails is
    // dropped and logged, never answered: an answer would need the key.
    void open_from_first(const PayloadPacket&f,const std::vector<uint8_t>&raw,const SPeer&from,STime now){
        const size_t trigger=raw.size();
        const Protection requested=protection_of(f.service_flags);
        Protection required=KeyTable::global().required(f.service_name);
        if(lo.require_protection&&required==Protection::None)required=Protection::Authenticate;
        std::optional<ServiceKey> key;std::array<uint8_t,32> okey{};std::array<uint8_t,16> nonce_i{};std::string nk;
        struct Wipe{std::array<uint8_t,32>&k;~Wipe(){OPENSSL_cleanse(k.data(),k.size());}} wipe_okey{okey};
        if(requested!=Protection::None){
            if(!open_limit.allow(from.text,lo.open_rate_per_sec,lo.open_burst,lo.open_global_rate_per_sec,now)){
                ++opens_rate_limited;log_line("XTP_SESSION_OPEN_DROPPED peer="+from.text+" reason=protected open rate limit ("+std::to_string(opens_rate_limited)+" so far)",now);return;
            }
            const uint8_t*b=f.data.data();
            if(f.data.size()<OPEN_BLOCK+TAIL||!std::equal(XSEC_MAGIC.begin(),XSEC_MAGIC.end(),b)||b[4]!=1||b[6]!=uint8_t(requested)){log_line("XTP_SESSION_OPEN_DROPPED peer="+from.text+" reason=malformed open block",now);return;}
            const uint64_t key_id=from_be64(b+8);std::copy(b+16,b+32,nonce_i.begin());const int64_t ts=int64_t(from_be64(b+32));
            key=KeyTable::global().by_id(key_id);
            if(!key||key->service!=f.service_name||uint8_t(key->suite)!=b[5]){log_line("XTP_SESSION_OPEN_DROPPED peer="+from.text+" service="+f.service_name+" reason=no valid key "+std::to_string(key_id)+" for this service",now);return;}
            auto ok=security::hkdf_sha256(key->secret.data(),32,std::vector<uint8_t>(nonce_i.begin(),nonce_i.end()),label("XTP-OPEN-1",f.service_name,f.key),32);
            std::copy(ok.begin(),ok.end(),okey.begin());OPENSSL_cleanse(ok.data(),ok.size());
            auto copy=raw;auto toff=payload_tail_off(copy);
            auto ctr=toff?unprotect(copy,key->suite,okey.data(),DIR_OPEN,*toff,*toff,0):std::nullopt;
            if(!ctr||*ctr!=0){log_line("XTP_SESSION_OPEN_DROPPED peer="+from.text+" service="+f.service_name+" reason=open tag did not verify",now);return;}
            const int64_t nowms=security::now_ms();
            if(ts<nowms-OPEN_CLOCK_WINDOW_MS||ts>nowms+OPEN_CLOCK_WINDOW_MS){log_line("XTP_SESSION_OPEN_DROPPED peer="+from.text+" reason=open timestamp outside the clock window",now);return;}
            expire_open_nonces(nowms);
            nk.assign(nonce_i.begin(),nonce_i.end());
            if(open_nonces.count(nk)){log_line("XTP_SESSION_OPEN_DROPPED peer="+from.text+" reason=replayed open",now);return;}
        }
        const uint8_t*ok=key?okey.data():nullptr;const CipherSuite suite=key?key->suite:CipherSuite::Aes256Gcm;
        if(uint8_t(requested)<uint8_t(required)){refuse(f,from,DIAG_AUTH_REQUIRED,std::string("service ")+f.service_name+" requires "+protection_name(required),trigger,ok,suite);return;}
        if(!(f.service_flags&XTP_SERVICE_FLAG_INTERACTIVE)){refuse(f,from,DIAG_MODE_UNSUPPORTED,"FIRST without INTERACTIVE at a session listener",trigger,ok,suite);return;}
        if(!accepting||f.service_name.empty()||!admitted(f.service_name)){refuse(f,from,DIAG_SERVICE_NOT_ADMITTED,"named service not admitted: "+f.service_name,trigger,ok,suite);return;}
        if(cores.size()>=lo.max_sessions||backlog.size()>=lo.accept_backlog){refuse(f,from,DIAG_QUOTA_EXCEEDED,"session table or accept backlog full",trigger,ok,suite);return;}
        if(key){
            // admitted: only now does the nonce take a place in the cache
            size_t&mine=open_nonces_per_key[key->key_id];
            if(open_nonces.size()>=OPEN_NONCE_CAP||mine>=OPEN_NONCE_CAP_PER_KEY){log_line("XTP_SESSION_OPEN_DROPPED peer="+from.text+" service="+f.service_name+" reason=open replay cache full for key "+std::to_string(key->key_id),now);return;}
            ++mine;open_nonces.insert(nk);open_nonce_q.emplace_back(security::now_ms()+OPEN_NONCE_TTL_MS,nk,key->key_id);
        }
        auto c=std::make_shared<SCore>();
        c->key=f.key;c->initiator=false;c->little=f.little;c->prio=f.priority;c->peer=from;c->service=f.service_name;
        c->tun=lo;c->seg=session_segment(route,lo);c->st=SCore::OPEN;
        c->sync_base=random31();c->sync_last=c->sync_base;
        c->created=c->last_heard=c->last_ka=c->progress_at=now;
        if(key){
            c->prot=requested;c->suite=key->suite;c->key_id=key->key_id;c->key_principal=key->principal;c->nonce_i=nonce_i;
            auto r=security::random_bytes(16);std::copy(r.begin(),r.end(),c->nonce_r.begin());
            std::vector<uint8_t> salt(c->nonce_i.begin(),c->nonce_i.end());salt.insert(salt.end(),c->nonce_r.begin(),c->nonce_r.end());
            auto okm=security::hkdf_sha256(key->secret.data(),32,salt,label("XTP-CTX-1",c->service,c->key,{uint8_t(c->prot),uint8_t(c->suite)}),64);
            std::copy(okm.begin()+32,okm.end(),c->tx_key.begin());std::copy(okm.begin(),okm.begin()+32,c->rx_key.begin());
            OPENSSL_cleanse(okm.data(),okm.size());
            c->confirmed=false;c->open_pkt=raw;    // offered to accept() once the opener proves its key
            c->open_retry_at=now+std::chrono::milliseconds(250);
        }
        cores[{from.text,f.key}]=c;if(c->confirmed)backlog.push_back(c);
        send_first(*c);send_cntl(*c,true,now);
        cv.notify_all();
    }
    void on_cntl(SCore&c,const Cntl&q,STime now){
        if(c.st==SCore::FAILED){if(!(q.flags&TRAIL_END))resend_abort(c,now);return;}
        // Once the peer has echoed one of our SYNCs, its END (graceful or
        // abort) must echo one too: our own ENDs always carry the peer's last
        // SYNC.  This stops a blind forger, not an on-path one (docs/SESSIONS.md).
        if((q.flags&TRAIL_END)&&c.peer_echoed&&!c.in_context(q.echo)){++c.stale_ignored;return;}
        if(q.flags&TRAIL_END){
            if((q.flags&(TRAIL_RCLOSE|TRAIL_WCLOSE))==(TRAIL_RCLOSE|TRAIL_WCLOSE)){
                // Graceful END: the peer has everything we sent, including our WCLOSE.
                const bool was_done=c.st==SCore::DONE;
                c.peer_end=true;
                if(q.flags&TRAIL_SREQ)c.peer_sync=q.sync;
                if(c.st==SCore::OPEN&&c.wclose_sent){c.wclose_acked=true;c.peer_rseq=c.snd_nxt;c.inflight.clear();c.rto_armed=false;check_done(c,now);}
                // A finished end resends its END with SREQ until the peer's END
                // arrives; answer such a retry (it is how a lost END is
                // repaired).  An END without SREQ is never answered, so two
                // finished ends cannot bounce ENDs back and forth.
                if(c.st==SCore::DONE){if(was_done&&(q.flags&TRAIL_SREQ))send_cntl(c,false,now);cv.notify_all();return;}
            }
            else{fail(c,"XTP context aborted by peer",false,now);return;}
        }
        if(c.st==SCore::DONE){if(q.flags&TRAIL_SREQ)c.peer_sync=q.sync;send_cntl(c,false,now);cv.notify_all();return;}
        if(c.st!=SCore::OPEN)return;
        if(q.echo){
            if(!c.in_context(q.echo)){++c.stale_ignored;return;}
            c.peer_echoed=true;
            auto st=c.sync_times.find(q.echo);
            if(st!=c.sync_times.end()){
                const double sample=std::chrono::duration<double,std::milli>(now-st->second).count();
                c.srtt=c.srtt<0?sample:0.875*c.srtt+0.125*sample;c.stats.srtt_ms=c.srtt;
                c.sync_times.erase(c.sync_times.begin(),std::next(st));
            }
        }else if(c.peer_echoed&&!(q.flags&TRAIL_END)){++c.stale_ignored;return;}
        // RSEQ is believed only up to what we have sent, and only at a segment
        // boundary.  An RSEQ inside a segment we still hold (a < RSEQ < z) is
        // taken as that segment's start, so its bytes are never freed early.
        uint64_t r=std::min<uint64_t>(q.rseq,c.snd_nxt);
        {auto it=c.inflight.upper_bound(r);if(it!=c.inflight.begin()){--it;if(it->second.a<r&&r<it->second.z)r=it->second.a;}}
        if(r>c.peer_rseq){c.peer_rseq=r;c.progress_at=now;c.backoff=0;}
        if(q.alloc>c.peer_alloc)c.peer_alloc=q.alloc;
        c.peer_spans=q.spans;
        if((q.flags&TRAIL_RCLOSE)&&c.wclose_sent&&c.peer_rseq>=c.written){if(!c.wclose_acked)c.progress_at=now;c.wclose_acked=true;}
        for(auto it=c.inflight.begin();it!=c.inflight.end();){if(c.covered(it->second))it=c.inflight.erase(it);else ++it;}
        // Free acknowledged bytes, but never bytes a held segment still needs.
        const uint64_t keep=c.inflight.empty()?c.peer_rseq:std::min(c.peer_rseq,c.inflight.begin()->second.a);
        while(c.sbase<keep&&!c.sbuf.empty()){c.sbuf.pop_front();++c.sbase;}
        if(c.inflight.empty())c.rto_armed=false;
        else if(c.progress_at==now){c.rto_at=now+std::chrono::milliseconds(c.rto_ms());c.rto_armed=true;}
        // dev29 exact repair: whatever was sent before the echoed SYNC and is
        // still not covered was lost.
        if(q.echo){
            size_t resent=0;
            for(auto&kv:c.inflight){SOut&s=kv.second;if(s.a<c.peer_alloc+1&&c.sync_le(s.sync,q.echo)&&!c.covered(s)){send_seg(c,s,now);++resent;}}
            if(resent){c.stats.retransmitted_packets+=resent;send_cntl(c,true,now);}
        }
        if(q.flags&TRAIL_SREQ){c.peer_sync=q.sync;c.need_cntl=true;}
        check_done(c,now);
        transmit(c,now);
    }
    void on_data(SCore&c,const PayloadPacket&f,STime now){
        if(c.st==SCore::DONE){send_cntl(c,false,now);return;}
        if(c.st==SCore::FAILED){resend_abort(c,now);return;}
        if(c.initiator&&f.first){
            if(c.st==SCore::OPENING){
                if(!(f.service_flags&XTP_SERVICE_FLAG_INTERACTIVE)){fail(c,"XTP peer answered without an interactive context",true,now);return;}
                c.st=SCore::OPEN;c.progress_at=now;cv.notify_all();
            }
            c.need_cntl=true;
        }
        if(c.st!=SCore::OPEN)return;
        if(!c.initiator&&f.first){c.need_cntl=true;send_first(c);}   // our accept was lost: send it again
        const uint64_t a=f.seq,n=f.data.size(),z=a+n;const uint8_t fl=f.trailer;
        if(z>c.delivered+c.tun.receive_window){c.need_cntl=true;return;}  // beyond the window we offered
        if((fl&TRAIL_WCLOSE)&&!c.peer_wclose){c.peer_wclose=true;c.peer_wclose_at=z;}
        if(z<=c.rcv_nxt){if(n||(fl&TRAIL_WCLOSE))c.need_cntl=true;}
        else if(a<=c.rcv_nxt){
            c.deliver(f.data.data()+(c.rcv_nxt-a),size_t(z-c.rcv_nxt),(fl&TRAIL_EOM)!=0);c.rcv_nxt=z;
            while(!c.ooo.empty()){
                auto it=c.ooo.begin();if(it->first>c.rcv_nxt)break;
                const uint64_t z2=it->first+it->second.first.size();
                if(z2>c.rcv_nxt)c.deliver(it->second.first.data()+(c.rcv_nxt-it->first),size_t(z2-c.rcv_nxt),(it->second.second&TRAIL_EOM)!=0);
                else if(z2==c.rcv_nxt&&(it->second.second&TRAIL_EOM))c.deliver(nullptr,0,true);
                c.rcv_nxt=std::max(c.rcv_nxt,z2);c.ooo_bytes-=it->second.first.size();c.ooo.erase(it);
            }
            if(!c.ooo.empty())c.need_cntl=true;
        }else{
            // Out of order.  Kept only if it overlaps nothing already held and
            // stays within the window and MAX_OOO_SEGMENTS: an unauthenticated
            // peer cannot grow this map, or the SPAN walk, beyond those bounds.
            // A segment not kept is simply resent by a correct sender.
            bool keep=n>0&&c.ooo.size()<MAX_OOO_SEGMENTS&&c.ooo_bytes+n<=c.tun.receive_window;
            if(keep){
                auto nx=c.ooo.lower_bound(a);
                if(nx!=c.ooo.end()&&nx->first<z)keep=false;
                if(keep&&nx!=c.ooo.begin()){auto pv=std::prev(nx);if(pv->first+pv->second.first.size()>a)keep=false;}
            }
            if(keep){c.ooo[a]={f.data,fl};c.ooo_bytes+=n;}
            c.need_cntl=true;   // report the SPAN at once
        }
        if(fl&TRAIL_SREQ)c.need_cntl=true;
        if(c.rcv_nxt>=c.rseq_adv+2*c.seg)c.need_cntl=true;
        if(c.peer_input_complete())c.need_cntl=true;
        check_done(c,now);
        transmit(c,now);
        cv.notify_all();
    }
    // dev32: the initiator's side of a protected accept: check the accept
    // block, derive the context keys and verify the accept's tail with them.
    bool take_accept(SCore&c,const PayloadPacket&f,const std::vector<uint8_t>&raw,STime now){
        if(protection_of(f.service_flags)!=c.prot)return false;
        const uint8_t*b=f.data.data();
        if(f.data.size()<ACCEPT_BLOCK+TAIL||!std::equal(XSEC_MAGIC.begin(),XSEC_MAGIC.end(),b)||b[4]!=1||b[5]!=uint8_t(c.suite)||b[6]!=uint8_t(c.prot))return false;
        std::array<uint8_t,16> nonce_r{};std::copy(b+8,b+24,nonce_r.begin());
        std::vector<uint8_t> salt(c.nonce_i.begin(),c.nonce_i.end());salt.insert(salt.end(),nonce_r.begin(),nonce_r.end());
        auto okm=security::hkdf_sha256(c.lt_secret.data(),32,salt,label("XTP-CTX-1",c.service,c.key,{uint8_t(c.prot),uint8_t(c.suite)}),64);
        std::array<uint8_t,32> tx{},rx{};std::copy(okm.begin(),okm.begin()+32,tx.begin());std::copy(okm.begin()+32,okm.end(),rx.begin());OPENSSL_cleanse(okm.data(),okm.size());
        auto copy=raw;auto toff=payload_tail_off(copy);
        auto ctr=toff?unprotect(copy,c.suite,rx.data(),DIR_R2I,*toff,*toff,0):std::nullopt;
        if(!ctr||!c.rx_win.accept(*ctr)){OPENSSL_cleanse(tx.data(),32);OPENSSL_cleanse(rx.data(),32);++c.stats.auth_failures;return false;}
        c.tx_key=tx;c.rx_key=rx;c.nonce_r=nonce_r;OPENSSL_cleanse(c.lt_secret.data(),32);OPENSSL_cleanse(tx.data(),32);OPENSSL_cleanse(rx.data(),32);
        (void)now;return true;
    }
    // dev32: verify (and for DATA in encrypt mode, decrypt) a packet of a
    // protected context in place.  False: drop it.
    bool verify(SCore&c,std::vector<uint8_t>&pkt,uint8_t type){
        std::optional<size_t> toff;size_t enc_len=0;
        if(type==TYPE_CNTL){if(pkt.size()<HEADER+CONTROL+TAIL+TRAILER)return false;toff=pkt.size()-TRAILER-TAIL;}
        else{toff=payload_tail_off(pkt);if(toff&&type==TYPE_DATA&&c.prot==Protection::Encrypt)enc_len=*toff-HEADER;}
        if(!toff){++c.stats.auth_failures;return false;}
        auto ctr=unprotect(pkt,c.suite,c.rx_key.data(),c.rx_dir(),*toff,HEADER,enc_len);
        if(!ctr){++c.stats.auth_failures;return false;}
        if(!c.rx_win.accept(*ctr)){++c.stats.replays_rejected;return false;}
        if(!c.confirmed)confirm(c,SClock::now());
        if(enc_len){   // decrypted in place: make the checksums match the plaintext for the parser
            const bool l=(pkt[0]&0x80)!=0;const size_t t=pkt.size()-TRAILER;
            put32(pkt,t,checksum32(pkt.data()+HEADER,t-HEADER),l);seal(pkt,t,l);
        }
        return true;
    }
    void on_packet(const std::vector<uint8_t>&in,const SPeer&from,STime now){
        if(in.size()<HEADER+TRAILER)return;
        const bool l=(in[0]&0x80)!=0;const uint8_t type=uint8_t(in[0]&0x1f);
        const uint32_t wk=get32(in.data(),4,l);const bool ret=(wk&0x80000000U)!=0;const uint32_t key=wk&0x7fffffffU;
        if(listening==ret)return;   // our own packets, or another context's direction
        std::shared_ptr<SCore> core;
        if(listening){auto it=cores.find({from.text,key});if(it!=cores.end())core=it->second;}
        else{
            if(!same_session_peer(car->layer,from,initiator_peer)){log_line("XTP_FOREIGN_CONTROL_IGNORED carrier=session from="+from.text,now);return;}
            for(auto&kv:cores)if(kv.second->key==key)core=kv.second;
        }
        if(type==TYPE_DIAG){
            // A DIAG refuses a context being opened.  Only an opener is refused,
            // and only while it is opening; an established context ignores DIAG.
            // dev32: a protected opener believes only a DIAG under its open key.
            if(listening||!core||core->st!=SCore::OPENING)return;
            auto pkt=in;
            if(core->guarded()){
                auto toff=payload_tail_off(pkt);auto ctr=toff?unprotect(pkt,core->suite,core->open_key.data(),DIR_REFUSE,*toff,*toff,0):std::nullopt;
                if(!ctr||*ctr!=0){
                    auto d=parse_diag(in.data(),in.size());
                    if(d)core->unauthenticated_refusal=diag_value_name(d->value);
                    ++core->stats.auth_failures;return;
                }
                // verified: CODE and VALUE are the first 8 bytes; the tail follows the reason
                const uint32_t code=get32(pkt.data(),HEADER,l),value=get32(pkt.data(),HEADER+4,l);
                fail(*core,std::string("XTP context refused by peer: ")+diag_value_name(value)+" (code="+std::to_string(code)+" value="+std::to_string(value)+", authenticated)",false,now);return;
            }
            auto d=parse_diag(pkt.data(),pkt.size());if(!d)return;
            const char*name=diag_value_name(d->value);
            fail(*core,std::string("XTP context refused by peer: ")+name+" (code="+std::to_string(d->code)+" value="+std::to_string(d->value)+")",false,now);return;
        }
        if(type==TYPE_CNTL){
            if(!core)return;
            auto pkt=in;
            if(core->guarded()&&(core->st==SCore::OPENING||!verify(*core,pkt,TYPE_CNTL)))return;
            auto q=parse_cntl(pkt.data(),pkt.size());if(!q)return;
            core->last_heard=now;core->stats.packets_received++;on_cntl(*core,*q,now);return;
        }
        if(type!=TYPE_FIRST&&type!=TYPE_DATA)return;
        auto f=parse_payload_packet(in.data(),in.size());if(!f)return;
        if(!core){
            if(listening&&f->first&&f->seq==0)open_from_first(*f,in,from,now);
            return;
        }
        if(core->guarded()){
            if(f->first){
                if(listening){
                    // The opener resent its FIRST because our accept was lost.  Believed
                    // only while unconfirmed, only byte-identical to the open that
                    // verified, never as a sign of life, and answered a bounded number
                    // of times (review M3).  Once confirmed, the opener has our accept.
                    if(core->confirmed||in!=core->open_pkt||core->accept_resends>=MAX_ACCEPT_RESENDS)return;
                    ++core->accept_resends;send_first(*core);core->need_cntl=true;transmit(*core,now);return;
                }
                if(core->st!=SCore::OPENING){
                    // the responder resent its accept: it has not heard us yet
                    if(in==core->accept_pkt&&core->accept_answers<MAX_ACCEPT_RESENDS&&core->st==SCore::OPEN){++core->accept_answers;send_cntl(*core,false,now);}
                    return;
                }
                if(!take_accept(*core,*f,in,now))return;
                core->accept_pkt=in;
                f->data.clear();                                    // the accept carries no user data
            }else{
                if(core->st==SCore::OPENING)return;
                auto pkt=in;if(!verify(*core,pkt,TYPE_DATA))return;
                f=parse_payload_packet(pkt.data(),pkt.size());if(!f||f->data.size()<TAIL)return;
                f->data.resize(f->data.size()-TAIL);
            }
        }
        core->last_heard=now;core->stats.packets_received++;on_data(*core,*f,now);
    }
    void timers(SCore&c,STime now){
        using std::chrono::milliseconds;
        if(c.st==SCore::OPENING){
            if(now-c.created>=milliseconds(c.open_timeout_ms)){fail(c,"XTP interactive context not accepted by peer within "+std::to_string(c.open_timeout_ms)+" ms ("+(c.guarded()?(c.unauthenticated_refusal.empty()?std::string("unreachable, not a dev32 SessionListener, or the peer does not hold key ")+std::to_string(c.key_id):"an unauthenticated refusal ("+c.unauthenticated_refusal+") was ignored: the peer may not hold key "+std::to_string(c.key_id)):std::string("unreachable, or not a dev31 SessionListener"))+")",false,now);return;}
            if(now>=c.open_retry_at){send_first(c);send_cntl(c,true,now);c.open_backoff=std::min(c.open_backoff+1,3);c.open_retry_at=now+milliseconds(250<<c.open_backoff);}
            return;
        }
        // Finished, but the peer's END has not arrived (ours or its may have
        // been lost): resend ours with SREQ, which the peer answers.
        if(c.st==SCore::DONE&&!c.peer_end&&now>=c.end_retry_at&&now-c.done_at<milliseconds(c.tun.close_linger_ms)){
            send_cntl(c,true,now);c.end_retry_at=now+milliseconds(c.rto_ms());return;
        }
        if(c.st!=SCore::OPEN)return;
        if(!c.confirmed){
            // responder, protected, the opener has not yet proved its key
            if(now-c.created>=milliseconds(UNCONFIRMED_TIMEOUT_MS)){fail(c,"XTP protected open never confirmed by the opener (a replayed open, or the opener went away)",false,now);return;}
            if(now>=c.open_retry_at&&c.accept_resends<MAX_ACCEPT_RESENDS){++c.accept_resends;send_first(c);send_cntl(c,true,now);c.open_backoff=std::min(c.open_backoff+1,3);c.open_retry_at=now+milliseconds(250<<c.open_backoff);}
            return;
        }
        if(now-c.last_heard>=milliseconds(c.tun.dead_after_ms)){fail(c,"XTP context timed out: nothing heard from the peer for "+std::to_string(c.tun.dead_after_ms)+" ms",true,now);return;}
        if(c.rto_armed&&now>=c.rto_at){
            if(now-c.progress_at>=milliseconds(c.tun.dead_after_ms)){fail(c,"XTP context timed out: the peer stopped acknowledging for "+std::to_string(c.tun.dead_after_ms)+" ms",true,now);return;}
            size_t resent=0;
            for(auto&kv:c.inflight){SOut&s=kv.second;if(!c.covered(s)&&s.a<=c.peer_alloc){send_seg(c,s,now);++resent;}}
            c.stats.retransmitted_packets+=resent;
            c.backoff=std::min(c.backoff+1,16);send_cntl(c,true,now);
            c.rto_at=now+milliseconds(c.rto_ms());
        }
        if(c.written>c.snd_nxt&&c.snd_nxt>=c.peer_alloc&&now>=c.probe_at){   // window closed: ask for an update
            send_cntl(c,true,now);c.probe_at=now+milliseconds(std::max(c.rto_ms(),200));
        }
        if(now-c.last_heard>=milliseconds(c.tun.keepalive_ms)&&now-c.last_ka>=milliseconds(c.tun.keepalive_ms)){
            send_cntl(c,true,now);c.last_ka=now;c.stats.keepalives_sent++;
        }
        if(c.need_cntl)send_cntl(c,false,now);
    }
    // Review L4: a context ends when its key is revoked, expires or leaves the
    // key table.  A RETIRING key is still valid, so rotation does not end
    // sessions; removing the key does.  Checked about once a second.
    void check_keys(STime now){
        for(auto&kv:cores){
            SCore&c=*kv.second;
            if(!c.guarded()||(c.st!=SCore::OPEN&&c.st!=SCore::OPENING))continue;
            if(!KeyTable::global().valid(c.key_id,c.service))
                fail(c,"XTP key "+std::to_string(c.key_id)+" of service "+c.service+" was revoked or expired; the context is closed",c.st==SCore::OPEN,now);
        }
    }
    int next_wait_ms(STime now) const{
        STime next=now+std::chrono::milliseconds(50);
        for(const auto&kv:cores){
            const SCore&c=*kv.second;
            if(c.st==SCore::OPENING||(c.st==SCore::OPEN&&!c.confirmed))next=std::min(next,c.open_retry_at);
            if(c.st==SCore::OPEN&&c.rto_armed)next=std::min(next,c.rto_at);
            if(c.st==SCore::DONE&&!c.peer_end)next=std::min(next,c.end_retry_at);
        }
        return int(std::max<int64_t>(1,std::chrono::duration_cast<std::chrono::milliseconds>(next-now).count()));
    }
    void run(){
        std::vector<uint8_t> pkt;SPeer from;
        while(!stop){
            int wait;{std::lock_guard<std::mutex> g(m);wait=next_wait_ms(SClock::now());}
            if(car->recv(pkt,from,wait)){
                std::lock_guard<std::mutex> g(m);on_packet(pkt,from,SClock::now());
                for(int i=0;i<256&&car->recv(pkt,from,0);++i)on_packet(pkt,from,SClock::now());
            }
            std::lock_guard<std::mutex> g(m);const auto now=SClock::now();
            if(now-keys_checked>=std::chrono::seconds(1)){keys_checked=now;check_keys(now);}
            for(auto it=cores.begin();it!=cores.end();){
                SCore&c=*it->second;timers(c,now);
                const bool finished=(c.st==SCore::DONE||c.st==SCore::FAILED)&&now-c.done_at>=std::chrono::milliseconds(c.tun.close_linger_ms);
                if(listening&&finished)it=cores.erase(it);else ++it;
            }
        }
    }
};

} // namespace detail

struct Session::Impl{
    std::shared_ptr<detail::SEndpoint> ep;std::shared_ptr<detail::SCore> core;
    Impl(std::shared_ptr<detail::SEndpoint> e,std::shared_ptr<detail::SCore> c):ep(std::move(e)),core(std::move(c)){}
    ~Impl(){
        std::unique_lock<std::mutex> lk(ep->m);
        if(core->st==detail::SCore::OPEN||core->st==detail::SCore::OPENING)ep->fail(*core,"XTP context aborted locally (Session destroyed without close)",true,detail::SClock::now());
        // Finished, but the peer has not confirmed: linger as close() does, so
        // that a lost final END is still answered before our socket goes.
        else if(core->st==detail::SCore::DONE&&!core->peer_end)ep->cv.wait_for(lk,std::chrono::milliseconds(core->tun.close_linger_ms),[&]{return core->peer_end;});
    }
};

namespace {
template<class Pred>
bool wait_on(detail::SEndpoint&ep,std::unique_lock<std::mutex>&lk,int timeout_ms,Pred p){
    if(timeout_ms<0){ep.cv.wait(lk,p);return true;}
    return ep.cv.wait_for(lk,std::chrono::milliseconds(timeout_ms),p);
}
}

Session::Session(std::shared_ptr<Impl> impl):impl_(std::move(impl)){}
Session::~Session()=default;

void Session::write(const std::vector<uint8_t>&data,bool eom,int timeout_ms){
    auto&ep=*impl_->ep;auto&c=*impl_->core;
    if(eom&&data.empty())throw std::invalid_argument("XTP session write with eom needs at least one byte");
    std::unique_lock<std::mutex> lk(ep.m);
    if(c.wclose_req)throw std::runtime_error("XTP session write after shutdown_write");
    const auto deadline=detail::SClock::now()+std::chrono::milliseconds(timeout_ms<0?0:timeout_ms);
    size_t pos=0;
    while(pos<data.size()){
        if(c.st!=detail::SCore::OPEN)throw std::runtime_error(c.error.empty()?"XTP session is closed":c.error);
        const size_t held=size_t(c.written-c.sbase);
        if(held>=c.tun.send_buffer_bytes){
            auto ready=[&]{return c.st!=detail::SCore::OPEN||size_t(c.written-c.sbase)<c.tun.send_buffer_bytes;};
            if(timeout_ms<0)ep.cv.wait(lk,ready);
            else if(!ep.cv.wait_until(lk,deadline,ready))throw std::runtime_error("XTP session write timed out: the peer is not reading");
            continue;
        }
        const size_t n=std::min(data.size()-pos,c.tun.send_buffer_bytes-held);
        if(c.written+n>detail::SESSION_MAX_OFFSET)throw std::runtime_error("XTP session sequence space (2^32-1 bytes per direction) exhausted; open a new session");
        c.sbuf.insert(c.sbuf.end(),data.begin()+long(pos),data.begin()+long(pos+n));c.written+=n;pos+=n;c.stats.bytes_written+=n;
        if(pos==data.size()&&eom)c.eoms.insert(c.written);
        ep.transmit(c,detail::SClock::now());
    }
}

SessionChunk Session::read(size_t max_bytes,int timeout_ms){
    auto&ep=*impl_->ep;auto&c=*impl_->core;
    if(max_bytes==0)throw std::invalid_argument("XTP session read of 0 bytes");
    std::unique_lock<std::mutex> lk(ep.m);
    auto ready=[&]{return c.ready_bytes>0||(c.ready.size()&&c.ready.front().eom)||c.peer_input_complete()||c.st==detail::SCore::FAILED;};
    if(!wait_on(ep,lk,timeout_ms,ready))return {};
    SessionChunk out;
    if(!c.ready.empty()){
        auto&f=c.ready.front();const size_t n=std::min(max_bytes,f.data.size());
        out.data.assign(f.data.begin(),f.data.begin()+long(n));
        if(n==f.data.size()){out.eom=f.eom;c.ready.pop_front();}else f.data.erase(f.data.begin(),f.data.begin()+long(n));
        c.ready_bytes-=n;c.delivered+=n;c.stats.bytes_read+=n;
        if(c.delivered+c.tun.receive_window>=c.alloc_adv+c.tun.receive_window/4)c.need_cntl=true;   // window update
        if(c.need_cntl&&c.st!=detail::SCore::FAILED)ep.transmit(c,detail::SClock::now());
        return out;
    }
    if(c.st==detail::SCore::FAILED)throw std::runtime_error(c.error);
    out.end=true;return out;
}

void Session::shutdown_write(){
    auto&ep=*impl_->ep;auto&c=*impl_->core;
    std::lock_guard<std::mutex> g(ep.m);
    if(c.wclose_req||c.st!=detail::SCore::OPEN)return;
    c.wclose_req=true;ep.transmit(c,detail::SClock::now());
}

bool Session::close(int timeout_ms){
    shutdown_write();
    auto&ep=*impl_->ep;auto&c=*impl_->core;
    std::unique_lock<std::mutex> lk(ep.m);
    const bool done=wait_on(ep,lk,timeout_ms,[&]{return c.st!=detail::SCore::OPEN;});
    if(c.st==detail::SCore::DONE){
        // Linger until the peer has seen our END too (its own END arrives), so a
        // lost END is answered while we still exist.
        wait_on(ep,lk,c.tun.close_linger_ms,[&]{return c.peer_end;});
        return true;
    }
    if(!done)ep.fail(c,"XTP session close timed out: the peer did not close its direction",true,detail::SClock::now());
    return false;
}

void Session::abort(){
    auto&ep=*impl_->ep;auto&c=*impl_->core;
    std::lock_guard<std::mutex> g(ep.m);
    ep.fail(c,"XTP context aborted locally",true,detail::SClock::now());
}

bool Session::is_open() const{std::lock_guard<std::mutex> g(impl_->ep->m);return impl_->core->st==detail::SCore::OPEN;}
bool Session::peer_closed() const{std::lock_guard<std::mutex> g(impl_->ep->m);return impl_->core->peer_input_complete();}
std::string Session::error() const{std::lock_guard<std::mutex> g(impl_->ep->m);return impl_->core->error;}
uint32_t Session::key() const{return impl_->core->key;}
std::string Session::service_name() const{return impl_->core->service;}
std::string Session::peer_address() const{return impl_->core->peer.text;}
Protection Session::protection() const{return impl_->core->prot;}
uint64_t Session::key_id() const{return impl_->core->key_id;}
std::string Session::key_principal() const{return impl_->core->key_principal;}
SessionStats Session::stats() const{std::lock_guard<std::mutex> g(impl_->ep->m);return impl_->core->stats;}

std::unique_ptr<Session> open_session(const Route&route,const SessionOptions&o){
    if(o.service_name.empty())throw std::invalid_argument("XTP open_session needs a named service");
    if(!valid_service_name(o.service_name))throw std::invalid_argument("invalid XTP named service: "+o.service_name);
    SessionListenOptions eo;static_cast<SessionTuning&>(eo)=o;
    auto ep=std::make_shared<detail::SEndpoint>(route,false,eo);
    auto c=std::make_shared<detail::SCore>();
    c->key=(o.key&0x7fffffffU)?(o.key&0x7fffffffU):detail::random31();c->initiator=true;c->little=o.little_endian;c->prio=o.priority;
    c->peer=detail::route_peer(route);c->service=o.service_name;c->tun=o;c->seg=detail::session_segment(route,o);c->open_timeout_ms=o.open_timeout_ms;
    c->sync_base=detail::random31();c->sync_last=c->sync_base;
    // dev32: protection.  The service's profile from the key table, or what the
    // caller demands if that is stronger; the key is the newest active one.
    // The option is a minimum (review L3): "none" never lowers the service's profile.
    Protection want=KeyTable::global().required(o.service_name);
    if(o.protection&&uint8_t(*o.protection)>uint8_t(want))want=*o.protection;
    if(want!=Protection::None){
        auto k=KeyTable::global().for_open(o.service_name,o.key_principal);
        if(!k)throw std::runtime_error("XTP: no active key for service "+o.service_name+" (it needs "+protection_name(want)+")");
        if(uint8_t(k->protection)>uint8_t(want))want=k->protection;
        c->prot=want;c->suite=k->suite;c->key_id=k->key_id;c->key_principal=k->principal;c->lt_secret=k->secret;
        auto ni=security::random_bytes(16);std::copy(ni.begin(),ni.end(),c->nonce_i.begin());
        auto ok=security::hkdf_sha256(k->secret.data(),32,ni,detail::label("XTP-OPEN-1",c->service,c->key),32);
        std::copy(ok.begin(),ok.end(),c->open_key.begin());OPENSSL_cleanse(ok.data(),ok.size());
    }
    const auto now=detail::SClock::now();c->created=c->last_heard=c->last_ka=c->progress_at=now;
    ep->initiator_peer=c->peer;ep->cores[{c->peer.text,c->key}]=c;
    {
        std::unique_lock<std::mutex> lk(ep->m);
        ep->send_first(*c);ep->send_cntl(*c,true,now);c->open_retry_at=now+std::chrono::milliseconds(250);
        ep->start();
        ep->cv.wait(lk,[&]{return c->st!=detail::SCore::OPENING;});
        if(c->st!=detail::SCore::OPEN)throw std::runtime_error(c->error);
        ep->transmit(*c,detail::SClock::now());
    }
    return std::make_unique<Session>(std::make_shared<Session::Impl>(ep,c));
}

struct SessionListener::Impl{
    std::shared_ptr<detail::SEndpoint> ep;
    ~Impl(){
        if(!ep)return;
        std::lock_guard<std::mutex> g(ep->m);ep->accepting=false;
        for(auto&c:ep->backlog)ep->fail(*c,"XTP session listener closed before accept",true,detail::SClock::now());
        ep->backlog.clear();ep->cv.notify_all();
    }
};
SessionListener::SessionListener(const Route&route,const SessionListenOptions&o){
    // Build the endpoint first: if the socket cannot be opened (port in use,
    // no CAP_NET_RAW, unknown interface) this throws before any Impl exists.
    auto ep=std::make_shared<detail::SEndpoint>(route,true,o);
    impl_=std::make_shared<Impl>();impl_->ep=ep;ep->start();
}
SessionListener::~SessionListener()=default;
std::unique_ptr<Session> SessionListener::accept(int timeout_ms){
    auto&ep=*impl_->ep;
    std::unique_lock<std::mutex> lk(ep.m);
    if(!wait_on(ep,lk,timeout_ms,[&]{return !ep.backlog.empty()||!ep.accepting;}))return nullptr;
    if(ep.backlog.empty())return nullptr;
    auto c=ep.backlog.front();ep.backlog.pop_front();c->accepted=true;
    return std::make_unique<Session>(std::make_shared<Session::Impl>(impl_->ep,c));
}
void SessionListener::close(){
    auto&ep=*impl_->ep;std::lock_guard<std::mutex> g(ep.m);
    ep.accepting=false;
    for(auto&c:ep.backlog)ep.fail(*c,"XTP session listener closed before accept",true,detail::SClock::now());
    ep.backlog.clear();ep.cv.notify_all();
}
size_t SessionListener::contexts() const{std::lock_guard<std::mutex> g(impl_->ep->m);return impl_->ep->cores.size();}

} // namespace xtp
