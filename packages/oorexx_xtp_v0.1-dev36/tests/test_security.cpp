// dev32 per-service protection tests (decision D-07).
// Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"' (see make test-security).
//   P1  authenticate: a session works both ways; its data is in clear on the wire
//   P2  encrypt: 2 MB each way through 20%/14% loss, byte-exact; the data never appears on the wire
//   P3  ChaCha20-Poly1305 suite
//   P4  a byte changed in transit (checksums recomputed, as an attacker would) is dropped and repaired
//   P5  forged END, graceful END and DATA from the peer's own address are dropped
//   P6  a replayed DATA packet is rejected by the anti-replay window
//   P7  a replayed open FIRST (after the session ended) opens nothing
//   P8  an unprotected open of a service that has keys is refused: AUTH_REQUIRED
//   P9  require_protection refuses unprotected opens of services without keys
//   P10 rotation: a new key opens new sessions; a session on the retiring key keeps working
//   P11 no active key: open_session refuses before sending anything
//   P12 key file: loads at mode 600; refused at 644; a bad line names its line number
//   P13 throughput, encrypt and unprotected, 20 MB on loopback
// Review fixes (docs/SECURITY.md, "Review"):
//   P14 H1/L3 profiles are sticky: an expired key leaves the service protected; opens fail, "none" is a minimum
//   P15 H2 keys are replaced in one step: no moment without keys; a bad set changes nothing
//   P16 M2 an open replayed to another listener holding the key never reaches accept()
//   P17 M3 a spoofed copy of the open does not keep a dead context alive, and is not answered
//   P18 M1 a key holder flooding valid opens (as fast as one thread can send) does not stall
//          sessions on the same listener, nor stop new opens from another address
//   P19 L4 revoking a key ends the contexts using it, at both ends
//   P20 ML2/L2 key file: a symbolic link or another user's file is refused; strict hex
//   P21 (dev33) encrypted sessions over raw IP protocol 36 and over L2 (lo)
// Second review (dev33):
//   P22 F3 a clear session ends when its service gets a profile
//   P23 F4 clear opens of made-up services cannot crowd out a protected open
//   P24 F5 the open limit is per host: 64 source ports on one host do not starve another host
//   P25 Q4 unconfirmed contexts whose accept resends are spent cost no CPU
//   P26 Q5 two refusals of one open use different AEAD nonces
//   P27 Q7/F1 32,000 keys replace quickly; invalid service names and principals are refused
//   P28 (dev35, gateway mode B) a client's key opens only for an opener naming that client;
//       the listener sees which client opened
#include XTP_TRANSPORT_SRC
#include <atomic>
#include <fstream>
#include <functional>
#include <iostream>
#include <random>
#include <sys/stat.h>
#include <thread>
#include <ctime>
#include <set>
using namespace xtp;

static int failures=0;
static void verdict(bool ok,const std::string&id,const std::string&what){std::cout<<(ok?"PASS ":"FAIL ")<<id<<" "<<what<<"\n"<<std::flush;if(!ok)failures++;}
static std::vector<uint8_t> bytes(size_t n,uint32_t seed){std::mt19937 g(seed);std::vector<uint8_t> v(n);for(auto&b:v)b=uint8_t(g());return v;}
static std::vector<uint8_t> text(const std::string&s){return std::vector<uint8_t>(s.begin(),s.end());}
static double ms_since(std::chrono::steady_clock::time_point t){return std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count();}
static Route udp(uint16_t port){Route r;r.peer="svc";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:"+std::to_string(port);return r;}
static std::vector<uint8_t> read_all(Session&s,int timeout_ms=10000){
  std::vector<uint8_t> out;
  for(;;){auto c=s.read(65536,timeout_ms);if(c.end)break;if(c.data.empty())throw std::runtime_error("read timed out");out.insert(out.end(),c.data.begin(),c.data.end());}
  return out;
}
static std::vector<uint8_t> read_message(Session&s){
  std::vector<uint8_t> out;
  for(;;){auto c=s.read(65536,5000);if(c.end)throw std::runtime_error("end before EOM");if(c.data.empty())throw std::runtime_error("read timed out");out.insert(out.end(),c.data.begin(),c.data.end());if(c.eom)return out;}
}
static ServiceKey make_key(const std::string&service,uint64_t id,Protection p,CipherSuite s=CipherSuite::Aes256Gcm,bool active=true,int64_t not_before=0){
  ServiceKey k;k.service=service;k.key_id=id;k.protection=p;k.suite=s;k.active=active;k.not_before_ms=not_before;k.source="api";
  auto r=security::random_bytes(32);std::copy(r.begin(),r.end(),k.secret.begin());return k;
}
static bool contains(const std::vector<uint8_t>&hay,const std::vector<uint8_t>&needle){return std::search(hay.begin(),hay.end(),needle.begin(),needle.end())!=hay.end();}

// UDP relay with a per-packet hook: return false to drop.  Records every packet.
struct Relay{
  int front=-1,back=-1;std::atomic<bool> stop{false};std::thread th;sockaddr_in client{};std::atomic<bool> have_client{false};sockaddr_in target{};
  std::mutex m;std::vector<std::vector<uint8_t>> fwd_log,rev_log;std::function<bool(std::vector<uint8_t>&,bool,unsigned long)> hook;
  std::atomic<unsigned long> fwd{0},rev{0};
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
          if(n>0){client=f;have_client=true;std::vector<uint8_t> pkt(buf.begin(),buf.begin()+n);const unsigned long k=++fwd;bool pass=true;
            {std::lock_guard<std::mutex> g(m);fwd_log.push_back(pkt);if(hook)pass=hook(pkt,true,k);}
            if(pass)sendto(back,pkt.data(),pkt.size(),0,(sockaddr*)&target,sizeof target);}}
        if(p[1].revents&POLLIN){ssize_t n=recv(back,buf.data(),buf.size(),0);
          if(n>0&&have_client){std::vector<uint8_t> pkt(buf.begin(),buf.begin()+n);const unsigned long k=++rev;bool pass=true;
            {std::lock_guard<std::mutex> g(m);rev_log.push_back(pkt);if(hook)pass=hook(pkt,false,k);}
            if(pass)sendto(front,pkt.data(),pkt.size(),0,(sockaddr*)&client,sizeof client);}}
      }
    });
  }
  void to_client(const std::vector<uint8_t>&p){if(have_client)sendto(front,p.data(),p.size(),0,(sockaddr*)&client,sizeof client);}
  void to_target(const std::vector<uint8_t>&p){sendto(back,p.data(),p.size(),0,(sockaddr*)&target,sizeof target);}
  bool wire_contains(const std::vector<uint8_t>&needle){std::lock_guard<std::mutex> g(m);for(auto&p:fwd_log)if(contains(p,needle))return true;for(auto&p:rev_log)if(contains(p,needle))return true;return false;}
  ~Relay(){stop=true;th.join();::close(front);::close(back);}
};
static bool is_type(const std::vector<uint8_t>&p,uint8_t t){return p.size()>=HEADER+TRAILER&&(p[0]&0x1f)==t;}
// What an attacker on the path can do: change bytes and recompute the XTP checksums.
static void reseal(std::vector<uint8_t>&p){const bool l=(p[0]&0x80)!=0;const size_t t=p.size()-TRAILER;put32(p,t,checksum32(p.data()+HEADER,t-HEADER),l);detail::seal(p,t,l);}


