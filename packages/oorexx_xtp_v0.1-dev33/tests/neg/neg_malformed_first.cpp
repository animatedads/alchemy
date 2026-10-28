// NEGATIVE TEST E6 (dev26): one malformed FIRST must not kill a listener.
// A FIRST carrying a named-service segment (format 0xA11C) with an impossible
// length is sent, then a valid message.  Expected: the listener drops the bad
// frame and still delivers the valid one.  dev25 throws out of receive().
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"'
#include XTP_TRANSPORT_SRC
#include <iostream>
#include <thread>
int main(){
  using namespace xtp;
  Route lr; lr.peer="svc"; lr.layer=4; lr.carrier="udp"; lr.destination="127.0.0.1:45201";
  ListenOptions lo; lo.timeout_ms=3000;
  std::string got, err;
  Listener l(lr,lo);
  std::thread t([&]{ try{ auto x=l.receive(); got.assign(x.logical.begin(),x.logical.end()); }catch(const std::exception&e){ err=e.what(); } });
  // Malformed segment: logical length 0xFFFF, format 0xA11C, 16 bytes total.
  std::vector<uint8_t> bad(16,0); bad[0]=0xff; bad[1]=0xff; bad[2]=uint8_t(XTP_NAMED_SERVICE_FORMAT); bad[3]=uint8_t(XTP_NAMED_SERVICE_FORMAT>>8);
  auto pkt=payload_packet(TYPE_FIRST,4242,0,bad,true);
  int s=socket(AF_INET,SOCK_DGRAM,0); auto a=ipaddr("127.0.0.1",45201);
  sendto(s,pkt.data(),pkt.size(),0,(sockaddr*)&a,sizeof a); close(s);
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  int rc=0;
  try{ SendOptions so; so.retries=3; so.timeout_ms=500; send_message(lr,std::vector<uint8_t>{'g','o','o','d'},so); }
  catch(const std::exception&e){ std::cout<<"sender: "<<e.what()<<"\n"; }
  t.join();
  if(got=="good"){ std::cout<<"PASS listener survived malformed FIRST and delivered the next message\n"; }
  else { std::cout<<"FAIL listener did not deliver the valid message after a malformed FIRST; listener error: "<<(err.empty()?"(none)":err)<<"\n"; rc=1; }
  return rc;
}
