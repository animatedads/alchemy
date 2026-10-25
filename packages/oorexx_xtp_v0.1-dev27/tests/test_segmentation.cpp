// dev27 unicast segmentation tests.
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"'  (internal helpers are used by S5)
//   S1 UDP 300 KB, 1024-byte segments, named service: delivered byte-exact
//   S2 L2 (lo) 100 KB, 1456-byte segments: delivered byte-exact      (SKIP without AF_PACKET)
//   S3 UDP through a relay that drops every 5th forward and every 7th reverse packet:
//      delivered byte-exact with retransmissions
//   S4 a stream for a service the listener does not admit: refused, nothing delivered
//   S5 a small message is still ONE FIRST with EOM on the wire (dev26-compatible)
//   S6 the same stream sent twice with the same KEY: second delivery flagged replay
#include XTP_TRANSPORT_SRC
#include <atomic>
#include <iostream>
#include <random>
#include <thread>
using namespace xtp;

static int failures=0, skips=0;
static void verdict(bool ok,const std::string&id,const std::string&what){std::cout<<(ok?"PASS ":"FAIL ")<<id<<" "<<what<<"\n";if(!ok)failures++;}
static std::vector<uint8_t> payload(size_t n,uint32_t seed){std::mt19937 g(seed);std::vector<uint8_t> v(n);for(auto&b:v)b=uint8_t(g());return v;}

struct Received{ReceiveResult r;std::string err;};
static Received receive_one(Listener&l){Received x;try{x.r=l.receive();}catch(const std::exception&e){x.err=e.what();}return x;}

static void s1_udp_large(){
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:45501";
  ListenOptions lo;lo.timeout_ms=5000;lo.allowed_services={"bulk.test"};Listener l(lr,lo);
  auto data=payload(300*1024,1);Received got;
  std::thread t([&]{got=receive_one(l);});
  SendOptions so;so.segment_bytes=1024;so.service_name="bulk.test";so.timeout_ms=300;so.retries=20;
  SendResult sr;std::string serr;try{sr=send_message(lr,data,so);}catch(const std::exception&e){serr=e.what();}
  t.join();
  std::cout<<"  S1 segments="<<sr.segments<<" retransmitted="<<sr.retransmitted_packets<<(serr.empty()?"":" sender_error="+serr)<<(got.err.empty()?"":" listener_error="+got.err)<<"\n";
  verdict(serr.empty()&&got.r.logical==data&&got.r.service_name=="bulk.test"&&sr.segments>1&&!got.r.replay,"S1","UDP 300 KB in 1024-byte segments, named service, byte-exact");
}

static void s2_l2_large(){
  int probe=socket(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE));
  if(probe<0){std::cout<<"SKIP S2 L2 stream (AF_PACKET unavailable)\n";skips++;return;} ::close(probe);
  Route lr;lr.peer="mi";lr.layer=2;lr.carrier="l2";lr.interface_name="lo";lr.destination="00:00:00:00:00:00";
  ListenOptions lo;lo.timeout_ms=5000;Listener l(lr,lo);
  auto data=payload(100*1024,2);Received got;
  std::thread t([&]{got=receive_one(l);});
  SendOptions so;so.segment_bytes=1456;so.timeout_ms=300;so.retries=20;
  SendResult sr;std::string serr;try{sr=send_message(lr,data,so);}catch(const std::exception&e){serr=e.what();}
  t.join();
  std::cout<<"  S2 segments="<<sr.segments<<" retransmitted="<<sr.retransmitted_packets<<(serr.empty()?"":" sender_error="+serr)<<(got.err.empty()?"":" listener_error="+got.err)<<"\n";
  verdict(serr.empty()&&got.r.logical==data&&sr.segments>=70,"S2","L2 100 KB in Ethernet-sized (1456-byte) segments, byte-exact");
}

// Relay: client -> relay_port -> (drop every Nth) -> listener; listener -> relay -> (drop every Mth) -> client.
struct LossyRelay{
  int front=-1,back=-1;std::atomic<bool> stop{false};std::thread th;sockaddr_in client{};bool have_client=false;
  size_t fwd=0,rev=0,fwd_dropped=0,rev_dropped=0;
  LossyRelay(uint16_t relay_port,uint16_t target_port,int drop_fwd,int drop_rev){
    front=socket(AF_INET,SOCK_DGRAM,0);back=socket(AF_INET,SOCK_DGRAM,0);
    auto a=ipaddr("127.0.0.1",relay_port);bind(front,(sockaddr*)&a,sizeof a);
    auto b=ipaddr("127.0.0.1",0);bind(back,(sockaddr*)&b,sizeof b);
    auto target=ipaddr("127.0.0.1",target_port);
    th=std::thread([this,target,drop_fwd,drop_rev]{
      std::array<uint8_t,65536> buf{};
      while(!stop){
        pollfd p[2]={{front,POLLIN,0},{back,POLLIN,0}};
        if(poll(p,2,50)<=0)continue;
        if(p[0].revents&POLLIN){sockaddr_in from{};socklen_t fl=sizeof from;ssize_t n=recvfrom(front,buf.data(),buf.size(),0,(sockaddr*)&from,&fl);if(n>0){client=from;have_client=true;if(++fwd%size_t(drop_fwd)==0)fwd_dropped++;else sendto(back,buf.data(),size_t(n),0,(const sockaddr*)&target,sizeof target);}}
        if(p[1].revents&POLLIN){ssize_t n=recv(back,buf.data(),buf.size(),0);if(n>0&&have_client){if(++rev%size_t(drop_rev)==0)rev_dropped++;else sendto(front,buf.data(),size_t(n),0,(sockaddr*)&client,sizeof client);}}
      }
    });
  }
  ~LossyRelay(){stop=true;th.join();::close(front);::close(back);}
};

