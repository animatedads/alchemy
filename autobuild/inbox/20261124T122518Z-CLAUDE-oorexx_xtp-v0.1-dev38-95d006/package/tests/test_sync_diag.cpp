// dev29 SYNC/ECHO and DIAG tests.
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"' -DXTP_DEV29
// Without -DXTP_DEV29 only Y1, Y2 and D1 build, so they can be run against dev28.
//   Y1 a close CNTL recorded from an earlier context with the same KEY is
//      injected as if from the destination: the transfer must not be reported
//      complete on it, and the new data must really be delivered
//   Y2 under 20%/14% loss with timeout_ms=2000, a stream finishes within 2 s:
//      waits are timed from the measured SYNC/ECHO round trip, not timeout_ms
//   Y3 a status request (SYNC) is answered with ECHO = SYNC and the receiver's state
//   D1 a refused named service fails fast with the reason (single FIRST and stream)
//   D2 a DIAG from a source other than the destination is ignored
#include XTP_TRANSPORT_SRC
#include <atomic>
#include <iostream>
#include <mutex>
#include <random>
#include <thread>
using namespace xtp;

static int failures=0;
static void verdict(bool ok,const std::string&id,const std::string&what){std::cout<<(ok?"PASS ":"FAIL ")<<id<<" "<<what<<"\n";if(!ok)failures++;}
static std::vector<uint8_t> payload(size_t n,uint32_t seed){std::mt19937 g(seed);std::vector<uint8_t> v(n);for(auto&b:v)b=uint8_t(g());return v;}
static double ms_since(std::chrono::steady_clock::time_point t){return std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count();}
struct Received{ReceiveResult r;std::string err;};
static Received receive_one(Listener&l){Received x;try{x.r=l.receive();}catch(const std::exception&e){x.err=e.what();}return x;}

// In-process UDP relay with programmable loss, capture and injection.
struct Relay{
  int front=-1,back=-1;std::atomic<bool> stop{false};std::thread th;sockaddr_in client{};std::atomic<bool> have_client{false};sockaddr_in target{};
  std::mutex m;unsigned drop_fwd=0,drop_rev=0;unsigned long fwd=0,rev=0;std::atomic<bool> drop_data{false};
  std::vector<uint8_t> last_close;   // last reverse CNTL with full close flags
  Relay(uint16_t relay_port,uint16_t target_port){
    front=socket(AF_INET,SOCK_DGRAM,0);back=socket(AF_INET,SOCK_DGRAM,0);
    auto a=ipaddr("127.0.0.1",relay_port);bind(front,(sockaddr*)&a,sizeof a);
    auto b=ipaddr("127.0.0.1",0);bind(back,(sockaddr*)&b,sizeof b);target=ipaddr("127.0.0.1",target_port);
    th=std::thread([this]{
      std::array<uint8_t,65536> buf{};
      while(!stop){
        pollfd p[2]={{front,POLLIN,0},{back,POLLIN,0}};
        if(poll(p,2,20)<=0)continue;
        if(p[0].revents&POLLIN){sockaddr_in f{};socklen_t fl=sizeof f;ssize_t n=recvfrom(front,buf.data(),buf.size(),0,(sockaddr*)&f,&fl);
          if(n>0){client=f;have_client=true;const bool is_data=(buf[0]&0x1f)==TYPE_DATA;bool drop=false;
            {std::lock_guard<std::mutex> g(m);++fwd;if(drop_fwd&&fwd%drop_fwd==0)drop=true;}
            if(is_data&&drop_data)drop=true;
            if(!drop)sendto(back,buf.data(),size_t(n),0,(sockaddr*)&target,sizeof target);}}
        if(p[1].revents&POLLIN){ssize_t n=recv(back,buf.data(),buf.size(),0);
          if(n>0&&have_client){bool drop=false;{std::lock_guard<std::mutex> g(m);++rev;if(drop_rev&&rev%drop_rev==0)drop=true;}
            auto q=parse_cntl(buf.data(),size_t(n));
            if(q&&(q->flags&(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END))==(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END)){std::lock_guard<std::mutex> g(m);last_close.assign(buf.begin(),buf.begin()+n);}
            if(!drop)sendto(front,buf.data(),size_t(n),0,(sockaddr*)&client,sizeof client);}}
      }
    });
  }
  void inject_to_client(const std::vector<uint8_t>&pkt){if(have_client)sendto(front,pkt.data(),pkt.size(),0,(sockaddr*)&client,sizeof client);}
  ~Relay(){stop=true;th.join();::close(front);::close(back);}
};