// A raw UDP socket, for packets the library would never send itself.
struct RawUdp{
  int fd=-1;
  explicit RawUdp(const char*host="127.0.0.1"){fd=socket(AF_INET,SOCK_DGRAM,0);auto a=ipaddr(host,0);bind(fd,(sockaddr*)&a,sizeof a);}
  ~RawUdp(){::close(fd);}
  void send(uint16_t port,const std::vector<uint8_t>&p){auto t=ipaddr("127.0.0.1",port);sendto(fd,p.data(),p.size(),0,(sockaddr*)&t,sizeof t);}
  std::vector<uint8_t> recv(int timeout_ms){pollfd q{fd,POLLIN,0};if(poll(&q,1,timeout_ms)<=0)return {};std::array<uint8_t,65536> b{};ssize_t n=::recv(fd,b.data(),b.size(),0);return n>0?std::vector<uint8_t>(b.begin(),b.begin()+n):std::vector<uint8_t>{};}
};
// An unprotected interactive open, as a dev31 opener (or an attacker) sends it.
static std::vector<uint8_t> clear_open(const std::string&service,uint32_t key){
  auto sd=encode_named_service(service,true,XTP_SERVICE_FLAG_INTERACTIVE);
  return detail::s_payload(TYPE_FIRST,key,0,sd.data(),sd.size(),TRAIL_SREQ,true,{});
}
// The DIAG VALUE a listener answers a clear open with, or 0 for no answer.
static uint32_t refusal_of_clear_open(uint16_t port,const std::string&service,uint32_t key){
  RawUdp u;u.send(port,clear_open(service,key));
  for(int i=0;i<5;++i){auto r=u.recv(600);if(r.empty())return 0;if(is_type(r,TYPE_DIAG)){auto d=parse_diag(r.data(),r.size());return d?d->value:0;}}
  return 0;
}
// A valid protected open, built as send_first builds it, for flooding.
static std::vector<uint8_t> protected_open(const ServiceKey&k,uint32_t wkey){
  std::array<uint8_t,16> ni{};auto r=security::random_bytes(16);std::copy(r.begin(),r.end(),ni.begin());
  auto ok=security::hkdf_sha256(k.secret.data(),32,std::vector<uint8_t>(ni.begin(),ni.end()),detail::label("XTP-OPEN-1",k.service,wkey),32);
  auto body=encode_named_service(k.service,true,uint8_t(XTP_SERVICE_FLAG_INTERACTIVE|detail::protection_flags(k.protection)));
  body.insert(body.end(),{'X','S','E','C',1,uint8_t(k.suite),uint8_t(k.protection),0});
  uint8_t id[8];detail::be64(id,k.key_id);body.insert(body.end(),id,id+8);body.insert(body.end(),ni.begin(),ni.end());
  uint8_t ts[8];detail::be64(ts,uint64_t(security::now_ms()));body.insert(body.end(),ts,ts+8);
  const size_t tail_at=HEADER+body.size();body.resize(body.size()+detail::TAIL,0);
  auto pkt=detail::s_payload(TYPE_FIRST,wkey,0,body.data(),body.size(),TRAIL_SREQ,true,{});
  detail::protect(pkt,true,k.suite,ok.data(),detail::DIR_OPEN,0,tail_at,tail_at,0);
  return pkt;
}

static void p1_authenticate(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.auth",101,Protection::Authenticate));
  SessionListener L(udp(47101));Relay R(47102,47101);const auto marker=text("AUTHENTICATED-BUT-CLEAR-0123456789");std::string got;Protection pr=Protection::None;uint64_t kid=0;
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;auto m=read_message(*s);s->write(m,true);read_all(*s);s->close();}catch(...){}});
  try{SessionOptions o;o.service_name="svc.auth";auto c=open_session(udp(47102),o);pr=c->protection();kid=c->key_id();c->write(marker,true);auto m=read_message(*c);got.assign(m.begin(),m.end());c->close();}
  catch(const std::exception&e){got=std::string("error: ")+e.what();}
  srv.join();const bool clear=R.wire_contains(marker);
  std::cout<<"  P1 protection="<<protection_name(pr)<<" key="<<kid<<" echo ok="<<(got==std::string(marker.begin(),marker.end()))<<" data visible on the wire="<<clear<<"\n";
  verdict(pr==Protection::Authenticate&&kid==101&&got==std::string(marker.begin(),marker.end())&&clear,"P1","authenticate: the session works both ways under key 101, and its data is in clear on the wire");
}

static void p2_encrypt_lossy(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.secret",201,Protection::Encrypt));
  SessionListener L(udp(47111));Relay R(47112,47111);
  R.hook=[](std::vector<uint8_t>&,bool fwd,unsigned long k){return fwd?k%5!=0:k%7!=0;};
  auto up=bytes(2*1024*1024,21),down=bytes(2*1024*1024,22);
  const auto marker=text("ENCRYPTED-PLAINTEXT-MARKER-XYZZY-42");std::copy(marker.begin(),marker.end(),up.begin()+1000);std::copy(marker.begin(),marker.end(),down.begin()+5000);
  std::vector<uint8_t> sg,cg;bool sc=false,cc=false;std::string err;Protection pr=Protection::None;SessionStats st{};
  const auto t0=std::chrono::steady_clock::now();
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s){err="no accept";return;}std::thread w([&]{try{s->write(down);s->shutdown_write();}catch(...){}});try{sg=read_all(*s,20000);}catch(...){}w.join();sc=s->close(8000);}catch(const std::exception&e){err=std::string("server: ")+e.what();}});
  try{SessionOptions o;o.service_name="svc.secret";auto c=open_session(udp(47112),o);pr=c->protection();std::thread w([&]{try{c->write(up);c->shutdown_write();}catch(...){}});try{cg=read_all(*c,20000);}catch(...){}w.join();cc=c->close(8000);st=c->stats();}
  catch(const std::exception&e){err+=std::string(" client: ")+e.what();}
  srv.join();const bool leak=R.wire_contains(marker);
  std::cout<<"  P2 "<<int(ms_since(t0))<<" ms, protection="<<protection_name(pr)<<", resent "<<st.retransmitted_packets<<", marker on the wire="<<leak<<(err.empty()?"":" "+err)<<"\n";
  verdict(pr==Protection::Encrypt&&sg==up&&cg==down&&sc&&cc&&!leak,"P2","encrypt: 2 MB each way through 20%/14% loss, byte-exact, closed; the plaintext never appears on the wire");
}

