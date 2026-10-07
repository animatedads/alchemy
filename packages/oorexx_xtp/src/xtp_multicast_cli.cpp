#include "xtp/xtp_socket.hpp"
#include <iostream>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

int main(int argc,char**argv){try{
    if(argc<3){std::cerr<<"usage: xtp-multicast send|listen GROUP [options]\n";return 2;}
    std::string op=argv[1],peer=argv[2];xtp::SocketProvider provider;
    if(op=="send"){
        std::string message;std::string input_file;xtp::MulticastOptions o;
        for(int i=3;i<argc;++i){std::string a=argv[i];if(a=="--message"&&i+1<argc)message=argv[++i];else if(a=="--file"&&i+1<argc)input_file=argv[++i];else if(a=="--expected"&&i+1<argc)o.expected_receivers=std::stoul(argv[++i]);else if(a=="--timeout-ms"&&i+1<argc)o.timeout_ms=std::stoi(argv[++i]);else if(a=="--retries"&&i+1<argc)o.retries=std::stoi(argv[++i]);else if(a=="--key"&&i+1<argc)o.key=uint32_t(std::stoul(argv[++i]));else if(a=="--noerr")o.reliable=false;else if(a=="--ttl"&&i+1<argc)o.ttl=std::stoi(argv[++i]);else if(a=="--segment-bytes"&&i+1<argc)o.segment_bytes=std::stoul(argv[++i]);else if(a=="--no-rate-pacing")o.rate_pacing=false;else if(a=="--default-rate"&&i+1<argc)o.default_rate_bytes_per_sec=uint32_t(std::stoul(argv[++i]));else if(a=="--default-burst"&&i+1<argc)o.default_burst_bytes=uint32_t(std::stoul(argv[++i]));else throw std::runtime_error("unknown send option: "+a);}
        std::vector<uint8_t>b;
        if(!input_file.empty()){std::ifstream in(input_file,std::ios::binary);if(!in)throw std::runtime_error("cannot open multicast input file: "+input_file);b.assign(std::istreambuf_iterator<char>(in),std::istreambuf_iterator<char>());}
        else b.assign(message.begin(),message.end());
        auto r=provider.send_multicast(peer,b,o);
        std::cout<<"XTP_MULTICAST_OK group="<<peer<<" bytes="<<r.logical_bytes<<" wire_bytes="<<r.wire_bytes<<" attempts="<<r.attempts<<" acks="<<r.acknowledgements<<" required="<<r.required_acknowledgements<<" packets="<<r.packets<<" retransmitted="<<r.retransmitted_packets<<" rollbacks="<<r.rollback_events<<" slowest_rseq="<<r.slowest_rseq<<" slowest_alloc="<<r.slowest_alloc<<" allocation_rounds="<<r.allocation_rounds<<" allocation_stalls="<<r.allocation_stalls<<" slowest_rate="<<r.slowest_rate_bytes_per_sec<<" slowest_burst="<<r.slowest_burst_bytes<<" rate_bursts="<<r.rate_paced_bursts<<" rate_sleep_us="<<r.rate_sleep_microseconds<<"\n";
        for(const auto&x:r.responders) std::cout<<"ACK "<<x<<"\n";
        return 0;
    }
    if(op=="listen"){
        int timeout=0;uint32_t receiveWindow=1024u*1024u;uint32_t advertisedRate=0xffffffffu;uint32_t advertisedBurst=0xffffffffu;int rejectSuppressionMs=20;std::string output_file;for(int i=3;i<argc;++i){std::string a=argv[i];if(a=="--timeout-ms"&&i+1<argc)timeout=std::stoi(argv[++i]);else if(a=="--receive-window"&&i+1<argc)receiveWindow=uint32_t(std::stoul(argv[++i]));else if(a=="--rate"&&i+1<argc)advertisedRate=uint32_t(std::stoul(argv[++i]));else if(a=="--burst"&&i+1<argc)advertisedBurst=uint32_t(std::stoul(argv[++i]));else if(a=="--reject-suppression-ms"&&i+1<argc)rejectSuppressionMs=std::stoi(argv[++i]);else if(a=="--output"&&i+1<argc)output_file=argv[++i];else throw std::runtime_error("unknown listen option: "+a);}xtp::ListenOptions lo;lo.timeout_ms=timeout;lo.receive_window=receiveWindow;lo.advertised_rate_bytes_per_sec=advertisedRate;lo.advertised_burst_bytes=advertisedBurst;lo.reject_suppression_ms=rejectSuppressionMs;auto l=provider.listen_multicast(peer,lo);auto r=l->receive();if(!output_file.empty()){std::ofstream out(output_file,std::ios::binary);if(!out)throw std::runtime_error("cannot open multicast output file: "+output_file);out.write(reinterpret_cast<const char*>(r.logical.data()),std::streamsize(r.logical.size()));std::cout<<"XTP_MULTICAST_DELIVER group="<<peer<<" from="<<r.peer_address<<" bytes="<<r.logical.size()<<" output="<<output_file<<"\n";}else{std::string text(r.logical.begin(),r.logical.end());std::cout<<"XTP_MULTICAST_DELIVER group="<<peer<<" from="<<r.peer_address<<" bytes="<<r.logical.size()<<" data="<<text<<"\n";}return 0;
    }
    throw std::runtime_error("unknown operation");
}catch(const std::exception&e){std::cerr<<"xtp-multicast: "<<e.what()<<"\n";return 1;}}