static void y1_stale_close(){
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:46001";
  ListenOptions lo;lo.timeout_ms=4000;Listener l(lr,lo);
  Relay relay(46002,46001);
  Route via=lr;via.destination="127.0.0.1:46002";
  SendOptions so;so.segment_bytes=1024;so.key=31337;so.timeout_ms=200;so.retries=20;
  // Context A completes normally; the relay records its final close CNTL.
  auto a=payload(10000,11);Received ra;
  {std::thread t([&]{ra=receive_one(l);});send_message(via,a,so);t.join();}
  std::vector<uint8_t> stale;{std::lock_guard<std::mutex> g(relay.m);stale=relay.last_close;}
  // Context B: same KEY, new data.  DATA is held back for 400 ms and A's close is
  // injected as soon as B starts.
  auto b=payload(10000,12);Received rb;std::string serr;SendResult sr;
  relay.drop_data=true;
  std::thread t([&]{rb=receive_one(l);});
  std::thread inj([&]{for(int i=0;i<4;++i){std::this_thread::sleep_for(std::chrono::milliseconds(20));relay.inject_to_client(stale);}std::this_thread::sleep_for(std::chrono::milliseconds(320));relay.drop_data=false;});
  try{sr=send_message(via,b,so);}catch(const std::exception&e){serr=e.what();}
  inj.join();t.join();
  std::cout<<"  Y1 A delivered="<<(ra.r.logical==a)<<" stale_close_captured="<<!stale.empty()<<" B sender="<<(serr.empty()?"ok":serr)<<" B delivered="<<(rb.r.logical==b)<<(rb.err.empty()?"":" listener_error="+rb.err)<<"\n";
  verdict(ra.r.logical==a&&!stale.empty()&&serr.empty()&&rb.r.logical==b,"Y1","a stale close from an earlier context with the same KEY cannot complete a new transfer");
}

static void y2_rtt_timer(){
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:46011";
  ListenOptions lo;lo.timeout_ms=20000;Listener l(lr,lo);
  Relay relay(46012,46011);relay.drop_fwd=5;relay.drop_rev=7;
  Route via=lr;via.destination="127.0.0.1:46012";
  SendOptions so;so.segment_bytes=1024;so.timeout_ms=2000;so.retries=12;
  auto d=payload(100*1024,13);Received got;std::string serr;
  const auto t0=std::chrono::steady_clock::now();
  std::thread t([&]{got=receive_one(l);});
  try{send_message(via,d,so);}catch(const std::exception&e){serr=e.what();}
  const double elapsed=ms_since(t0);
  t.join();
  unsigned long f_=0,r_=0;{std::lock_guard<std::mutex> g(relay.m);f_=relay.fwd;r_=relay.rev;}
  std::cout<<"  Y2 elapsed_ms="<<int(elapsed)<<" timeout_ms=2000 relay_forward_packets="<<f_<<" (every 5th dropped) reverse_packets="<<r_<<" (every 7th dropped)"<<(serr.empty()?"":" sender_error="+serr)<<"\n";
  verdict(serr.empty()&&got.r.logical==d&&elapsed<2000.0,"Y2","100 KB at 20%/14% loss with timeout_ms=2000 finishes within one timeout (RTT-timed waits)");
}

