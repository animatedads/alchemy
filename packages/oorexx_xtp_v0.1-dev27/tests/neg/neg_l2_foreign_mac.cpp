// NEGATIVE TEST: an L2 XTP listener must only accept FIRST frames addressed to its own MAC
// (or a joined multicast group). Send to a foreign unicast MAC on the same segment (lo here).
#include "xtp/xtp_transport.hpp"
#include <iostream>
#include <thread>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <linux/if_ether.h>
#include <unistd.h>
using namespace xtp;
int main(){
  { int probe=socket(AF_PACKET,SOCK_RAW,htons(0x817D)); if(probe<0){ std::cout<<"SKIP L2 foreign-MAC test: AF_PACKET unavailable (needs CAP_NET_RAW)\n"; return 77; } close(probe); }
  Route lr; lr.peer="mi-a"; lr.layer=2; lr.carrier="l2"; lr.interface_name="lo"; lr.destination="00:00:00:00:00:00";
  ListenOptions lo; lo.timeout_ms=3000; lo.allowed_services={"rto2.work"};
  std::string got="(nothing)"; std::string err;
  std::thread t([&]{ try{ Listener l(lr,lo); auto x=l.receive(); got.assign(x.logical.begin(),x.logical.end()); }catch(const std::exception&e){err=e.what();} });
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  Route sr=lr; sr.peer="mi-b"; sr.destination="02:52:00:09:00:99";   // NOT the listener's MAC
  SendOptions so; so.service_name="rto2.work"; so.retries=2; so.timeout_ms=1000;
  bool delivered=false;
  try{ send_message(sr,std::vector<uint8_t>{'f','o','r','-','M','I','-','B'},so); delivered=true; }catch(const std::exception&e){ std::cout<<"sender: "<<e.what()<<"\n"; }
  t.join();
  std::cout<<"listener(local MAC 00:00:00:00:00:00) received: "<<got<<(err.empty()?"":" err="+err)<<"\n";
  if(got=="for-MI-B"){ std::cout<<"FAIL: L2 listener accepted and ACKed a frame addressed to foreign MAC 02:52:00:09:00:99; sender delivered="<<delivered<<"\n"; return 1; }
  std::cout<<"PASS\n"; return 0;
}