static void p3_chacha(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.chacha",301,Protection::Encrypt,CipherSuite::ChaCha20Poly1305));
  SessionListener L(udp(47121));std::string got;
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;auto d=read_all(*s);s->write(d);s->close();}catch(...){}});
  try{SessionOptions o;o.service_name="svc.chacha";auto c=open_session(udp(47121),o);auto d=bytes(300000,31);c->write(d);c->shutdown_write();got=read_all(*c)==d?"byte-exact":"MISMATCH";c->close();}
  catch(const std::exception&e){got=std::string("error: ")+e.what();}
  srv.join();std::cout<<"  P3 300 KB echo: "<<got<<"\n";
  verdict(got=="byte-exact","P3","ChaCha20-Poly1305 suite, encrypt mode");
}

static void p4_tamper(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.tamper",401,Protection::Authenticate));
  SessionListener L(udp(47131));Relay R(47132,47131);std::atomic<int> changed{0};
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){if(fwd&&is_type(p,TYPE_DATA)&&p.size()>HEADER+TRAILER+40&&changed<5){p[HEADER+3]^=0x01;reseal(p);++changed;}return true;};
  std::vector<uint8_t> got;SessionStats ss{};const auto d=bytes(200000,41);
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;got=read_all(*s);ss=s->stats();s->close();}catch(...){}});
  try{SessionOptions o;o.service_name="svc.tamper";auto c=open_session(udp(47132),o);c->write(d);c->close(8000);}catch(...){}
  srv.join();
  std::cout<<"  P4 "<<changed<<" DATA packets changed in transit: receiver dropped "<<ss.auth_failures<<", data "<<(got==d?"byte-exact":"WRONG")<<"\n";
  verdict(changed==5&&ss.auth_failures>=5&&got==d,"P4","a changed byte (with valid XTP checksums) is dropped as unauthenticated and the data is repaired by retransmission");
}

static void p5_forged(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.forge",501,Protection::Authenticate));
  SessionListener L(udp(47141));Relay R(47142,47141);std::string reply;SessionStats cs{};
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;for(int i=0;i<2;++i){auto m=read_message(*s);s->write(m,true);}read_all(*s);s->close();}catch(...){}});
  try{SessionOptions o;o.service_name="svc.forge";auto c=open_session(udp(47142),o);c->write(text("one"),true);read_message(*c);
    const uint32_t rk=c->key()|0x80000000U;
    std::vector<Span> sp;
    for(uint8_t fl:{uint8_t(TRAIL_END),uint8_t(TRAIL_RCLOSE|TRAIL_WCLOSE|TRAIL_END)}){auto f=detail::s_cntl(rk,0,65536,0,0,0,sp,fl,true,{},detail::TAIL);reseal(f);R.to_client(f);}
    std::vector<uint8_t> junk(64,'J');junk.resize(64+detail::TAIL,0);R.to_client(detail::s_payload(TYPE_DATA,rk,0,junk.data(),junk.size(),TRAIL_EOM,true,{}));
    std::this_thread::sleep_for(std::chrono::milliseconds(80));
    c->write(text("two"),true);auto m=read_message(*c);reply.assign(m.begin(),m.end());cs=c->stats();c->close();}
  catch(const std::exception&e){reply=std::string("error: ")+e.what();}
  srv.join();std::cout<<"  P5 after forged abort, graceful END and DATA from the peer's address: '"<<reply<<"', client dropped "<<cs.auth_failures<<"\n";
  verdict(reply=="two"&&cs.auth_failures>=3,"P5","forged END (abort and graceful) and DATA from the peer's own address are dropped");
}

static void p6_replay_data(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.replay",601,Protection::Encrypt));
  SessionListener L(udp(47151));Relay R(47152,47151);std::vector<uint8_t> captured;std::mutex cm;
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){if(fwd&&is_type(p,TYPE_DATA)){std::lock_guard<std::mutex> g(cm);if(captured.empty())captured=p;}return true;};
  std::vector<uint8_t> got;SessionStats ss{};const auto d=bytes(50000,61);
  std::unique_ptr<Session> s;std::thread acc([&]{s=L.accept(3000);});
  SessionOptions o;o.service_name="svc.replay";auto c=open_session(udp(47152),o);acc.join();
  c->write(d);std::this_thread::sleep_for(std::chrono::milliseconds(200));
  {std::lock_guard<std::mutex> g(cm);for(int i=0;i<3;++i)R.to_target(captured);}
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  c->shutdown_write();got=read_all(*s);ss=s->stats();c->close(3000);s->close(3000);
  std::cout<<"  P6 a captured DATA packet replayed 3 times: rejected "<<ss.replays_rejected<<", data "<<(got==d?"byte-exact":"WRONG")<<"\n";
  verdict(ss.replays_rejected>=3&&got==d,"P6","a replayed DATA packet is rejected by the anti-replay window");
}

static void p7_replay_open(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.reopen",701,Protection::Authenticate));
  SessionListenOptions lo;lo.close_linger_ms=300;SessionListener L(udp(47161),lo);Relay R(47162,47161);std::vector<uint8_t> first;std::mutex fm;
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){if(fwd&&is_type(p,TYPE_FIRST)){std::lock_guard<std::mutex> g(fm);if(first.empty())first=p;}return true;};
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;read_all(*s);s->close();}catch(...){}});
  {SessionOptions o;o.service_name="svc.reopen";o.close_linger_ms=300;auto c=open_session(udp(47162),o);c->write(text("x"));c->close();}
  srv.join();std::this_thread::sleep_for(std::chrono::milliseconds(700));
  const size_t before=L.contexts();
  {std::lock_guard<std::mutex> g(fm);R.to_target(first);}
  auto again=L.accept(500);
  std::cout<<"  P7 replayed open FIRST: contexts before "<<before<<", accepted "<<(again?"YES":"nothing")<<"\n";
  verdict(!again,"P7","a replayed open FIRST opens nothing (open nonce already seen)");
}