#ifdef XTP_DEV29
static void y3_echo(){
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:46021";
  ListenOptions lo;lo.timeout_ms=1500;Listener l(lr,lo);
  std::thread t([&]{try{l.receive();}catch(...){}});
  int fd=socket(AF_INET,SOCK_DGRAM,0);auto to=ipaddr("127.0.0.1",46021);timeval tv{0,300000};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&tv,sizeof tv);
  auto env=WireFilterChain::parse_spec("").encode(payload(3000,14)).bytes;
  std::vector<uint8_t> first(env.begin(),env.begin()+1024);
  auto f=payload_packet(TYPE_FIRST,4711,0,first,true,false,false,false,true);
  sendto(fd,f.data(),f.size(),0,(sockaddr*)&to,sizeof to);
  std::array<uint8_t,65536> b{};recv(fd,b.data(),b.size(),0);           // the FIRST's own status
  auto sreq=sync_request_packet(4711,0x5150A1u,true);
  sendto(fd,sreq.data(),sreq.size(),0,(sockaddr*)&to,sizeof to);
  ssize_t n=recv(fd,b.data(),b.size(),0);
  std::optional<Cntl> q;if(n>0)q=parse_cntl(b.data(),size_t(n));
  ::close(fd);t.join();
  std::cout<<"  Y3 reply="<<(q?"yes":"no");if(q)std::cout<<" echo=0x"<<std::hex<<q->echo<<std::dec<<" rseq="<<q->rseq;std::cout<<"\n";
  verdict(q&&q->echo==0x5150A1u&&q->rseq==1024&&(q->key&0x80000000U),"Y3","a SYNC status request is answered with ECHO=SYNC and the current RSEQ");
}

#endif
static void d1_diag_fast_fail(){
  Route lr;lr.peer="svc";lr.layer=4;lr.carrier="udp";lr.destination="127.0.0.1:46031";
  ListenOptions lo;lo.timeout_ms=3000;lo.allowed_services={"only.this"};Listener l(lr,lo);
  std::thread t([&]{try{l.receive();}catch(...){}});
  SendOptions so;so.service_name="something.else";so.timeout_ms=500;so.retries=12;
  std::string e1,e2;auto t1=std::chrono::steady_clock::now();
  try{send_message(lr,payload(100,15),so);}catch(const std::exception&e){e1=e.what();}
  const double ms1=ms_since(t1);
  so.segment_bytes=512;auto t2=std::chrono::steady_clock::now();
  try{send_message(lr,payload(20000,16),so);}catch(const std::exception&e){e2=e.what();}
  const double ms2=ms_since(t2);
  t.join();
  std::cout<<"  D1 single: "<<int(ms1)<<" ms, "<<e1<<"\n  D1 stream: "<<int(ms2)<<" ms, "<<e2<<"\n";
  verdict(e1.find("SERVICE_NOT_ADMITTED")!=std::string::npos&&e2.find("SERVICE_NOT_ADMITTED")!=std::string::npos&&ms1<400&&ms2<400,"D1","a refused service fails fast with its reason (single FIRST and stream)");
}

#ifdef XTP_DEV29
static void d2_forged_diag(){
  const uint16_t DEST=46041,FORGER=46042;
  int sink=socket(AF_INET,SOCK_DGRAM,0);auto a=ipaddr("127.0.0.1",DEST);bind(sink,(sockaddr*)&a,sizeof a);
  int forger=socket(AF_INET,SOCK_DGRAM,0);auto f=ipaddr("127.0.0.1",FORGER);bind(forger,(sockaddr*)&f,sizeof f);
  std::thread attacker([&]{
    std::array<uint8_t,65536> b{};sockaddr_in from{};socklen_t fl=sizeof from;
    ssize_t n=recvfrom(sink,b.data(),b.size(),0,(sockaddr*)&from,&fl);if(n<8)return;
    const uint32_t key=get32(b.data(),4,true)&0x7fffffffU;
    auto dg=diag_packet(key,DIAG_CONTEXT_REFUSED,DIAG_SERVICE_NOT_ADMITTED,"forged",true);
    sendto(forger,dg.data(),dg.size(),0,(sockaddr*)&from,fl);
  });
  Route r;r.peer="victim";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:46041";
  SendOptions so;so.timeout_ms=300;so.retries=2;std::string err;
  try{send_message(r,payload(64,17),so);}catch(const std::exception&e){err=e.what();}
  attacker.join();::close(sink);::close(forger);
  verdict(!err.empty()&&err.find("refused")==std::string::npos,"D2","a DIAG from a source other than the destination is ignored");
}

#endif
int main(){
  y1_stale_close();y2_rtt_timer();
#ifdef XTP_DEV29
  y3_echo();
#endif
  d1_diag_fast_fail();
#ifdef XTP_DEV29
  d2_forged_diag();
#endif
  std::cout<<"SYNC/DIAG SUITE: fail="<<failures<<"\n";
  return failures?1:0;
}
