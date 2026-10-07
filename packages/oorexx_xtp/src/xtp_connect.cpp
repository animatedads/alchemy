#include "xtp/xtp_socket.hpp"
#include <iostream>
#include <map>
#include <string>
#include <vector>

static void usage(){std::cerr<<"usage: xtp-connect PEER (--message TEXT | --hex HEX) [--key N] [--timeout-ms N] [--retries N]\n";}
static std::vector<uint8_t> from_hex(const std::string& h){
 if(h.size()%2) throw std::runtime_error("hex payload must contain an even number of digits");
 auto nib=[](char c)->uint8_t{if(c>='0'&&c<='9')return uint8_t(c-'0');if(c>='a'&&c<='f')return uint8_t(c-'a'+10);if(c>='A'&&c<='F')return uint8_t(c-'A'+10);throw std::runtime_error("invalid hex payload");};
 std::vector<uint8_t> out; out.reserve(h.size()/2); for(size_t i=0;i<h.size();i+=2) out.push_back(uint8_t((nib(h[i])<<4)|nib(h[i+1]))); return out;
}
int main(int argc,char**argv){try{
 if(argc<4){usage();return 2;}std::string peer=argv[1];std::map<std::string,std::string>o;
 for(int i=2;i<argc;++i){std::string k=argv[i];if(k.rfind("--",0)!=0||i+1>=argc){usage();return 2;}o[k]=argv[++i];}
 if((o.count("--message")?1:0)+(o.count("--hex")?1:0)!=1){usage();return 2;}
 xtp::SendOptions so;if(o.count("--key"))so.key=uint32_t(std::stoul(o["--key"]));if(o.count("--timeout-ms"))so.timeout_ms=std::stoi(o["--timeout-ms"]);if(o.count("--retries"))so.retries=std::stoi(o["--retries"]);
 std::vector<uint8_t>bytes; if(o.count("--hex")) bytes=from_hex(o["--hex"]); else {std::string msg=o["--message"];bytes.assign(msg.begin(),msg.end());} xtp::SocketProvider p;auto r=p.send(peer,bytes,so);
 std::cout<<"XTP_CONNECT_OK peer="<<peer<<" layer="<<r.route.layer<<" carrier="<<r.route.carrier<<" attempts="<<r.attempts<<" bytes="<<r.logical_bytes<<" wire_bytes="<<r.wire_bytes<<" rseq="<<r.rseq<<" dseq="<<r.dseq<<" alloc="<<r.alloc<<" filters="<<r.route.wire_filters<<"\n";return 0;
}catch(const std::exception&e){std::cerr<<"XTP_CONNECT_ERROR "<<e.what()<<"\n";return 3;}}
