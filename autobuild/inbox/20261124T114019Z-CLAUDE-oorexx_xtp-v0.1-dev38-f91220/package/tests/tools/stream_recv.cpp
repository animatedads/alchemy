// usage: stream_recv HOST:PORT NBYTES SEED TIMEOUT_MS   (exit 0 only on a byte-exact delivery)
// After delivering, it keeps serving until the line has been quiet for 1.5 s,
// as a real listener does, so that a sender whose final close-ACK was lost can
// still be answered.
#include "xtp/xtp_transport.hpp"
#include <chrono>
#include <iostream>
#include <random>
int main(int argc,char**argv){
  if(argc<5){std::cerr<<"usage: stream_recv HOST:PORT NBYTES SEED TIMEOUT_MS\n";return 2;}
  std::mt19937 g(uint32_t(std::stoul(argv[3])));std::vector<uint8_t> v(std::stoul(argv[2]));for(auto&b:v)b=uint8_t(g());
  xtp::Route r;r.peer="self";r.layer=4;r.carrier="udp";r.destination=argv[1];
  xtp::ListenOptions lo;lo.timeout_ms=1500;
  const auto deadline=std::chrono::steady_clock::now()+std::chrono::milliseconds(std::stoi(argv[4]));
  int verdict=-1;
  try{
    xtp::Listener l(r,lo);
    while(std::chrono::steady_clock::now()<deadline){
      try{auto x=l.receive();if(x.replay)continue;
          if(verdict==-1){verdict=x.logical==v?0:1;std::cout<<(verdict==0?"RECV_OK":"RECV_MISMATCH")<<" bytes="<<x.logical.size()<<"\n";std::cout.flush();}}
      catch(const std::exception&e){if(verdict!=-1)break;if(std::string(e.what()).find("timeout")==std::string::npos)throw;}
    }
  }catch(const std::exception&e){std::cout<<"RECV_FAILED "<<e.what()<<"\n";return 1;}
  if(verdict==-1){std::cout<<"RECV_FAILED nothing delivered before the deadline\n";return 1;}
  return verdict;
}
