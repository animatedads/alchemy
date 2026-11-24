// NEGATIVE TEST (white-box): does an XTP L4 sender accept a delivery ACK that
// (a) comes from a source address/port other than the destination, and
// (b) corresponds to no listener and no application delivery at all?
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"'
// Expected under a fail-closed contract: send_message must NOT report success.
#include XTP_TRANSPORT_SRC
#include <thread>
#include <iostream>
int main(){
  using namespace xtp;
  const uint16_t DEST=45101, FORGER=45102;
  // "destination" is a bare socket: NO XTP Listener, NO application.
  int sink=socket(AF_INET,SOCK_DGRAM,0); sockaddr_in a=ipaddr("127.0.0.1",DEST);
  if(bind(sink,(sockaddr*)&a,sizeof a)<0){perror("bind sink");return 2;}
  int forger=socket(AF_INET,SOCK_DGRAM,0); sockaddr_in f=ipaddr("127.0.0.1",FORGER);
  if(bind(forger,(sockaddr*)&f,sizeof f)<0){perror("bind forger");return 2;}
  std::thread attacker([&]{
    std::array<uint8_t,65536> b{}; sockaddr_in from{}; socklen_t fl=sizeof from;
    ssize_t n=recvfrom(sink,b.data(),b.size(),0,(sockaddr*)&from,&fl);   // observe FIRST (on-path view)
    if(n<8) return;
    bool little=(b[0]&0x80)!=0;
    uint32_t key= little ? (uint32_t(b[4])|uint32_t(b[5])<<8|uint32_t(b[6])<<16|uint32_t(b[7])<<24)
                         : (uint32_t(b[4])<<24|uint32_t(b[5])<<16|uint32_t(b[6])<<8|uint32_t(b[7]));
    key&=0x7fffffffU;
    auto ack=control_packet(key,0x7ffffff0u,0x7ffffff0u,little);       // forged close-ACK
    sendto(forger,ack.data(),ack.size(),0,(sockaddr*)&from,fl);          // sent from a DIFFERENT port
    std::cout<<"ATTACKER observed key="<<key<<" from sender port "<<ntohs(from.sin_port)<<"; forged ACK sent from port "<<FORGER<<" (destination was "<<DEST<<")\n";
  });
  Route r; r.peer="victim"; r.layer=4; r.carrier="udp"; r.destination="127.0.0.1:45101";
  SendOptions so; so.service_name="storage.range.read"; so.retries=2; so.timeout_ms=1000;
  int rc=0;
  try{
    auto x=send_message(r,std::vector<uint8_t>{'s','e','c','r','e','t'},so);
    std::cout<<"FAIL(expected-reject): sender reported DELIVERED attempts="<<x.attempts<<" rseq="<<x.rseq<<" with no listener and an ACK from a non-destination source\n";
    rc=1;
  }catch(const std::exception&e){
    std::cout<<"PASS sender rejected spoofed ACK: "<<e.what()<<"\n";
  }
  attacker.join(); return rc;
}