static void p8_unprotected_refused(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.needs",801,Protection::Encrypt));
  SessionListener L(udp(47171));
  const uint32_t v=refusal_of_clear_open(47171,"svc.needs",8101);
  std::cout<<"  P8 a clear open of svc.needs (keys: encrypt) is answered with DIAG VALUE "<<v<<" ("<<diag_value_name(v)<<")\n";
  verdict(v==DIAG_AUTH_REQUIRED&&L.contexts()==0,"P8","an unprotected open of a service that has keys is refused with AUTH_REQUIRED");
}

static void p9_require_protection(){
  KeyTable::global().clear();SessionListenOptions lo;lo.require_protection=true;SessionListener L(udp(47181),lo);std::string err;
  try{SessionOptions o;o.service_name="svc.nokeys";open_session(udp(47181),o);}catch(const std::exception&e){err=e.what();}
  std::cout<<"  P9 "<<err<<"\n";
  verdict(err.find("AUTH_REQUIRED")!=std::string::npos,"P9","require_protection refuses unprotected opens of services without keys");
}

static void p10_rotation(){
  KeyTable::global().clear();const int64_t now=security::now_ms();
  auto k1=make_key("svc.rotate",1001,Protection::Encrypt,CipherSuite::Aes256Gcm,true,now-60000);KeyTable::global().install(k1);
  SessionListener L(udp(47191));std::vector<std::unique_ptr<Session>> srv;std::mutex sm;
  std::thread acc([&]{for(int i=0;i<2;++i){auto s=L.accept(4000);if(!s)return;std::lock_guard<std::mutex> g(sm);srv.push_back(std::move(s));}});
  SessionOptions o;o.service_name="svc.rotate";auto a=open_session(udp(47191),o);const uint64_t ka=a->key_id();
  auto k2=make_key("svc.rotate",1002,Protection::Encrypt,CipherSuite::Aes256Gcm,true,now-1000);KeyTable::global().install(k2);
  k1.active=false;KeyTable::global().install(k1);              // 1001 now retiring
  auto b=open_session(udp(47191),o);const uint64_t kb=b->key_id();acc.join();
  std::string ga,gb;
  try{a->write(text("still-on-1001"),true);b->write(text("new-on-1002"),true);
      std::lock_guard<std::mutex> g(sm);for(auto&s:srv){auto m=read_message(*s);(s->key_id()==1001?ga:gb).assign(m.begin(),m.end());}}
  catch(const std::exception&e){ga=e.what();}
  std::cout<<"  P10 first session key "<<ka<<", after rotation "<<kb<<"; old session read '"<<ga<<"', new '"<<gb<<"'\n";
  verdict(ka==1001&&kb==1002&&ga=="still-on-1001"&&gb=="new-on-1002","P10","rotation: the new key opens new sessions; a session on the retiring key keeps working");
  a->abort();b->abort();for(auto&s:srv)s->abort();
}

static void p11_no_key(){
  KeyTable::global().clear();std::string err;
  try{SessionOptions o;o.service_name="svc.missing";o.protection=Protection::Encrypt;open_session(udp(47201),o);}catch(const std::exception&e){err=e.what();}
  std::cout<<"  P11 "<<err<<"\n";
  verdict(err.find("no active key")!=std::string::npos,"P11","open_session with protection demanded and no active key refuses before sending");
}

static void p12_key_file(){
  const std::string dir="/tmp/claude-0/-home-claude/cb53fb2f-253f-5d25-837b-5e3749f69612/scratchpad";
  const std::string good=dir+"/keys_good.tsv",open_perm=dir+"/keys_644.tsv",bad=dir+"/keys_bad.tsv";
  {std::ofstream f(good);f<<"# service key_id protection suite secret principal not_before not_after state\n";
   f<<"svc.file 00000000000003e9 encrypt aes256gcm "<<std::string(64,'a')<<" mu-07 0 0 active\n";
   f<<"svc.file 00000000000003ea encrypt chacha20poly1305 "<<std::string(64,'b')<<"\n";}
  ::chmod(good.c_str(),0600);
  {std::ofstream f(open_perm);f<<"svc.file 00000000000003eb auth aes256gcm "<<std::string(64,'c')<<"\n";}::chmod(open_perm.c_str(),0644);
  {std::ofstream f(bad);f<<"# fine\nsvc.file 00000000000003ec auth aes256gcm "<<std::string(64,'d')<<"\nsvc.file nothex auth aes256gcm "<<std::string(64,'e')<<"\n";}::chmod(bad.c_str(),0600);
  KeyTable::global().clear();size_t n=0;std::string e644,ebad;
  try{n=KeyTable::global().load_file(good);}catch(const std::exception&e){e644="good file: "+std::string(e.what());}
  const Protection req=KeyTable::global().required("svc.file");auto k=KeyTable::global().by_id(1001);
  try{KeyTable::global().load_file(open_perm);}catch(const std::exception&e){e644=e.what();}
  try{KeyTable::global().load_file(bad);}catch(const std::exception&e){ebad=e.what();}
  const size_t after=KeyTable::global().list().size();
  std::cout<<"  P12 loaded "<<n<<" keys, profile "<<protection_name(req)<<", principal '"<<(k?k->principal:"")<<"'; 644: "<<e644<<"; bad: "<<ebad<<"; keys kept "<<after<<"\n";
  verdict(n==2&&req==Protection::Encrypt&&k&&k->principal=="mu-07"&&e644.find("chmod 600")!=std::string::npos&&ebad.find("line 3")!=std::string::npos&&after==2,
          "P12","key file: loads at mode 600; refused at 644; a bad line is named and leaves the loaded keys in place");
  ::unlink(good.c_str());::unlink(open_perm.c_str());::unlink(bad.c_str());
}

static double throughput(const std::string&service,uint16_t port,size_t mb){
  SessionListener L(udp(port));double ms=0;bool ok=false;const auto d=bytes(mb*1024*1024,77);
  std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;ok=read_all(*s,30000)==d;s->close();}catch(...){}});
  try{SessionOptions o;o.service_name=service;const auto t0=std::chrono::steady_clock::now();auto c=open_session(udp(port),o);c->write(d);c->close(30000);ms=ms_since(t0);}catch(...){}
  srv.join();return ok&&ms>0?double(mb)/(ms/1000.0):-1;
}
static void p13_throughput(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.fast.enc",1301,Protection::Encrypt));
  const double plain=throughput("svc.fast.plain",47211,20),enc=throughput("svc.fast.enc",47213,20);
  std::cout<<"  P13 20 MB on loopback: unprotected "<<int(plain)<<" MB/s, encrypted "<<int(enc)<<" MB/s\n";
  verdict(plain>0&&enc>0,"P13","throughput measured for both (recorded, not a pass/fail bound)");
}


