// Interop tool (public libxtp API only, so it builds against any dev27+ tree).
// usage: stream_send HOST:PORT NBYTES SEED SEGMENT_BYTES TIMEOUT_MS RETRIES
#include "xtp/xtp_transport.hpp"
#include <iostream>
#include <random>
int main(int argc,char**argv){
  if(argc<7){std::cerr<<"usage: stream_send HOST:PORT NBYTES SEED SEGMENT_BYTES TIMEOUT_MS RETRIES\n";return 2;}
  std::mt19937 g(uint32_t(std::stoul(argv[3])));std::vector<uint8_t> v(std::stoul(argv[2]));for(auto&b:v)b=uint8_t(g());
  xtp::Route r;r.peer="peer";r.layer=4;r.carrier="udp";r.destination=argv[1];
  xtp::SendOptions o;o.segment_bytes=std::stoul(argv[4]);o.timeout_ms=std::stoi(argv[5]);o.retries=std::stoi(argv[6]);
  try{auto x=xtp::send_message(r,v,o);std::cout<<"SENT bytes="<<v.size()<<" segments="<<x.segments<<" retransmitted="<<x.retransmitted_packets<<"\n";return 0;}
  catch(const std::exception&e){std::cout<<"SEND_FAILED "<<e.what()<<"\n";return 1;}
}
