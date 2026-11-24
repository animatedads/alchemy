// NEGATIVE TEST N1-L2 (dev26): an L2 sender must accept a close-ACK only from
// the route's destination MAC, addressed to its own MAC.  An attacker on the
// same segment (here: lo) observes the FIRST and injects a forged CNTL from a
// foreign source MAC.  No listener exists.  Expected: send_message fails.
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"'
#include XTP_TRANSPORT_SRC
#include <iostream>
#include <thread>
int main(){
  using namespace xtp;
  unsigned idx=if_nametoindex("lo");
  int att=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));
  if(att<0){std::cout<<"SKIP L2 spoofed-ACK test: AF_PACKET unavailable (needs CAP_NET_RAW)\n";return 77;}
  sockaddr_ll ba{};ba.sll_family=AF_PACKET;ba.sll_protocol=htons(XTP_ETHERTYPE);ba.sll_ifindex=int(idx);
  if(bind(att,(sockaddr*)&ba,sizeof ba)<0){perror("attacker bind");return 2;}
  std::thread attacker([&]{
    std::array<uint8_t,65536> b{};
    for(int i=0;i<8;i++){
      ssize_t n=recv(att,b.data(),b.size(),0);
      if(n<14+24) continue;
      const uint8_t* p=b.data()+14;
      if((p[0]&0x1f)!=0x02) continue;            // FIRST only
      bool little=(p[0]&0x80)!=0;
      uint32_t key=get32(p,4,little)&0x7fffffffU;
      auto ack=control_packet(key,0x7ffffff0u,0x7ffffff0u,little);
      std::vector<uint8_t> fr(14+ack.size());
      const uint8_t victim[6]={0,0,0,0,0,0}, forged[6]={0x02,0x66,0,0,0,0x01};
      std::copy(victim,victim+6,fr.begin()); std::copy(forged,forged+6,fr.begin()+6);
      fr[12]=uint8_t(XTP_ETHERTYPE>>8); fr[13]=uint8_t(XTP_ETHERTYPE);
      std::copy(ack.begin(),ack.end(),fr.begin()+14);
      sockaddr_ll out{};out.sll_family=AF_PACKET;out.sll_protocol=htons(XTP_ETHERTYPE);out.sll_ifindex=int(idx);out.sll_halen=6;std::copy(victim,victim+6,out.sll_addr);
      sendto(att,fr.data(),fr.size(),0,(sockaddr*)&out,sizeof out);
      std::cout<<"ATTACKER forged CNTL key="<<key<<" from MAC 02:66:00:00:00:01\n";
      return;
    }
  });
  Route r; r.peer="mi-a"; r.layer=2; r.carrier="l2"; r.interface_name="lo"; r.destination="00:00:00:00:00:00";
  SendOptions so; so.service_name="rto2.work"; so.retries=2; so.timeout_ms=1000;
  int rc=0;
  try{ auto x=send_message(r,std::vector<uint8_t>{'s','e','c','r','e','t'},so);
       std::cout<<"FAIL: L2 sender reported DELIVERED attempts="<<x.attempts<<" on a forged CNTL from a foreign MAC with no listener\n"; rc=1; }
  catch(const std::exception&e){ std::cout<<"PASS L2 sender rejected forged ACK: "<<e.what()<<"\n"; }
  attacker.join(); close(att); return rc;
}