static void p14_sticky_profile(){
  KeyTable::global().clear();
  auto k=make_key("svc.sticky",1401,Protection::Encrypt);k.not_after_ms=security::now_ms()+700;KeyTable::global().install(k);
  SessionListener L(udp(47221));
  std::this_thread::sleep_for(std::chrono::milliseconds(900));   // the only key has expired
  const Protection after=KeyTable::global().required("svc.sticky");
  std::string e_default,e_none;
  try{SessionOptions o;o.service_name="svc.sticky";open_session(udp(47221),o);e_default="OPENED";}catch(const std::exception&e){e_default=e.what();}
  try{SessionOptions o;o.service_name="svc.sticky";o.protection=Protection::None;open_session(udp(47221),o);e_none="OPENED";}catch(const std::exception&e){e_none=e.what();}
  const uint32_t v=refusal_of_clear_open(47221,"svc.sticky",14101);
  KeyTable::global().forget_profile("svc.sticky");const Protection forgotten=KeyTable::global().required("svc.sticky");
  std::cout<<"  P14 key expired: profile "<<protection_name(after)<<"; default open: "<<e_default<<"; open asking none: "<<e_none<<"; clear open answered "<<diag_value_name(v)<<"; after forget_profile: "<<protection_name(forgotten)<<"\n";
  verdict(after==Protection::Encrypt&&e_default.find("no active key")!=std::string::npos&&e_none.find("no active key")!=std::string::npos&&v==DIAG_AUTH_REQUIRED&&forgotten==Protection::None,
          "P14","profiles are sticky: an expired key leaves the service at encrypt, opens fail closed, \"none\" is only a minimum; forget_profile lowers it");
}

static void p15_atomic_replace(){
  KeyTable::global().clear();
  auto make=[](uint64_t id){auto k=make_key("svc.atomic",id,Protection::Encrypt);k.source="ldap";return k;};
  KeyTable::global().replace_source("ldap",{make(1501)});
  std::atomic<bool> stop{false};std::atomic<long> checks{0},gaps{0};
  std::thread watcher([&]{while(!stop){if(KeyTable::global().required("svc.atomic")!=Protection::Encrypt||!KeyTable::global().for_open("svc.atomic"))++gaps;++checks;}});
  for(int i=0;i<20000;++i)KeyTable::global().replace_source("ldap",{make(1501+uint64_t(i%2))});
  stop=true;watcher.join();
  // a bad set changes nothing: a key id of 0, a key id of another service, bad hex
  KeyTable::global().install([]{auto k=make_key("svc.other",1599,Protection::Authenticate);return k;}());
  const auto before=KeyTable::global().list().size();std::string e1,e2,e3;
  try{auto k=make(0);KeyTable::global().replace_source("ldap",{make(1510),k});}catch(const std::exception&e){e1=e.what();}
  try{auto k=make(1599);KeyTable::global().replace_source("ldap",{make(1510),k});}catch(const std::exception&e){e2=e.what();}
  try{KeyTable::global().replace_source_text("ldap","svc.atomic 00000000000005f6 encrypt aes256gcm "+std::string(64,'a')+"\nsvc.atomic 00000000000005f7 encrypt aes256gcm 0x"+std::string(62,'b')+"\n");}catch(const std::exception&e){e3=e.what();}
  const bool unchanged=KeyTable::global().list().size()==before&&KeyTable::global().by_id(1510)==std::nullopt&&KeyTable::global().required("svc.atomic")==Protection::Encrypt&&KeyTable::global().for_open("svc.atomic");
  std::cout<<"  P15 20000 replacements, "<<checks<<" concurrent checks, "<<gaps<<" without an encrypt key; bad sets: '"<<e1<<"' / '"<<e2<<"' / '"<<e3<<"'; table unchanged="<<unchanged<<"\n";
  verdict(gaps==0&&checks>0&&!e1.empty()&&e2.find("already belongs")!=std::string::npos&&e3.find("line 2")!=std::string::npos&&e3.find("not hex")!=std::string::npos&&unchanged,
          "P15","replace_source is one step: no moment without the service's keys; a bad set is refused whole and changes nothing");
}

static void p16_replay_to_other_listener(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.pool",1601,Protection::Encrypt));
  SessionListener A(udp(47231)),B(udp(47233));Relay R(47232,47231);std::vector<uint8_t> first;std::mutex fm;
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){if(fwd&&is_type(p,TYPE_FIRST)){std::lock_guard<std::mutex> g(fm);if(first.empty())first=p;}return true;};
  std::thread srv([&]{try{auto s=A.accept(3000);if(!s)return;read_all(*s);s->close();}catch(...){}});
  bool ok_a=false;
  try{SessionOptions o;o.service_name="svc.pool";auto c=open_session(udp(47232),o);c->write(text("real"));ok_a=c->close(3000);}catch(...){}
  srv.join();
  RawUdp u;{std::lock_guard<std::mutex> g(fm);u.send(47233,first);}      // the captured open, replayed to pool node B
  auto got=B.accept(1500);
  const size_t half=B.contexts();
  std::cout<<"  P16 open captured at A, replayed to B (same service key): A session ok="<<ok_a<<", B accept: "<<(got?"A SESSION":"nothing")<<", B held "<<half<<" unconfirmed context(s)\n";
  verdict(ok_a&&!got,"P16","an open replayed to another listener holding the key never reaches accept(): the opener must prove the key first");
}

static void p17_spoofed_first(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.alive",1701,Protection::Authenticate));
  SessionListenOptions lo;lo.dead_after_ms=800;lo.keepalive_ms=200;lo.close_linger_ms=200;SessionListener L(udp(47241),lo);Relay R(47242,47241);
  std::vector<uint8_t> first;std::atomic<bool> cut{false};std::atomic<int> answers{0};std::mutex fm;
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){
    if(fwd&&is_type(p,TYPE_FIRST)){std::lock_guard<std::mutex> g(fm);if(first.empty())first=p;}
    if(cut){if(!fwd)++answers;return false;}
    return true;};
  std::unique_ptr<Session> s;std::thread acc([&]{s=L.accept(3000);});
  SessionOptions o;o.service_name="svc.alive";o.dead_after_ms=60000;auto c=open_session(udp(47242),o);acc.join();
  c->write(text("hi"),true);read_message(*s);
  cut=true;answers=0;                                     // the opener is gone; only the spoofer is left
  for(int i=0;i<25;++i){{std::lock_guard<std::mutex> g(fm);R.to_target(first);}std::this_thread::sleep_for(std::chrono::milliseconds(100));}
  const bool alive=s&&s->is_open();const int firsts=answers.load();
  std::cout<<"  P17 25 spoofed copies of the open over 2.5 s (dead_after 800 ms): server context open="<<alive<<", packets the server sent the spoofed address="<<firsts<<" ("<<(s?s->error():"")<<")\n";
  verdict(s&&!alive&&firsts<=6,"P17","a spoofed copy of the open neither keeps a dead context alive nor draws accepts (only its own keepalives and abort)");
  c->abort();
}

