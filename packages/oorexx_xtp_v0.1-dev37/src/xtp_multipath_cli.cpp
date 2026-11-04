#include "xtp/xtp_socket.hpp"
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

static uint64_t u64(const char* s){return std::stoull(s,nullptr,0);}
static uint32_t u32(const char* s){auto v=std::stoull(s,nullptr,0);if(v>0xffffffffULL)throw std::runtime_error("value out of range");return uint32_t(v);}
int main(int argc,char**argv){
    try{
        if(argc<3){std::cerr<<"usage: xtp-multipath send|listen PEER [options]\n";return 2;}
        std::string op=argv[1],peer=argv[2];xtp::SocketProvider provider;
        if(op=="send"){
            std::string message;xtp::MultipathOptions o;
            for(int i=3;i<argc;++i){std::string a=argv[i];if(a=="--message"&&i+1<argc)message=argv[++i];else if(a=="--chunk"&&i+1<argc)o.chunk_bytes=size_t(u64(argv[++i]));else if(a=="--generation"&&i+1<argc)o.generation=u32(argv[++i]);else if(a=="--transfer-id"&&i+1<argc)o.transfer_id=u64(argv[++i]);else if(a=="--paths"&&i+1<argc)o.max_paths=size_t(u64(argv[++i]));else if(a=="--timeout-ms"&&i+1<argc)o.send.timeout_ms=int(u64(argv[++i]));else if(a=="--retries"&&i+1<argc)o.send.retries=int(u64(argv[++i]));else throw std::runtime_error("bad send option: "+a);}
            std::vector<uint8_t>b(message.begin(),message.end());auto r=provider.send_multipath(peer,b,o);
            std::cout<<"XTP_MULTIPATH_OK peer="<<peer<<" transfer="<<r.transfer_id<<" generation="<<r.generation<<" bytes="<<r.logical_bytes<<" chunks="<<r.chunk_count<<" failovers="<<r.failovers<<" paths="<<r.paths.size()<<"\n";
            for(size_t i=0;i<r.paths.size();++i){auto&p=r.paths[i];std::cout<<"PATH index="<<i<<" layer="<<p.route.layer<<" carrier="<<p.route.carrier<<" assigned="<<p.assigned_chunks<<" delivered="<<p.delivered_chunks<<" replayed="<<p.replayed_chunks<<" failed="<<(p.failed?1:0);if(!p.error.empty())std::cout<<" error="<<p.error;std::cout<<"\n";}return 0;
        }
        if(op=="listen"){
            size_t paths=2;for(int i=3;i<argc;++i){std::string a=argv[i];if(a=="--paths"&&i+1<argc)paths=size_t(u64(argv[++i]));else throw std::runtime_error("bad listen option: "+a);}
            auto l=provider.listen_multipath(peer,paths);auto r=l->receive();std::string s(r.logical.begin(),r.logical.end());
            std::cout<<"XTP_MULTIPATH_DELIVER peer="<<peer<<" transfer="<<r.transfer_id<<" generation="<<r.generation<<" bytes="<<r.logical_bytes<<" chunks="<<r.chunks<<" data="<<s<<"\n";return 0;
        }
        throw std::runtime_error("operation must be send or listen");
    }catch(const std::exception&e){std::cerr<<"xtp-multipath: "<<e.what()<<"\n";return 1;}
}
