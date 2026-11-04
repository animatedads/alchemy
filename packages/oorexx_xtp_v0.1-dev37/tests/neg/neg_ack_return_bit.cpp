// NEGATIVE TEST N1-RTN (dev26): XTP marks a returned KEY with its high bit
// (the return bit).  A close-ACK whose KEY lacks it is not a reply from the
// receiving end of this context and must not complete the send.  Here an
// impostor bound to the destination's own address and port answers the FIRST
// with a correctly checksummed close-ACK whose KEY has the return bit cleared.
// Expected: send_message fails.  dev25 never checks the bit.
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"'
#include XTP_TRANSPORT_SRC
#include <iostream>
#include <thread>
int main(){
  using namespace xtp;
  const uint16_t DEST=45401;
  int imp=socket(AF_INET,SOCK_DGRAM,0); sockaddr_in a=ipaddr("127.0.0.1",DEST);
  if(bind(imp,(sockaddr*)&a,sizeof a)<0){perror("bind impostor");return 2;}
  std::thread impostor([&]{
    std::array<uint8_t,65536> b{}; sockaddr_in from{}; socklen_t fl=sizeof from;
    ssize_t n=recvfrom(imp,b.data(),b.size(),0,(sockaddr*)&from,&fl);
    if(n<8) return;
    bool little=(b[0]&0x80)!=0;
    uint32_t key=get32(b.data(),4,little)&0x7fffffffU;
    auto ack=control_packet(key,0x7ffffff0u,0x7ffffff0u,little);
    // Clear the return bit in the common-header KEY and re-seal the header/trailer checksum.
    put32(ack,4,key,little);
    size_t t=ack.size()-TRAILER;
    std::vector<uint8_t> ht(ack.begin(),ack.begin()+HEADER); ht.insert(ht.end(),ack.begin()+long(t),ack.end());
    put32(ht,HEADER+12,0,little); put32(ack,t+12,checksum32(ht.data(),ht.size()),little);
    sendto(imp,ack.data(),ack.size(),0,(sockaddr*)&from,fl);
    std::cout<<"IMPOSTOR answered key="<<key<<" from the destination port with the return bit cleared\n";
  });
  Route r; r.peer="victim"; r.layer=4; r.carrier="udp"; r.destination="127.0.0.1:45401";
  SendOptions so; so.retries=2; so.timeout_ms=1000;
  int rc=0;
  try{ auto x=send_message(r,std::vector<uint8_t>{'d','a','t','a'},so);
       std::cout<<"FAIL sender accepted a close-ACK without the XTP return bit (attempts="<<x.attempts<<")\n"; rc=1; }
  catch(const std::exception&e){ std::cout<<"PASS sender ignored a close-ACK without the return bit: "<<e.what()<<"\n"; }
  impostor.join(); close(imp); return rc;
}