static void p18_open_flood(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.real",1801,Protection::Encrypt));
  const auto flood_key=make_key("svc.flood",1802,Protection::Encrypt);KeyTable::global().install(flood_key);
  SessionListenOptions lo;lo.allowed_services={"svc.real"};SessionListener L(udp(47251),lo);
  std::vector<std::unique_ptr<Session>> srv;std::mutex sm;
  std::thread acc([&]{for(int i=0;i<2;++i){auto s=L.accept(8000);if(!s)return;std::lock_guard<std::mutex> g(sm);srv.push_back(std::move(s));}});
  SessionOptions o;o.service_name="svc.real";auto c=open_session(udp(47251),o);
  std::thread echo([&]{for(;;){std::unique_ptr<Session>*s=nullptr;{std::lock_guard<std::mutex> g(sm);if(!srv.empty())s=&srv[0];}if(s){try{for(;;){auto m=read_message(**s);(*s)->write(m,true);}}catch(...){}return;}std::this_thread::sleep_for(std::chrono::milliseconds(5));}});
  // pre-build valid opens from a holder of another service's key
  std::vector<std::vector<uint8_t>> opens;for(int i=0;i<30000;++i)opens.push_back(protected_open(flood_key,uint32_t(100000+i)));
  std::atomic<bool> stop{false};std::atomic<long> sent{0};
  std::thread flood([&]{RawUdp u("127.0.0.2");/* dev33: the limit is per host, so the flood comes from another host */size_t i=0;while(!stop){u.send(47251,opens[i%opens.size()]);++i;++sent;if(i%64==0)std::this_thread::sleep_for(std::chrono::microseconds(500));}});
  double worst=0;int echoed=0;std::string fresh;
  for(int i=0;i<40;++i){const auto t0=std::chrono::steady_clock::now();try{c->write(text("ping"+std::to_string(i)),true);auto m=read_message(*c);if(m==text("ping"+std::to_string(i)))++echoed;}catch(...){}worst=std::max(worst,ms_since(t0));std::this_thread::sleep_for(std::chrono::milliseconds(25));}
  try{auto c2=open_session(udp(47251),o);fresh=c2->protection()==Protection::Encrypt?"opened":"wrong protection";c2->abort();}catch(const std::exception&e){fresh=e.what();}
  stop=true;flood.join();const double secs=2.0;(void)secs;
  std::cout<<"  P18 "<<sent<<" valid opens of a non-admitted service during the test: "<<echoed<<"/40 echoes, worst round trip "<<int(worst)<<" ms; a fresh open during the flood: "<<fresh<<"\n";
  verdict(echoed==40&&worst<250&&fresh=="opened","P18","a key holder flooding valid opens does not stall sessions on the same listener, nor stop new opens");
  c->abort();{std::lock_guard<std::mutex> g(sm);for(auto&s:srv)s->abort();}echo.join();acc.join();
}

static void p19_revoke_ends_contexts(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.revoke",1901,Protection::Encrypt));
  SessionListener L(udp(47261));std::unique_ptr<Session> s;std::thread acc([&]{s=L.accept(3000);});
  SessionOptions o;o.service_name="svc.revoke";auto c=open_session(udp(47261),o);acc.join();
  c->write(text("before"),true);const auto m=read_message(*s);
  const auto t0=std::chrono::steady_clock::now();KeyTable::global().revoke(1901);
  while((c->is_open()||(s&&s->is_open()))&&ms_since(t0)<3000)std::this_thread::sleep_for(std::chrono::milliseconds(20));
  const int took=int(ms_since(t0));
  std::cout<<"  P19 key revoked: both ends closed after "<<took<<" ms; opener: "<<c->error()<<"; responder: "<<(s?s->error():"")<<"\n";
  verdict(m==text("before")&&!c->is_open()&&s&&!s->is_open()&&(c->error().find("revoked")!=std::string::npos||s->error().find("revoked")!=std::string::npos)&&took<2500,"P19","revoking a key ends the contexts using it at both ends, within about a second");
}

static void p20_key_file_safety(){
  const std::string dir="/tmp/claude-0/-home-claude/cb53fb2f-253f-5d25-837b-5e3749f69612/scratchpad";
  const std::string real=dir+"/keys_real.tsv",link=dir+"/keys_link.tsv",other=dir+"/keys_other.tsv";
  {std::ofstream f(real);f<<"svc.kf 0000000000000801 encrypt aes256gcm "<<std::string(64,'a')<<"\n";}::chmod(real.c_str(),0600);
  ::unlink(link.c_str());(void)!::symlink(real.c_str(),link.c_str());
  {std::ofstream f(other);f<<"svc.kf 0000000000000802 encrypt aes256gcm "<<std::string(64,'b')<<"\n";}::chmod(other.c_str(),0600);(void)!::chown(other.c_str(),65534,65534);
  KeyTable::global().clear();std::string el,eo,eh;size_t n=0;
  try{KeyTable::global().load_file(link);el="LOADED";}catch(const std::exception&e){el=e.what();}
  try{KeyTable::global().load_file(other);eo="LOADED";}catch(const std::exception&e){eo=e.what();}
  try{n=KeyTable::global().load_file(real);}catch(const std::exception&e){el+=" / real: "+std::string(e.what());}
  for(const std::string& bad:{"-1"+std::string(62,'a')," f"+std::string(62,'a'),"az"+std::string(62,'a')}){
    try{parse_key_line("svc.kf 0000000000000803 encrypt aes256gcm "+bad,"api");eh+="ACCEPTED ";}catch(const std::exception&e){eh+=std::string(e.what())+" | ";}
  }
  std::cout<<"  P20 symlink: "<<el<<"; other user's file: "<<eo<<"; real file loaded "<<n<<"; bad secrets: "<<eh<<"\n";
  verdict(el.find("symbolic link")!=std::string::npos&&eo.find("owned by uid 65534")!=std::string::npos&&n==1&&eh.find("ACCEPTED")==std::string::npos,
          "P20","key file: a symbolic link and another user's file are refused; secrets must be exact hex");
  ::unlink(link.c_str());::unlink(real.c_str());::unlink(other.c_str());
}

