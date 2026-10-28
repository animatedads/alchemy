// dev31 interactive context (Session) tests.
// Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"' (see make test-session).
//   S1  open, exchange a message each way, close both ends gracefully
//   S2  2 MB each way at once through 20%/14% loss, byte-exact, both directions closed
//   S3  message boundaries (EOM) survive segmentation, small reads and loss
//   S4  half-close: the client's WCLOSE reaches the server, which still answers
//   S5  backpressure: a peer that does not read stops the writer at window + buffer
//   S6  a refused service fails open_session at once with SERVICE_NOT_ADMITTED
//   S7  an older listener (no interactive contexts) fails open_session at its timeout
//   S8  abort reaches the peer: its read fails with "aborted by peer"
//   S9  a silent peer ends the context after dead_after_ms; keepalive keeps an idle one open
//   S10 a forged END from another port does not end the context (source binding)
//   S11 20 concurrent sessions on one listener, each echoing 50 KB
//   S12 the accept FIRST and first status packets are lost: open still succeeds
//   S13 raw IP protocol 36 on loopback (skipped without CAP_NET_RAW)
//   S14 L2 EtherType 0x817D on lo (skipped without CAP_NET_RAW)
// Added after the independent review of dev31:
//   S15 a listener that cannot bind throws (it crashed)
//   S16 an RSEQ inside a held segment frees nothing (out-of-bounds read)
//   S17 hostile out-of-order segments stay within window and segment cap (unbounded memory and CPU)
//   S18 message marks and acknowledged bytes are released (unbounded growth)
//   S19 forged END / DIAG from the peer's own address are ignored once SYNC/ECHO is established
//   S20 a lost abort is resent when the peer next speaks (peer waited dead_after_ms)
//   S21 an oversize segment_bytes is refused at open (failed late as "not acknowledging")
#include XTP_TRANSPORT_SRC
#include <atomic>
#include <iostream>
#include <random>
#include <thread>
using namespace xtp;

