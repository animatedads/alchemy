#include "xtp/xtp_multipath.hpp"
#include <algorithm>
#include <array>
#include <chrono>
#include <cstring>
#include <cstdio>
#include <deque>
#include <map>
#include <tuple>
#include <random>
#include <stdexcept>
#include <thread>

namespace xtp {
namespace {
constexpr std::array<uint8_t,4> MAGIC{{'X','M','P','1'}};
constexpr size_t HEADER = 32;

void put32(std::vector<uint8_t>& b,size_t o,uint32_t v){
    b[o]=uint8_t(v>>24);b[o+1]=uint8_t(v>>16);b[o+2]=uint8_t(v>>8);b[o+3]=uint8_t(v);
}
void put64(std::vector<uint8_t>& b,size_t o,uint64_t v){
    for(int i=7;i>=0;--i){b[o+size_t(7-i)]=uint8_t(v>>(i*8));}
}
uint32_t get32(const uint8_t* b,size_t o){return (uint32_t(b[o])<<24)|(uint32_t(b[o+1])<<16)|(uint32_t(b[o+2])<<8)|uint32_t(b[o+3]);}
uint64_t get64(const uint8_t* b,size_t o){uint64_t v=0;for(size_t i=0;i<8;++i)v=(v<<8)|b[o+i];return v;}
uint64_t new_transfer_id(){
    static std::mt19937_64 rng([]{
        auto now=std::chrono::high_resolution_clock::now().time_since_epoch().count();
        std::random_device rd;
        return std::mt19937_64::result_type(now)^std::mt19937_64::result_type(rd());
    }());
    uint64_t v=rng(); return v?v:1;
}
uint32_t chunk_key(uint64_t transfer,uint32_t generation,uint32_t index){
    uint64_t x=transfer^(transfer>>31)^(uint64_t(generation)<<21)^uint64_t(index*0x9e3779b9U);
    uint32_t k=uint32_t(x^(x>>32))&0x7fffffffU;
    return k?k:1;
}
std::vector<uint8_t> frame(uint64_t transfer,uint32_t generation,uint32_t index,uint32_t count,
                           uint64_t total,const uint8_t* p,size_t n){
    if(total>0xffffffffULL) throw std::runtime_error("XMP1 logical transfer exceeds 4GiB profile limit");
    std::vector<uint8_t> b(HEADER+n);
    std::copy(MAGIC.begin(),MAGIC.end(),b.begin());
    put32(b,4,generation);put64(b,8,transfer);put32(b,16,index);put32(b,20,count);put32(b,24,uint32_t(total));put32(b,28,uint32_t(n));
    std::copy(p,p+n,b.begin()+HEADER);return b;
}
struct Chunk {uint64_t transfer=0;uint32_t generation=0,index=0,count=0,total=0;std::vector<uint8_t> data;};
Chunk parse(const std::vector<uint8_t>& b){
    if(b.size()<HEADER||!std::equal(MAGIC.begin(),MAGIC.end(),b.begin())) throw std::runtime_error("not an XMP1 multipath frame");
    Chunk c;c.generation=get32(b.data(),4);c.transfer=get64(b.data(),8);c.index=get32(b.data(),16);c.count=get32(b.data(),20);c.total=get32(b.data(),24);uint32_t n=get32(b.data(),28);
    if(c.count==0||c.index>=c.count||HEADER+size_t(n)!=b.size()) throw std::runtime_error("invalid XMP1 multipath frame");
    c.data.assign(b.begin()+HEADER,b.end());return c;
}
}

MultipathSendResult send_multipath(const std::vector<Route>& input,const std::vector<uint8_t>& logical,const MultipathOptions&o){
    if(input.empty()) throw std::runtime_error("multipath requires at least one route");
    if(o.chunk_bytes==0) throw std::runtime_error("multipath chunk size must be non-zero");
    const size_t path_count=o.max_paths?std::min(o.max_paths,input.size()):input.size();
    if(path_count==0) throw std::runtime_error("multipath has no permitted paths");
    std::vector<Route> routes(input.begin(),input.begin()+path_count);
    const size_t chunks=std::max<size_t>(1,(logical.size()+o.chunk_bytes-1)/o.chunk_bytes);
    const uint64_t tid=o.transfer_id?o.transfer_id:new_transfer_id();
    MultipathSendResult out;out.transfer_id=tid;out.generation=o.generation;out.logical_bytes=logical.size();out.chunk_count=chunks;
    out.paths.reserve(path_count);for(const auto&r:routes){MultipathPathResult pr;pr.route=r;out.paths.push_back(std::move(pr));}
    std::vector<bool> alive(path_count,true);
    for(size_t i=0;i<chunks;++i){
        size_t assigned=i%path_count;out.paths[assigned].assigned_chunks++;
        size_t offset=i*o.chunk_bytes;size_t n=logical.empty()?0:std::min(o.chunk_bytes,logical.size()-offset);
        const uint8_t* p=logical.empty()?reinterpret_cast<const uint8_t*>(""):logical.data()+offset;
        auto payload=frame(tid,o.generation,uint32_t(i),uint32_t(chunks),logical.size(),p,n);
        std::vector<size_t> candidates;candidates.push_back(assigned);
        if(o.replay_over_survivor){for(size_t step=1;step<path_count;++step)candidates.push_back((assigned+step)%path_count);}
        bool delivered=false;std::string last_error;
        for(size_t ci=0;ci<candidates.size();++ci){size_t pi=candidates[ci];if(!alive[pi])continue;
            SendOptions so=o.send;so.key=chunk_key(tid,o.generation,uint32_t(i));
            // dev35: a key or protection refusal is not a path failure (rethrown as is)
            try{send_message(routes[pi],payload,so);out.paths[pi].delivered_chunks++;if(pi!=assigned){out.paths[pi].replayed_chunks++;out.failovers++;}delivered=true;break;}
            catch(const ProtectionError&){throw;}
            catch(const std::exception&e){last_error=e.what();alive[pi]=false;out.paths[pi].failed=true;out.paths[pi].error=last_error;}
        }
        if(!delivered) throw std::runtime_error("multipath transfer lost chunk "+std::to_string(i)+": "+last_error);
    }
    return out;
}

struct MultipathListener::Impl {
    std::vector<std::unique_ptr<Listener>> listeners;
    ListenOptions options;
    // dev35 (fourth review, finding 1): chunk slots are allocated only as
    // chunks arrive, never up front from a claimed count, and every byte held
    // in unfinished transfers counts against one bound for the listener.
    struct Assembly {uint32_t generation=0,count=0,total=0;std::map<uint32_t,std::vector<uint8_t>> chunks;size_t bytes=0;std::string peer;};
    // dev34: a transfer is identified by its id AND the service, protection
    // and key its chunks arrived under, so chunks from different sources (a
    // clear chunk claiming a protected transfer's id, say) never mix.
    // dev37: and the key's serial, so chunks under an old and a new secret never join
    using AssemblyId=std::tuple<uint64_t,std::string,uint8_t,uint64_t,uint64_t>;
    std::map<AssemblyId,Assembly> assemblies;std::deque<AssemblyId> order;
    std::map<std::string,size_t> per_peer;size_t held_bytes=0;
    static constexpr size_t MAX_ASSEMBLIES=1024,MAX_PER_PEER=64;
    static constexpr uint32_t MAX_CHUNKS=1u<<20;
    explicit Impl(const std::vector<Route>&routes,const ListenOptions&o):options(o){
        if(routes.empty())throw std::runtime_error("multipath listener requires at least one route");
        ListenOptions lo=o;if(lo.timeout_ms==0)lo.timeout_ms=40;
        for(const auto&r:routes)listeners.push_back(std::make_unique<Listener>(r,lo));
    }
    // A chunk that is malformed, too large, or inconsistent with its transfer is
    // dropped and logged; it never ends receive() (dev34).
    void drop(const std::string&why){std::fprintf(stderr,"XTP_MULTIPATH_CHUNK_DROPPED reason=%s\n",why.c_str());}
    void forget(std::map<AssemblyId,Assembly>::iterator it){
        held_bytes-=it->second.bytes;
        auto pp=per_peer.find(it->second.peer);if(pp!=per_peer.end()&&--pp->second==0)per_peer.erase(pp);
        auto o=std::find(order.begin(),order.end(),it->first);if(o!=order.end())order.erase(o);   // finding 5: no stale order entries
        assemblies.erase(it);
    }
    MultipathReceiveResult receive(){
        for(;;){
            bool progressed=false;
            for(auto&l:listeners){
                ReceiveResult rr;
                try{rr=l->receive();}
                catch(const std::exception&e){if(std::string(e.what())!="XTP listener timeout")throw;continue;}
                progressed=true;if(rr.replay)continue;
                Chunk c;
                try{c=parse(rr.logical);}catch(const std::exception&e){drop(e.what());continue;}
                if(c.total>options.max_logical_bytes||c.count>MAX_CHUNKS||uint64_t(c.count)>uint64_t(c.total)+1){drop("transfer larger than the listener allows");continue;}
                const AssemblyId id{c.transfer,rr.service_name,uint8_t(rr.protection),rr.key_id,rr.key_serial};
                const std::string peer_host=rr.route.layer==4?rr.peer_address.substr(0,rr.peer_address.rfind(':')):rr.peer_address;   // UDP: host without port
                auto it=assemblies.find(id);
                if(it==assemblies.end()){
                    if(per_peer[peer_host]>=MAX_PER_PEER){drop("too many unfinished transfers from "+peer_host);if(per_peer[peer_host]==0)per_peer.erase(peer_host);continue;}
                    while(assemblies.size()>=MAX_ASSEMBLIES&&!order.empty()){auto old=assemblies.find(order.front());if(old==assemblies.end())order.pop_front();else forget(old);}
                    Assembly a;a.generation=c.generation;a.count=c.count;a.total=c.total;a.peer=peer_host;
                    it=assemblies.emplace(id,std::move(a)).first;order.push_back(id);++per_peer[peer_host];
                }
                auto&a=it->second;
                if(a.generation!=c.generation||a.count!=c.count||a.total!=c.total){drop("XMP1 transfer metadata conflict");continue;}
                if(!a.chunks.count(c.index)){
                    if(a.bytes+c.data.size()>a.total){drop("chunks exceed the transfer's total");continue;}
                    if(held_bytes+c.data.size()>options.max_logical_bytes*2){drop("unfinished transfers hold the listener's limit");continue;}
                    a.bytes+=c.data.size();held_bytes+=c.data.size();a.chunks.emplace(c.index,std::move(c.data));
                }
                if(a.chunks.size()==a.count){
                    MultipathReceiveResult out;out.transfer_id=c.transfer;out.generation=a.generation;out.chunks=a.count;out.logical_bytes=a.total;out.logical.reserve(a.total);
                    out.service_name=rr.service_name;out.protection=rr.protection;out.key_id=rr.key_id;
                    for(auto&part:a.chunks)out.logical.insert(out.logical.end(),part.second.begin(),part.second.end());
                    forget(it);
                    if(out.logical.size()!=out.logical_bytes){drop("XMP1 reassembled size mismatch");continue;}
                    return out;
                }
            }
            if(!progressed)std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }
    void close(){for(auto&l:listeners)l->close();}
};
MultipathListener::MultipathListener(const std::vector<Route>&r,const ListenOptions&o):impl_(std::make_unique<Impl>(r,o)){}
MultipathListener::~MultipathListener()=default;
MultipathListener::MultipathListener(MultipathListener&&) noexcept=default;
MultipathListener& MultipathListener::operator=(MultipathListener&&) noexcept=default;
MultipathReceiveResult MultipathListener::receive(){return impl_->receive();}
void MultipathListener::close(){if(impl_)impl_->close();}

} // namespace xtp
