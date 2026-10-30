// dev27/dev28 unicast segmentation and selective-retransmission tests.
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"'  (internal helpers are used by S5)
//   S1 UDP 300 KB, 1024-byte segments, named service: delivered byte-exact
//   S2 L2 (lo) 100 KB, 1456-byte segments: delivered byte-exact      (SKIP without AF_PACKET)
//   S3 UDP through a relay that drops every 5th forward and every 7th reverse packet:
//      delivered byte-exact with retransmissions
//   S4 a stream for a service the listener does not admit: refused, nothing delivered
//   S5 a small message is still ONE FIRST with EOM on the wire (dev26-compatible)
//   S6 the same stream sent twice with the same KEY: delivered once, resend acknowledged
//   S7 a retransmitted FIRST mid-stream keeps progress (dev27 reset it)
//   S8 an out-of-order segment is kept and reported as a SPAN
//   S9 NSPAN/SPAN encode/decode; malformed NSPAN refused
//   S10 (dev31) a receiver that reports a SPAN and then goes silent ends the send (it never ended before)
//   S3 also bounds retransmissions by the losses actually inflicted
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
  verdict(serr.empty()&&got.r.logical==data&&sr.retransmitted_packets>0&&relay.fwd_dropped>0&&relay.rev_dropped>0&&sr.retransmitted_packets<=2*relay.fwd_dropped+relay.rev_dropped+20,"S3","UDP 200 KB through 20%/14% loss, byte-exact; retransmissions bounded by losses (selective repeat)");
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
  // dev28: an identical stream resent with the same KEY after completion is a
  // retransmission (the sender lost the close): the listener re-sends the close
  // and does not reassemble or deliver it again.  (dev27 reassembled it and
  // returned it flagged replay.)
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:45541";
  ListenOptions lo;lo.timeout_ms=1500;Listener l(lr,lo);
  auto data=payload(30000,6);
  SendOptions so;so.segment_bytes=1024;so.key=4242;so.timeout_ms=300;so.retries=20;
  Received a,b;std::string e2;
  std::thread t1([&]{a=receive_one(l);});send_message(lr,data,so);t1.join();
  std::thread t2([&]{b=receive_one(l);});try{send_message(lr,data,so);}catch(const std::exception&e){e2=e.what();}t2.join();
  verdict(!a.r.replay&&a.r.logical==data&&e2.empty()&&!b.err.empty()&&b.r.logical.empty(),"S6","an identical stream resent with the same KEY is delivered once; the resend is acknowledged, not delivered again");
}

// Hand-built stream packets, for receiver-only tests.
static std::vector<std::vector<uint8_t>> stream_packets(const std::vector<uint8_t>&logical,uint32_t key,size_t seg){
  auto env=WireFilterChain::parse_spec("").encode(logical).bytes;
  std::vector<std::vector<uint8_t>> out;
  for(size_t pos=0;pos<env.size();pos+=seg){
    const size_t n=std::min(seg,env.size()-pos);const bool fin=pos+n==env.size();
    std::vector<uint8_t> chunk(env.begin()+long(pos),env.begin()+long(pos+n));
    out.push_back(payload_packet(pos==0?TYPE_FIRST:TYPE_DATA,key,uint32_t(pos),chunk,true,false,false,fin,true));
  }
  return out;
}
struct RawPeer{int fd;sockaddr_in to;
  explicit RawPeer(uint16_t port){fd=socket(AF_INET,SOCK_DGRAM,0);to=ipaddr("127.0.0.1",port);timeval tv{0,200000};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);}
  ~RawPeer(){::close(fd);}
  void send(const std::vector<uint8_t>&p){sendto(fd,p.data(),p.size(),0,(sockaddr*)&to,sizeof to);}
  std::vector<Cntl> drain(){std::vector<Cntl> v;std::array<uint8_t,65536>b{};for(;;){ssize_t n=recv(fd,b.data(),b.size(),0);if(n<=0)break;auto q=parse_cntl(b.data(),size_t(n));if(q)v.push_back(*q);}return v;}
};

static void s7_first_retransmit_keeps_progress(){
  // FIRST, DATA1, FIRST again (its CNTL was "lost"), DATA2 final.  dev27 reset
  // the stream on the second FIRST and never delivered.
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:45551";
  ListenOptions lo;lo.timeout_ms=2000;Listener l(lr,lo);
  auto data=payload(2500,7);auto pk=stream_packets(data,5151,1024);
  Received got;std::thread t([&]{got=receive_one(l);});
  RawPeer rp(45551);std::this_thread::sleep_for(std::chrono::milliseconds(50));
  rp.send(pk.at(0));rp.send(pk.at(1));rp.send(pk.at(0));rp.send(pk.at(2));
  t.join();
  verdict(pk.size()==3&&got.r.logical==data,"S7","a retransmitted FIRST mid-stream does not discard progress");
}