static int failures=0,skips=0;
static void verdict(bool ok,const std::string&id,const std::string&what){std::cout<<(ok?"PASS ":"FAIL ")<<id<<" "<<what<<"\n"<<std::flush;if(!ok)failures++;}
static void skip(const std::string&id,const std::string&why){std::cout<<"SKIP "<<id<<" "<<why<<"\n";skips++;}
static std::vector<uint8_t> bytes(size_t n,uint32_t seed){std::mt19937 g(seed);std::vector<uint8_t> v(n);for(auto&b:v)b=uint8_t(g());return v;}
static std::vector<uint8_t> text(const std::string&s){return std::vector<uint8_t>(s.begin(),s.end());}
static double ms_since(std::chrono::steady_clock::time_point t){return std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count();}
static Route udp(uint16_t port){Route r;r.peer="svc";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:"+std::to_string(port);return r;}
// Read until the peer's WCLOSE (end) or failure; returns the bytes.
static std::vector<uint8_t> read_all(Session&s,int timeout_ms=10000){
  std::vector<uint8_t> out;
  for(;;){auto c=s.read(65536,timeout_ms);if(c.end)break;if(c.data.empty())throw std::runtime_error("read timed out");out.insert(out.end(),c.data.begin(),c.data.end());}
  return out;
}
// Read one whole message (up to an EOM).
static std::vector<uint8_t> read_message(Session&s,size_t step=65536){
  std::vector<uint8_t> out;
  for(;;){auto c=s.read(step,5000);if(c.end)throw std::runtime_error("end before EOM");if(c.data.empty())throw std::runtime_error("read timed out");out.insert(out.end(),c.data.begin(),c.data.end());if(c.eom)return out;}
}

// UDP relay between a client and a listener, with programmable loss.
struct Relay{
  int front=-1,back=-1;std::atomic<bool> stop{false};std::thread th;sockaddr_in client{};std::atomic<bool> have_client{false};sockaddr_in target{};
  std::atomic<unsigned> drop_fwd{0},drop_rev{0},drop_first_rev{0};std::atomic<bool> drop_all{false},drop_rev_all{false};std::atomic<unsigned long> fwd{0},rev{0},dropped{0};
  Relay(uint16_t relay_port,uint16_t target_port){
    front=socket(AF_INET,SOCK_DGRAM,0);back=socket(AF_INET,SOCK_DGRAM,0);
    auto a=ipaddr("127.0.0.1",relay_port);bind(front,(sockaddr*)&a,sizeof a);
    auto b=ipaddr("127.0.0.1",0);bind(back,(sockaddr*)&b,sizeof b);target=ipaddr("127.0.0.1",target_port);
    int big=8*1024*1024;setsockopt(front,SOL_SOCKET,SO_RCVBUFFORCE,&big,sizeof big);setsockopt(back,SOL_SOCKET,SO_RCVBUFFORCE,&big,sizeof big);
    th=std::thread([this]{
      std::array<uint8_t,65536> buf{};
      while(!stop){
        pollfd p[2]={{front,POLLIN,0},{back,POLLIN,0}};
        if(poll(p,2,20)<=0)continue;
        if(p[0].revents&POLLIN){sockaddr_in f{};socklen_t fl=sizeof f;ssize_t n=recvfrom(front,buf.data(),buf.size(),0,(sockaddr*)&f,&fl);
          if(n>0){client=f;have_client=true;const unsigned long k=++fwd;bool drop=drop_all||(drop_fwd&&k%drop_fwd==0);
            if(drop)++dropped;else sendto(back,buf.data(),size_t(n),0,(sockaddr*)&target,sizeof target);}}
        if(p[1].revents&POLLIN){ssize_t n=recv(back,buf.data(),buf.size(),0);
          if(n>0&&have_client){const unsigned long k=++rev;bool drop=drop_all||drop_rev_all||(drop_rev&&k%drop_rev==0)||k<=drop_first_rev;
            if(drop)++dropped;else sendto(front,buf.data(),size_t(n),0,(sockaddr*)&client,sizeof client);}}
      }
    });
  }
  void inject_to_client(const std::vector<uint8_t>&pkt){if(have_client)sendto(front,pkt.data(),pkt.size(),0,(sockaddr*)&client,sizeof client);}
  ~Relay(){stop=true;th.join();::close(front);::close(back);}
};

static void s1_basic(){
  SessionListener L(udp(46201));SessionOptions o;o.service_name="echo";
  std::thread srv([&]{auto s=L.accept(3000);if(!s)return;auto m=read_message(*s);s->write(text("world"),true);read_all(*s);s->close();});
  std::string got;bool closed=false;
  try{auto c=open_session(udp(46201),o);c->write(text("hello"),true);auto m=read_message(*c);got.assign(m.begin(),m.end());closed=c->close();}catch(const std::exception&e){got=std::string("error: ")+e.what();}
  srv.join();
  std::cout<<"  S1 reply='"<<got<<"' closed="<<closed<<"\n";
  verdict(got=="world"&&closed,"S1","open, one message each way, both ends close gracefully");
}

static void s2_bulk_lossy(){
  SessionListenOptions lo;SessionListener L(udp(46211),lo);Relay R(46212,46211);R.drop_fwd=5;R.drop_rev=7;
  const auto up=bytes(2*1024*1024,21),down=bytes(2*1024*1024,22);
  std::vector<uint8_t> srv_got,cli_got;std::string err;bool srv_closed=false,cli_closed=false;SessionStats cs{};
  const auto t0=std::chrono::steady_clock::now();
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s){err="no accept";return;}
      std::thread w([&]{s->write(down);s->shutdown_write();});srv_got=read_all(*s,15000);w.join();srv_closed=s->close(8000);}catch(const std::exception&e){err=std::string("server: ")+e.what();}});
  try{SessionOptions o;o.service_name="bulk";auto c=open_session(udp(46212),o);
    std::thread w([&]{c->write(up);c->shutdown_write();});cli_got=read_all(*c,15000);w.join();cli_closed=c->close(8000);cs=c->stats();}
  catch(const std::exception&e){err+=std::string(" client: ")+e.what();}
  srv.join();
  std::cout<<"  S2 "<<int(ms_since(t0))<<" ms, relay dropped "<<R.dropped<<" of "<<(R.fwd+R.rev)<<", client resent "<<cs.retransmitted_packets<<" packets, srtt "<<cs.srtt_ms<<" ms"<<(err.empty()?"":" "+err)<<"\n";
  verdict(srv_got==up&&cli_got==down&&srv_closed&&cli_closed,"S2","2 MB each way at once through 20%/14% loss, byte-exact, closed both ends");
}