static void p21_carriers(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.carrier",2101,Protection::Encrypt));
  std::string out;bool ok=true;
  for(int layer:{3,2}){
    Route r;r.peer="svc";
    if(layer==3){r.layer=3;r.carrier="raw36";r.destination="127.0.0.1";}else{r.layer=2;r.carrier="l2";r.interface_name="lo";r.destination="00:00:00:00:00:00";}
    const auto d=bytes(300000,uint32_t(50+layer));std::string got;
    try{SessionListener L(r);std::thread srv([&]{try{auto s=L.accept(3000);if(!s)return;auto x=read_all(*s);s->write(x);s->close();}catch(...){}});
        try{SessionOptions o;o.service_name="svc.carrier";auto c=open_session(r,o);c->write(d);c->shutdown_write();const bool same=read_all(*c)==d;const bool enc=c->protection()==Protection::Encrypt;c->close();
            got=same&&enc?"byte-exact, encrypt":"WRONG";}
        catch(const std::exception&e){got=e.what();}
        srv.join();}
    catch(const std::exception&e){got=e.what();}
    ok&=got=="byte-exact, encrypt";out+=std::string(layer==3?" raw36: ":" L2: ")+got;
  }
  std::cout<<"  P21 300 KB echo:"<<out<<"\n";
  verdict(ok,"P21","encrypted sessions over raw IP protocol 36 and over L2");
}

static double cpu_s(){timespec t{};clock_gettime(CLOCK_PROCESS_CPUTIME_ID,&t);return double(t.tv_sec)+double(t.tv_nsec)/1e9;}

static void p22_late_profile(){
  KeyTable::global().clear();
  SessionListener L(udp(47271));std::unique_ptr<Session> s;std::thread acc([&]{s=L.accept(3000);});
  SessionOptions o;o.service_name="svc.late";auto c=open_session(udp(47271),o);acc.join();
  c->write(text("clear"),true);const auto m=read_message(*s);
  const auto t0=std::chrono::steady_clock::now();KeyTable::global().install(make_key("svc.late",2201,Protection::Encrypt));
  while((c->is_open()||(s&&s->is_open()))&&ms_since(t0)<3000)std::this_thread::sleep_for(std::chrono::milliseconds(20));
  const int took=int(ms_since(t0));
  std::cout<<"  P22 key installed for svc.late: the clear session closed after "<<took<<" ms ("<<c->error()<<" / "<<(s?s->error():"")<<")\n";
  verdict(m==text("clear")&&!c->is_open()&&s&&!s->is_open()&&took<2500,"P22","a clear session ends when its service gets a profile");
}

static void p23_clear_crowding(){
  KeyTable::global().clear();KeyTable::global().install(make_key("svc.real2",2301,Protection::Encrypt));
  SessionListenOptions lo;lo.open_rate_per_sec=100000;lo.open_burst=100000;lo.open_global_rate_per_sec=100000;
  SessionListener L(udp(47281),lo);RawUdp u("127.0.0.3");
  for(uint32_t i=0;i<300;++i)u.send(47281,clear_open("junk"+std::to_string(i),5000+i));
  std::this_thread::sleep_for(std::chrono::milliseconds(300));
  const size_t held=L.contexts();std::string got;
  std::unique_ptr<Session> mine;std::vector<std::unique_ptr<Session>> junk;std::atomic<bool> done{false};
  std::thread acc([&]{while(!done){auto x=L.accept(50);if(!x)continue;if(x->protection()==Protection::Encrypt)mine=std::move(x);else junk.push_back(std::move(x));}});
  try{SessionOptions o;o.service_name="svc.real2";auto c=open_session(udp(47281),o);got="opened";std::this_thread::sleep_for(std::chrono::milliseconds(200));c->abort();}catch(const std::exception&e){got=e.what();}
  done=true;acc.join();
  std::cout<<"  P23 300 clear opens of made-up services: "<<held<<" contexts held; then a protected open: "<<got<<"\n";
  verdict(held<=lo.max_sessions/2+1&&(got=="opened"||got=="accepted"),"P23","clear opens of made-up services hold at most half the table; a protected open still succeeds");
}

static void p24_host_limit(){
  KeyTable::global().clear();const auto k=make_key("svc.hostlim",2401,Protection::Encrypt);KeyTable::global().install(k);
  SessionListener L(udp(47291));std::atomic<bool> stop{false};std::atomic<long> sent{0};
  std::vector<std::thread> flooders;
  std::vector<std::vector<uint8_t>> opens;for(int i=0;i<4000;++i)opens.push_back(protected_open(k,uint32_t(200000+i)));
  for(int t=0;t<4;++t)flooders.emplace_back([&,t]{std::vector<std::unique_ptr<RawUdp>> ports;for(int p=0;p<16;++p)ports.push_back(std::make_unique<RawUdp>("127.0.0.2"));
    size_t i=size_t(t)*1000;while(!stop){ports[i%16]->send(47291,opens[i%opens.size()]);++i;++sent;if(i%64==0)std::this_thread::sleep_for(std::chrono::microseconds(3200));}});   // about 80,000 opens a second in all, the review's rate
  int ok=0;
  std::thread acc([&]{for(int i=0;i<400&&!stop;++i){auto x=L.accept(20);if(x)x->abort();}});
  for(int i=0;i<6;++i){try{SessionOptions o;o.service_name="svc.hostlim";o.open_timeout_ms=1500;auto c=open_session(udp(47291),o);++ok;c->abort();}catch(...){}}
  stop=true;for(auto&t:flooders)t.join();acc.join();
  std::cout<<"  P24 "<<sent<<" valid opens from 64 ports of 127.0.0.2; opens from 127.0.0.1 that succeeded: "<<ok<<"/6\n";
  verdict(ok>=5,"P24","the open limit is per host: a flood from 64 ports of one host does not starve another host");
}

static void p25_spent_resends(){
  KeyTable::global().clear();auto k=make_key("svc.spent",2501,Protection::Authenticate);KeyTable::global().install(k);
  SessionListener L(udp(47301));RawUdp u;std::vector<std::vector<uint8_t>> opens;for(uint32_t i=0;i<200;++i)opens.push_back(protected_open(k,7000+i));
  for(auto&p:opens)u.send(47301,p);
  for(int r=0;r<9;++r){for(auto&p:opens)u.send(47301,p);std::this_thread::sleep_for(std::chrono::milliseconds(5));}
  std::this_thread::sleep_for(std::chrono::milliseconds(300));
  const double c0=cpu_s();std::this_thread::sleep_for(std::chrono::milliseconds(3000));const double cpu=cpu_s()-c0;
  std::cout<<"  P25 200 unconfirmed contexts with their accept resends spent: "<<cpu<<" s of CPU in 3 s\n";
  verdict(cpu<0.3,"P25","unconfirmed contexts whose accept resends are spent do not spin");
}

