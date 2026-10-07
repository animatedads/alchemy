#include "xtp/xtp_socket.hpp"
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>
#include <string>

static void usage(){std::cerr<<"usage: xtp-listen PEER [--count N] [--timeout-ms N] [--hex]\n";}
static std::string hex(const std::vector<uint8_t>& b){std::ostringstream o;o<<std::hex<<std::setfill('0');for(uint8_t v:b)o<<std::setw(2)<<unsigned(v);return o.str();}
int main(int argc,char**argv){try{
 if(argc<2){usage();return 2;}std::string peer=argv[1];std::map<std::string,std::string>o;
 for(int i=2;i<argc;++i){std::string k=argv[i];if(k=="--hex"){o[k]="1";continue;}if(k.rfind("--",0)!=0||i+1>=argc){usage();return 2;}o[k]=argv[++i];}
 int count=o.count("--count")?std::stoi(o["--count"]):1;if(count<1)throw std::runtime_error("count must be positive");xtp::ListenOptions lo;if(o.count("--timeout-ms"))lo.timeout_ms=std::stoi(o["--timeout-ms"]);
 xtp::SocketProvider p;auto listener=p.listen(peer,lo);
 std::cout<<"XTP_LISTEN_READY peer="<<peer<<" layer="<<listener->route().layer<<" carrier="<<listener->route().carrier<<"\n";std::cout.flush();
 int fresh=0;while(fresh<count){auto r=listener->receive();if(r.replay){std::cerr<<"XTP_REPLAY_SUPPRESSED key="<<r.key<<" peer="<<r.peer_address<<"\n";continue;}++fresh;std::cout<<"XTP_ACCEPT key="<<r.key<<" peer="<<r.peer_address<<" bytes="<<r.logical.size()<<" wire_bytes="<<r.wire_bytes<<" endian="<<(r.little_endian?"little":"big")<<" data="<<(o.count("--hex")?hex(r.logical):std::string(r.logical.begin(),r.logical.end()))<<"\n";std::cout.flush();}
 return 0;
}catch(const std::exception&e){std::cerr<<"XTP_LISTEN_ERROR "<<e.what()<<"\n";return 3;}}