static void s3_eom(){
  SessionListener L(udp(46221));Relay R(46222,46221);R.drop_fwd=6;
  const std::vector<size_t> sizes{1,100,1408,1409,5000,3,70000};
  std::vector<size_t> got_big,got_small;std::string err;
  std::thread srv([&]{try{auto s=L.accept(3000);
      for(size_t i=0;i<sizes.size();++i)got_big.push_back(read_message(*s).size());
      for(size_t i=0;i<sizes.size();++i)got_small.push_back(read_message(*s,7).size());
      read_all(*s);s->close();}catch(const std::exception&e){err=e.what();}});
  try{SessionOptions o;o.service_name="msg";auto c=open_session(udp(46222),o);
    for(int round=0;round<2;++round)for(size_t i=0;i<sizes.size();++i)c->write(bytes(sizes[i],uint32_t(i)),true);
    c->close();}catch(const std::exception&e){err+=e.what();}
  srv.join();
  std::cout<<"  S3 sizes read: ";for(auto n:got_big)std::cout<<n<<" ";std::cout<<"| with 7-byte reads: ";for(auto n:got_small)std::cout<<n<<" ";std::cout<<(err.empty()?"":" "+err)<<"\n";
  verdict(got_big==sizes&&got_small==sizes,"S3","message boundaries survive segmentation, 7-byte reads and 1-in-6 loss");
}

static void s4_half_close(){
  SessionListener L(udp(46231));std::string srv_saw,cli_got;bool cli_end=false;
  std::thread srv([&]{auto s=L.accept(3000);if(!s)return;auto req=read_all(*s);srv_saw.assign(req.begin(),req.end());
      s->write(text("answer to: "+srv_saw));s->close();});
  try{SessionOptions o;o.service_name="half";auto c=open_session(udp(46231),o);c->write(text("question"));c->shutdown_write();
    auto r=c->read(4096,3000);cli_got.assign(r.data.begin(),r.data.end());
    for(;;){auto x=c->read(4096,3000);if(x.end){cli_end=true;break;}if(x.data.empty())break;cli_got.append(x.data.begin(),x.data.end());}
    c->close();}catch(const std::exception&e){cli_got=std::string("error: ")+e.what();}
  srv.join();
  std::cout<<"  S4 server saw '"<<srv_saw<<"' (then end); client got '"<<cli_got<<"' end="<<cli_end<<"\n";
  verdict(srv_saw=="question"&&cli_got=="answer to: question"&&cli_end,"S4","half-close: the server reads to end, then still answers on its own direction");
}

static void s5_backpressure(){
  SessionListenOptions lo;lo.receive_window=64*1024;SessionListener L(udp(46241),lo);
  std::unique_ptr<Session> s;std::thread acc([&]{s=L.accept(3000);});
  SessionOptions o;o.service_name="slow";o.send_buffer_bytes=64*1024;auto c=open_session(udp(46241),o);acc.join();
  const auto big=bytes(1024*1024,51);std::string werr;
  try{c->write(big,false,500);}catch(const std::exception&e){werr=e.what();}
  const uint64_t queued=c->stats().bytes_written;
  std::vector<uint8_t> got;std::thread rd([&]{try{got=read_all(*s,5000);}catch(...){}});
  std::vector<uint8_t> rest(big.begin()+long(queued),big.end());
  bool finished=false;try{c->write(rest);c->shutdown_write();finished=true;}catch(const std::exception&e){werr+=std::string(" then: ")+e.what();}
  rd.join();
  std::cout<<"  S5 writer stopped after "<<queued<<" bytes ('"<<werr<<"'); after the reader started, all "<<got.size()<<" bytes arrived\n";
  verdict(werr.find("not reading")!=std::string::npos&&queued<=64*1024+64*1024+1408&&finished&&got==big,"S5","a peer that does not read holds the writer to window + send buffer; reading releases it");
  c->close(2000);s->close(2000);
}