static void p26_refusal_nonces(){
  KeyTable::global().clear();auto k=make_key("svc.twice",2601,Protection::Authenticate);KeyTable::global().install(k);
  SessionListenOptions lo;lo.allowed_services={"svc.other"};SessionListener L(udp(47311),lo);
  auto open=protected_open(k,9555);RawUdp u;std::vector<std::vector<uint8_t>> diags;
  for(int i=0;i<2;++i){u.send(47311,open);for(auto r=u.recv(500);!r.empty();r=u.recv(200))if(is_type(r,TYPE_DIAG))diags.push_back(r);}
  std::set<uint64_t> ctrs;for(auto&d:diags){auto o=detail::payload_tail_off(d);if(o)ctrs.insert(detail::from_be64(d.data()+*o));}
  std::cout<<"  P26 one open sent twice to a listener that refuses it: "<<diags.size()<<" refusals, "<<ctrs.size()<<" distinct counters\n";
  verdict(diags.size()==2&&ctrs.size()==2,"P26","two refusals of the same open never reuse an AEAD nonce");
}

static void p27_table_scale(){
  std::string t;char id[17];
  for(int i=0;i<32000;++i){std::snprintf(id,sizeof id,"%016x",i+1);t+="svc.big "+std::string(id)+" encrypt aes256gcm "+std::string(64,'a')+"\n";}
  KeyTable::global().clear();std::atomic<bool> stop{false};std::atomic<double> worst{0};
  std::thread w([&]{while(!stop){auto t0=std::chrono::steady_clock::now();(void)KeyTable::global().required("svc.other");double ms=ms_since(t0);if(ms>worst)worst=ms;}});
  const auto t0=std::chrono::steady_clock::now();KeyTable::global().replace_source_text("ldap",t);KeyTable::global().replace_source_text("ldap",t);const double ms=ms_since(t0);
  stop=true;w.join();
  std::string bad;
  for(const std::string&line:{"bad[name 0000000000000001 encrypt aes256gcm "+std::string(64,'a'),"1.2.3.4 0000000000000001 encrypt aes256gcm "+std::string(64,'a'),
                              "svc.ok 0000000000000001 encrypt aes256gcm "+std::string(64,'a')+" pri\x01ncipal"}){
    try{parse_key_line(line,"api");bad+="ACCEPTED ";}catch(const std::exception&e){bad+=std::string(e.what())+" | ";}
  }
  KeyTable::global().clear();
  std::cout<<"  P27 32,000 keys replaced twice in "<<int(ms)<<" ms, worst wait for the table "<<worst<<" ms; refused: "<<bad<<"\n";
  verdict(ms<2000&&worst<500&&bad.find("ACCEPTED")==std::string::npos,"P27","32,000 keys replace in O(n); invalid service names and principals are refused");
}

static void p28_client_keys(){
  KeyTable::global().clear();
  KeyTable::global().install(make_key("svc.gw",2801,Protection::Encrypt));
  auto ck=make_key("svc.gw",2802,Protection::Encrypt);ck.principal="alice";KeyTable::global().install(ck);
  SessionListener L(udp(47321));std::vector<std::pair<uint64_t,std::string>> seen;std::mutex sm;
  std::vector<std::unique_ptr<Session>> kept;   // held until the end: aborting at once races the opener's open_session
  std::thread acc([&]{for(int i=0;i<2;++i){auto x=L.accept(3000);if(!x)return;std::lock_guard<std::mutex> g(sm);seen.emplace_back(x->key_id(),x->key_principal());kept.push_back(std::move(x));}});
  uint64_t k_default=0,k_alice=0;std::string e_bob;
  try{SessionOptions o;o.service_name="svc.gw";auto c=open_session(udp(47321),o);k_default=c->key_id();c->abort();}catch(const std::exception&e){e_bob+=std::string(" default: ")+e.what();}
  try{SessionOptions o;o.service_name="svc.gw";o.key_principal="alice";auto c=open_session(udp(47321),o);k_alice=c->key_id();c->abort();}catch(const std::exception&e){e_bob+=std::string(" alice: ")+e.what();}
  try{SessionOptions o;o.service_name="svc.gw";o.key_principal="bob";auto c=open_session(udp(47321),o);e_bob+=" BOB OPENED";c->abort();}catch(const std::exception&e){e_bob+=e.what();}
  acc.join();for(auto&k:kept)k->abort();
  bool alice_seen=false;for(auto&x:seen)if(x.first==2802&&x.second=="alice")alice_seen=true;
  std::cout<<"  P28 default opener used key "<<k_default<<"; opener naming alice used "<<k_alice<<" (listener saw principal "<<(alice_seen?"alice":"-")<<"); bob: "<<e_bob<<"\n";
  verdict(k_default==2801&&k_alice==2802&&alice_seen&&e_bob.find("no active key")!=std::string::npos,"P28","a client's key is used only by an opener naming that client, and the listener sees the client");
}

int main(int argc,char**argv){
  // optional argument: run only the tests whose ids are listed, e.g. "P2 P4"
  auto want=[&](const char*id){if(argc<2)return true;for(int i=1;i<argc;++i)if(std::string(argv[i])==id)return true;return false;};
  struct T{const char*id;void(*fn)();};
  const T tests[]={{"P1",p1_authenticate},{"P2",p2_encrypt_lossy},{"P3",p3_chacha},{"P4",p4_tamper},{"P5",p5_forged},{"P6",p6_replay_data},{"P7",p7_replay_open},
                   {"P8",p8_unprotected_refused},{"P9",p9_require_protection},{"P10",p10_rotation},{"P11",p11_no_key},{"P12",p12_key_file},{"P13",p13_throughput},
                   {"P14",p14_sticky_profile},{"P15",p15_atomic_replace},{"P16",p16_replay_to_other_listener},{"P17",p17_spoofed_first},
                   {"P18",p18_open_flood},{"P19",p19_revoke_ends_contexts},{"P20",p20_key_file_safety},{"P21",p21_carriers},
                   {"P22",p22_late_profile},{"P23",p23_clear_crowding},{"P24",p24_host_limit},{"P25",p25_spent_resends},{"P26",p26_refusal_nonces},{"P27",p27_table_scale},{"P28",p28_client_keys}};
  for(const auto&t:tests)if(want(t.id))t.fn();
  std::cout<<"SECURITY SUITE: fail="<<failures<<"\n";
  return failures?1:0;
}
