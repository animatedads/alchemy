#include "xtp/xtp_multipath.hpp"
#include <algorithm>
#include <array>
#include <chrono>
#include <cstring>
#include <map>
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
            try{send_message(routes[pi],payload,so);out.paths[pi].delivered_chunks++;if(pi!=assigned){out.paths[pi].replayed_chunks++;out.failovers++;}delivered=true;break;}
            catch(const std::exception&e){last_error=e.what();alive[pi]=false;out.paths[pi].failed=true;out.paths[pi].error=last_error;}
        }
        if(!delivered) throw std::runtime_error("multipath transfer lost chunk "+std::to_string(i)+": "+last_error);
    }
    return out;
}

struct MultipathListener::Impl {
    std::vector<std::unique_ptr<Listener>> listeners;
    struct Assembly {uint32_t generation=0,count=0,total=0;std::vector<std::vector<uint8_t>> chunks;std::vector<bool> have;size_t have_count=0;};
    std::map<uint64_t,Assembly> assemblies;
    explicit Impl(const std::vector<Route>&routes,const ListenOptions&o){
        if(routes.empty())throw std::runtime_error("multipath listener requires at least one route");
        ListenOptions lo=o;if(lo.timeout_ms==0)lo.timeout_ms=40;
        for(const auto&r:routes)listeners.push_back(std::make_unique<Listener>(r,lo));
    }
    MultipathReceiveResult receive(){
        for(;;){
            bool progressed=false;
            for(auto&l:listeners){
                try{
                    auto rr=l->receive();progressed=true;if(rr.replay)continue;auto c=parse(rr.logical);
                    auto it=assemblies.find(c.transfer);
                    if(it==assemblies.end()){
                        Assembly a;a.generation=c.generation;a.count=c.count;a.total=c.total;a.chunks.resize(c.count);a.have.assign(c.count,false);
                        it=assemblies.emplace(c.transfer,std::move(a)).first;
                    }
                    auto&a=it->second;
                    if(a.generation!=c.generation||a.count!=c.count||a.total!=c.total)throw std::runtime_error("XMP1 transfer metadata conflict");
                    if(!a.have[c.index]){a.have[c.index]=true;a.chunks[c.index]=std::move(c.data);a.have_count++;}
                    if(a.have_count==a.count){
                        MultipathReceiveResult out;out.transfer_id=c.transfer;out.generation=a.generation;out.chunks=a.count;out.logical_bytes=a.total;out.logical.reserve(a.total);
                        for(auto&part:a.chunks)out.logical.insert(out.logical.end(),part.begin(),part.end());
                        if(out.logical.size()!=a.total)throw std::runtime_error("XMP1 reassembled size mismatch");
                        assemblies.erase(it);return out;
                    }
                } catch(const std::exception&e){
                    if(std::string(e.what())!="XTP listener timeout")throw;
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