static void s6_refused(){
  SessionListenOptions lo;lo.allowed_services={"only.this"};SessionListener L(udp(46251),lo);
  SessionOptions o;o.service_name="something.else";std::string err;const auto t0=std::chrono::steady_clock::now();
  try{open_session(udp(46251),o);}catch(const std::exception&e){err=e.what();}
  const double ms=ms_since(t0);std::cout<<"  S6 "<<int(ms)<<" ms: "<<err<<"\n";
  verdict(err.find("SERVICE_NOT_ADMITTED")!=std::string::npos&&ms<500,"S6","a refused service fails open_session at once with its reason");
}

static void s7_old_listener(){
  ListenOptions lo;lo.timeout_ms=2000;Listener old(udp(46261),lo);std::thread t([&]{try{old.receive();}catch(...){}});
  SessionOptions o;o.service_name="svc";o.open_timeout_ms=800;std::string err;const auto t0=std::chrono::steady_clock::now();
  try{open_session(udp(46261),o);}catch(const std::exception&e){err=e.what();}
  const double ms=ms_since(t0);t.join();
  std::cout<<"  S7 "<<int(ms)<<" ms: "<<err<<"\n";
  verdict(err.find("not accepted")!=std::string::npos&&ms>=750&&ms<1500,"S7","a listener without interactive contexts fails open_session at its timeout, with a reason");
}

static void s8_abort(){
  SessionListener L(udp(46271));std::string err;
  std::thread srv([&]{auto s=L.accept(3000);if(!s)return;s->read(100,2000);s->abort();});
  try{SessionOptions o;o.service_name="ab";auto c=open_session(udp(46271),o);c->write(text("x"));c->read(100,3000);}catch(const std::exception&e){err=e.what();}
  srv.join();std::cout<<"  S8 "<<err<<"\n";
  verdict(err.find("aborted by peer")!=std::string::npos,"S8","an abort reaches the peer, whose read fails with the reason");
}

static void s9_dead_and_keepalive(){
  SessionListenOptions lo;lo.keepalive_ms=100;lo.dead_after_ms=600;SessionListener L(udp(46281),lo);Relay R(46282,46281);
  std::unique_ptr<Session> s;std::thread acc([&]{s=L.accept(3000);});
  SessionOptions o;o.service_name="ka";o.keepalive_ms=100;o.dead_after_ms=600;auto c=open_session(udp(46282),o);acc.join();
  std::this_thread::sleep_for(std::chrono::milliseconds(1500));
  const bool alive=c->is_open()&&s->is_open();const auto ka=c->stats().keepalives_sent;
  R.drop_all=true;std::string err;const auto t0=std::chrono::steady_clock::now();
  try{c->read(100,-1);}catch(const std::exception&e){err=e.what();}
  const double ms=ms_since(t0);
  std::cout<<"  S9 idle 1.5 s with keepalive 100 ms: open="<<alive<<" keepalives="<<ka<<"; peer silenced: failed after "<<int(ms)<<" ms: "<<err<<"\n";
  verdict(alive&&ka>=3,"S9a","keepalive holds an idle context open past dead_after_ms");
  verdict(err.find("timed out")!=std::string::npos&&ms<1500,"S9b","a silent peer ends the context after dead_after_ms, with a reason");
}

static void s10_forged_end(){
  SessionListener L(udp(46291));Relay R(46292,46291);std::string reply;
  std::thread srv([&]{auto s=L.accept(3000);if(!s)return;auto m=read_message(*s);s->write(m,true);m=read_message(*s);s->write(m,true);read_all(*s);s->close();});
  try{SessionOptions o;o.service_name="forge";auto c=open_session(udp(46292),o);c->write(text("one"),true);read_message(*c);
    // forged abort for this context, sent to the client's port from another port
    int f=socket(AF_INET,SOCK_DGRAM,0);auto pkt=detail::s_cntl(c->key()|0x80000000U,0,65536,0,0,0,{},TRAIL_END,true,{});
    sockaddr_in to=R.client;for(int i=0;i<3;++i)sendto(f,pkt.data(),pkt.size(),0,(sockaddr*)&to,sizeof to);::close(f);
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    c->write(text("two"),true);auto m=read_message(*c);reply.assign(m.begin(),m.end());c->close();}
  catch(const std::exception&e){reply=std::string("error: ")+e.what();}
  srv.join();std::cout<<"  S10 after a forged END: '"<<reply<<"'\n";
  verdict(reply=="two","S10","a forged END from another port does not end the context");
}