static void s3_lossy(){
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:45511";
  ListenOptions lo;lo.timeout_ms=15000;Listener l(lr,lo);
  LossyRelay relay(45512,45511,5,7);
  auto data=payload(200*1024,3);Received got;
  std::thread t([&]{got=receive_one(l);});
  Route via=lr;via.destination="127.0.0.1:45512";
  SendOptions so;so.segment_bytes=1024;so.timeout_ms=150;so.retries=60;
  SendResult sr;std::string serr;try{sr=send_message(via,data,so);}catch(const std::exception&e){serr=e.what();}
  t.join();
  std::cout<<"  S3 segments="<<sr.segments<<" retransmitted="<<sr.retransmitted_packets<<" relay_dropped fwd="<<relay.fwd_dropped<<" rev="<<relay.rev_dropped<<(serr.empty()?"":" sender_error="+serr)<<(got.err.empty()?"":" listener_error="+got.err)<<"\n";
  verdict(serr.empty()&&got.r.logical==data&&sr.retransmitted_packets>0&&relay.fwd_dropped>0&&relay.rev_dropped>0,"S3","UDP 200 KB through 20%/14% loss, byte-exact after go-back-N recovery");
}

static void s4_admission(){
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:45521";
  ListenOptions lo;lo.timeout_ms=2500;lo.allowed_services={"only.this"};Listener l(lr,lo);
  Received got;std::thread t([&]{got=receive_one(l);});
  SendOptions so;so.segment_bytes=512;so.service_name="something.else";so.timeout_ms=150;so.retries=3;
  std::string serr;try{send_message(lr,payload(20000,4),so);}catch(const std::exception&e){serr=e.what();}
  t.join();
  verdict(!serr.empty()&&!got.err.empty()&&got.r.logical.empty(),"S4","stream for an unadmitted service is refused and nothing is delivered");
}

static void s5_single_first(){
  // A bare socket captures what a small send puts on the wire, then answers it.
  int fake=socket(AF_INET,SOCK_DGRAM,0);auto a=ipaddr("127.0.0.1",45531);bind(fake,(sockaddr*)&a,sizeof a);
  size_t packets=0;bool first_with_eom=false;
  std::thread t([&]{
    std::array<uint8_t,65536> b{};sockaddr_in from{};socklen_t fl=sizeof from;
    ssize_t n=recvfrom(fake,b.data(),b.size(),0,(sockaddr*)&from,&fl);if(n<=0)return;packets++;
    auto f=parse_payload_packet(b.data(),size_t(n));
    first_with_eom=f&&f->first&&f->seq==0&&f->final_packet;
    if(f){auto ack=control_packet(f->key,uint32_t(f->data.size()),uint32_t(f->data.size())+65536u,f->little);sendto(fake,ack.data(),ack.size(),0,(sockaddr*)&from,fl);}
    timeval tv{0,300000};setsockopt(fake,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
    while(recv(fake,b.data(),b.size(),0)>0)packets++;
  });
  Route r;r.peer="svc";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:45531";
  SendOptions so;so.timeout_ms=500;so.retries=2;
  std::string serr;SendResult sr;try{sr=send_message(r,payload(100,5),so);}catch(const std::exception&e){serr=e.what();}
  t.join();::close(fake);
  verdict(serr.empty()&&packets==1&&first_with_eom&&sr.segments==1,"S5","a small message is still exactly one FIRST with EOM (dev26 wire format)");
}

static void s6_stream_replay(){
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:45541";
  ListenOptions lo;lo.timeout_ms=5000;Listener l(lr,lo);
  auto data=payload(30000,6);
  SendOptions so;so.segment_bytes=1024;so.key=4242;so.timeout_ms=300;so.retries=20;
  Received a,b;
  std::thread t1([&]{a=receive_one(l);});send_message(lr,data,so);t1.join();
  std::thread t2([&]{b=receive_one(l);});send_message(lr,data,so);t2.join();
  verdict(!a.r.replay&&a.r.logical==data&&b.r.replay&&b.r.logical.empty(),"S6","an identical stream resent with the same KEY is delivered once and then flagged replay");
}

int main(){
  s1_udp_large();s2_l2_large();s3_lossy();s4_admission();s5_single_first();s6_stream_replay();
  std::cout<<"SEGMENTATION SUITE: fail="<<failures<<" skip="<<skips<<"\n";
  return failures?1:0;
}