static void s8_spans_reported(){
  // FIRST, then DATA3 (skipping DATA1, DATA2): the CNTL must hold RSEQ at the
  // end of FIRST and report DATA3 as a SPAN.  Then fill the gap: delivered.
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:45561";
  ListenOptions lo;lo.timeout_ms=2000;Listener l(lr,lo);
  auto data=payload(4000,8);auto pk=stream_packets(data,6161,1024);
  Received got;std::thread t([&]{got=receive_one(l);});
  RawPeer rp(45561);std::this_thread::sleep_for(std::chrono::milliseconds(50));
  rp.send(pk.at(0));rp.drain();rp.send(pk.at(3));auto c=rp.drain();
  bool span_ok=!c.empty()&&c.back().rseq==1024&&c.back().spans.size()==1&&c.back().spans[0].first==3072;
  std::cout<<"  S8 cntls="<<c.size();if(!c.empty()){std::cout<<" rseq="<<c.back().rseq<<" spans="<<c.back().spans.size();if(!c.back().spans.empty())std::cout<<" ["<<c.back().spans[0].first<<","<<c.back().spans[0].second<<")";}std::cout<<"\n";
  rp.send(pk.at(1));rp.send(pk.at(2));
  t.join();
  verdict(span_ok&&got.r.logical==data,"S8","an out-of-order segment is kept and reported as a SPAN; filling the gap completes the stream");
}

static void s9_nspan_parsing(){
  std::vector<Span> sp={{100,200},{300,450}};
  auto good=control_packet_ex(77,50,4096,true,false,0xffffffffu,0xffffffffu,{},0,0,sp);
  auto q=parse_cntl(good.data(),good.size());
  bool ok_good=q&&q->spans==sp&&q->rseq==50;
  auto plain=control_packet_ex(77,50,4096,true,false);
  auto qp=parse_cntl(plain.data(),plain.size());
  bool ok_plain=plain.size()==HEADER+CONTROL+TRAILER&&get32(plain.data(),HEADER+36,true)==0&&qp&&qp->spans.empty();
  // NSPAN claims 200 pairs in a packet holding 2; checksums re-sealed so only NSPAN is wrong.
  auto bad=good;put32(bad,HEADER+36,200,true);
  const size_t t=bad.size()-TRAILER;put32(bad,t,checksum32(bad.data()+HEADER,t-HEADER),true);
  std::vector<uint8_t> ht(bad.begin(),bad.begin()+HEADER);ht.insert(ht.end(),bad.begin()+long(t),bad.end());put32(ht,HEADER+12,0,true);put32(bad,t+12,checksum32(ht.data(),ht.size()),true);
  bool ok_bad=!parse_cntl(bad.data(),bad.size());
  // An inverted span (end <= start) is also malformed.
  auto inv=control_packet_ex(77,50,4096,true,false,0xffffffffu,0xffffffffu,{},0,0,{{500,400}});
  bool ok_inv=!parse_cntl(inv.data(),inv.size());
  verdict(ok_good&&ok_plain&&ok_bad&&ok_inv,"S9","NSPAN round-trips; NSPAN=0 CNTL is the dev27 layout; an overlong NSPAN or inverted SPAN is refused");
}


// dev31: a receiver that reports a SPAN and then goes silent (as a listener
// does once it has delivered and stops reading) must not keep the sender
// resending for ever.  Before dev31 the early wake for a SPAN hole never
// counted as a timeout, so the send never ended.
static void s10_silent_after_span(){
  int fd=socket(AF_INET,SOCK_DGRAM,0);auto a=ipaddr("127.0.0.1",45561);bind(fd,(sockaddr*)&a,sizeof a);
  std::atomic<bool> stop{false};
  std::thread fake([&]{
    std::array<uint8_t,65536> b{};sockaddr_in from{};socklen_t fl=sizeof from;timeval tv{0,100000};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
    bool answered=false;
    while(!stop){ssize_t n=recvfrom(fd,b.data(),b.size(),0,(sockaddr*)&from,&fl);
      if(n>0&&!answered){auto f=parse_payload_packet(b.data(),size_t(n));
        if(f){auto q=control_packet_ex(f->key,1024,1u<<20,true,false,0xffffffffu,0xffffffffu,{},0,0,{{3072,4096}});sendto(fd,q.data(),q.size(),0,(sockaddr*)&from,fl);answered=true;}}}
  });
  Route r;r.peer="svc";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:45561";
  SendOptions so;so.segment_bytes=1024;so.timeout_ms=100;so.retries=3;std::string err;
  const auto t0=std::chrono::steady_clock::now();
  try{send_message(r,payload(50000,10),so);}catch(const std::exception&e){err=e.what();}
  const double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t0).count();
  stop=true;fake.join();::close(fd);
  std::cout<<"  S10 "<<int(ms)<<" ms: "<<err<<"\n";
  verdict(!err.empty()&&ms<6000,"S10","a receiver that reports a SPAN and then goes silent ends the send within the no-progress budget");
}
int main(){
  s1_udp_large();s2_l2_large();s3_lossy();s4_admission();s5_single_first();s6_stream_replay();s7_first_retransmit_keeps_progress();s8_spans_reported();s9_nspan_parsing();s10_silent_after_span();
  std::cout<<"SEGMENTATION SUITE: fail="<<failures<<" skip="<<skips<<"\n";
  return failures?1:0;
}