static void s11_concurrent(){
  SessionListenOptions lo11;lo11.close_linger_ms=1000;SessionListener L(udp(46301),lo11);const int N=20;std::atomic<int> ok{0};std::vector<std::thread> servers,clients;
  std::thread acceptor([&]{for(int i=0;i<N;++i){auto s=L.accept(5000);if(!s)break;servers.emplace_back([s=std::shared_ptr<Session>(std::move(s))]{try{auto d=read_all(*s);s->write(d);s->close();}catch(...){}});}});
  for(int i=0;i<N;++i)clients.emplace_back([&,i]{try{SessionOptions o;o.service_name="many";auto c=open_session(udp(46301),o);auto d=bytes(50000,uint32_t(1000+i));c->write(d);c->shutdown_write();if(read_all(*c)==d)++ok;c->close();}catch(...){}});
  for(auto&t:clients)t.join();
  acceptor.join();
  for(auto&t:servers)t.join();
  std::cout<<"  S11 "<<ok<<"/"<<N<<" sessions echoed 50 KB; contexts left after linger: ";std::this_thread::sleep_for(std::chrono::milliseconds(2300));std::cout<<L.contexts()<<"\n";
  verdict(ok==N&&L.contexts()==0,"S11","20 concurrent sessions on one listener, each byte-exact; finished contexts are released");
}

static void s12_lost_accept(){
  SessionListener L(udp(46311));Relay R(46312,46311);R.drop_first_rev=3;std::string got;
  std::thread srv([&]{auto s=L.accept(3000);if(!s)return;auto m=read_message(*s);s->write(m,true);read_all(*s);s->close();});
  const auto t0=std::chrono::steady_clock::now();
  try{SessionOptions o;o.service_name="lossy.open";auto c=open_session(udp(46312),o);c->write(text("ping"),true);auto m=read_message(*c);got.assign(m.begin(),m.end());c->close();}
  catch(const std::exception&e){got=std::string("error: ")+e.what();}
  srv.join();std::cout<<"  S12 first 3 reverse packets dropped: '"<<got<<"' in "<<int(ms_since(t0))<<" ms\n";
  verdict(got=="ping","S12","the accept FIRST and first status packets are lost, and the session still opens");
}


// ---- dev31 review findings (independent review, 27 Oct 2026) ----
// White-box checks drive a context directly, without a pump thread.
static std::shared_ptr<detail::SCore> bare_core(const Route&r,bool initiator){
  auto c=std::make_shared<detail::SCore>();c->initiator=initiator;c->key=4242;c->st=detail::SCore::OPEN;c->peer=detail::route_peer(r);
  c->seg=1000;c->sync_base=100;c->sync_last=100;c->peer_alloc=1u<<20;
  const auto now=std::chrono::steady_clock::now();c->created=c->last_heard=c->last_ka=c->progress_at=now;return c;
}
static void s15_listener_port_in_use(){
  int s=socket(AF_INET,SOCK_DGRAM,0);auto a=ipaddr("127.0.0.1",46351);bind(s,(sockaddr*)&a,sizeof a);
  std::string err;try{SessionListener L(udp(46351));}catch(const std::exception&e){err=e.what();}
  ::close(s);std::cout<<"  S15 "<<err<<"\n";
  verdict(err.find("bind")!=std::string::npos,"S15","a SessionListener that cannot bind throws instead of crashing");
}
static void s16_rseq_inside_segment(){
  Route r=udp(46361);auto ep=std::make_shared<detail::SEndpoint>(r,false,SessionListenOptions{});auto c=bare_core(r,true);
  const auto now=std::chrono::steady_clock::now();
  c->sbuf.assign(1000,0x5a);c->written=1000;ep->transmit(*c,now);
  Cntl q;q.rseq=500;q.alloc=1u<<20;ep->on_cntl(*c,q,now);
  const bool held=c->sbase==0&&c->sbuf.size()==1000&&c->peer_rseq==0&&c->inflight.count(0);
  ep->timers(*c,now+std::chrono::seconds(1));   // the retransmission timer fires and resends the segment
  std::cout<<"  S16 after RSEQ=500 inside [0,1000): sbase="<<c->sbase<<" held="<<c->sbuf.size()<<" peer_rseq="<<c->peer_rseq<<" resent="<<c->stats.retransmitted_packets<<"\n";
  verdict(held&&c->stats.retransmitted_packets==1,"S16","an RSEQ inside a held segment frees nothing that segment needs, and its resend stays in bounds");
}
static void s17_ooo_bounds(){
  Route r=udp(46371);auto ep=std::make_shared<detail::SEndpoint>(r,false,SessionListenOptions{});auto c=bare_core(r,false);
  const auto t0=std::chrono::steady_clock::now();
  for(uint32_t i=1;i<=5000;++i){PayloadPacket f;f.seq=1+i;f.data.assign(1400,'x');ep->on_data(*c,f,std::chrono::steady_clock::now());}
  for(uint32_t i=0;i<3000;++i){PayloadPacket f;f.seq=200000+i*2;f.data.assign(1,'y');ep->on_data(*c,f,std::chrono::steady_clock::now());}
  const double ms=ms_since(t0);
  std::cout<<"  S17 8000 hostile out-of-order segments in "<<int(ms)<<" ms: held "<<c->ooo.size()<<" segments, "<<c->ooo_bytes<<" bytes (window "<<c->tun.receive_window<<")\n";
  verdict(c->ooo.size()<=detail::MAX_OOO_SEGMENTS&&c->ooo_bytes<=c->tun.receive_window&&ms<2000,"S17","overlapping or tiny out-of-order segments cannot grow the reassembly store past the window or the segment cap");
}
static void s18_eoms_pruned(){
  Route r=udp(46381);auto ep=std::make_shared<detail::SEndpoint>(r,false,SessionListenOptions{});auto c=bare_core(r,true);
  const auto now=std::chrono::steady_clock::now();
  for(int i=0;i<10000;++i){c->sbuf.push_back(uint8_t(i));c->written++;c->eoms.insert(c->written);}
  ep->transmit(*c,now);
  Cntl q;q.rseq=uint32_t(c->written);q.alloc=1u<<20;ep->on_cntl(*c,q,now);
  std::cout<<"  S18 10000 one-byte messages sent and acknowledged: eoms left "<<c->eoms.size()<<", bytes held "<<c->sbuf.size()<<"\n";
  verdict(c->eoms.empty()&&c->sbuf.empty()&&c->inflight.empty(),"S18","message-boundary marks and acknowledged bytes are released");
}
static void s19_forged_end_and_diag_from_peer_address(){
  SessionListener L(udp(46391));Relay R(46392,46391);std::string reply;
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;for(;;){auto m=read_message(*s);s->write(m,true);}}catch(...){}});
  try{SessionOptions o;o.service_name="forge2";auto c=open_session(udp(46392),o);c->write(text("one"),true);read_message(*c);
    // from the listener's own address (through the relay): END with no valid ECHO, and a DIAG
    R.inject_to_client(detail::s_cntl(c->key()|0x80000000U,0,65536,0,0,0,{},TRAIL_END,true,{}));
    R.inject_to_client(detail::s_cntl(c->key()|0x80000000U,0,65536,0,0,0,{},TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END,true,{}));
    R.inject_to_client(diag_packet(c->key(),DIAG_CONTEXT_REFUSED,DIAG_POLICY_DENIED,"",true));
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    c->write(text("two"),true);auto m=read_message(*c);reply.assign(m.begin(),m.end());c->abort();}
  catch(const std::exception&e){reply=std::string("error: ")+e.what();}
  L.close();srv.join();std::cout<<"  S19 after a forged abort, graceful END and DIAG from the peer's address: '"<<reply<<"'\n";
  verdict(reply=="two","S19","once SYNC/ECHO is established, ENDs without a valid ECHO and DIAGs on an open context are ignored");
}
static void s20_lost_abort_resent(){
  SessionListener L(udp(46401));Relay R(46402,46401);std::string err;
  std::atomic<int64_t> abort_at{0};const auto base=std::chrono::steady_clock::now();
  std::thread srv([&]{auto s=L.accept(3000);if(!s)return;s->read(100,2000);R.drop_rev_all=true;
      abort_at=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-base).count();s->abort();
      std::this_thread::sleep_for(std::chrono::milliseconds(300));R.drop_rev_all=false;std::this_thread::sleep_for(std::chrono::milliseconds(1500));});
  double ms=-1;
  try{SessionOptions o;o.service_name="lost.abort";o.keepalive_ms=500;auto c=open_session(udp(46402),o);c->write(text("x"));
    try{for(;;){c->read(100,5000);}}catch(const std::exception&e){err=e.what();}
    ms=double(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-base).count()-abort_at);}
  catch(const std::exception&e){err=std::string("open: ")+e.what();}
  srv.join();std::cout<<"  S20 the abort was sent while the reverse path dropped everything for 300 ms; the client learned "<<int(ms)<<" ms after it: "<<err<<"\n";
  verdict(err.find("aborted by peer")!=std::string::npos&&ms>=300&&ms<1500,"S20","a lost abort is sent again when the peer next speaks (here its 500 ms keepalive), instead of the peer waiting dead_after_ms (30 s)");
}
static void s21_segment_too_big(){
  SessionOptions o;o.service_name="big";o.segment_bytes=70000;std::string err;
  try{open_session(udp(46411),o);}catch(const std::exception&e){err=e.what();}
  std::cout<<"  S21 "<<err<<"\n";
  verdict(err.find("exceeds the carrier maximum")!=std::string::npos,"S21","a segment size the carrier cannot send is refused at open");
}
static bool raw_allowed(int domain,int type,int proto){int s=socket(domain,type,proto);if(s<0)return false;::close(s);return true;}
static void echo_on(const Route&r,const std::string&id,const std::string&what){
  std::string got;bool end=false;
  try{SessionListener L(r);
    std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;auto d=read_all(*s);s->write(d);s->close();}catch(const std::exception&e){std::cout<<"  server: "<<e.what()<<"\n";}});
    SessionOptions o;o.service_name="carrier.check";auto c=open_session(r,o);auto d=bytes(300000,77);c->write(d);c->shutdown_write();
    auto back=read_all(*c);end=true;got=back==d?"byte-exact":"MISMATCH";c->close();srv.join();}
  catch(const std::exception&e){got=std::string("error: ")+e.what();}
  std::cout<<"  "<<id<<" 300 KB echo: "<<got<<"\n";
  verdict(got=="byte-exact"&&end,id,what);
}
static void s13_raw36(){
  if(!raw_allowed(AF_INET,SOCK_RAW,36)){skip("S13","raw IP protocol 36 needs CAP_NET_RAW");return;}
  Route r;r.peer="svc";r.layer=3;r.carrier="raw36";r.destination="127.0.0.1";
  echo_on(r,"S13","an interactive context over raw IP protocol 36 on loopback");
}
static void s14_l2(){
  if(!raw_allowed(AF_PACKET,SOCK_RAW,htons(XTP_ETHERTYPE))){skip("S14","AF_PACKET needs CAP_NET_RAW");return;}
  Route r;r.peer="svc";r.layer=2;r.carrier="l2";r.interface_name="lo";r.destination="00:00:00:00:00:00";
  echo_on(r,"S14","an interactive context over L2 EtherType 0x817D on lo");
}

int main(){
  s1_basic();s2_bulk_lossy();s3_eom();s4_half_close();s5_backpressure();s6_refused();s7_old_listener();
  s8_abort();s9_dead_and_keepalive();s10_forged_end();s11_concurrent();s12_lost_accept();s13_raw36();s14_l2();
  s15_listener_port_in_use();s16_rseq_inside_segment();s17_ooo_bounds();s18_eoms_pruned();s19_forged_end_and_diag_from_peer_address();s20_lost_abort_resent();s21_segment_too_big();
  std::cout<<"SESSION SUITE: fail="<<failures<<" skip="<<skips<<"\n";
  return failures?1:0;
}
