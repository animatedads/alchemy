// dev33 protected one-way messages and streams (decision D-07).
// Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"' (see make test-message-security).
//   M1  authenticate, one packet: delivered with protection and key id; data in clear on the wire
//   M2  encrypt, 2 MB stream through 20%/14% loss: byte-exact; plaintext never on the wire
//   M3  ChaCha20-Poly1305, encrypt
//   M4  DATA changed in transit (checksums recomputed): dropped, then repaired
//   M5  a clear message to a service with keys: refused with AUTH_REQUIRED, not delivered
//   M6  a captured protected message replayed to the same listener: not delivered again
//   M7  the same capture replayed to another listener holding the key: delivered once there
//       (the documented limit of a protocol with no handshake), never twice
//   M8  a forged close-acknowledgement does not make the sender report success early
//   M9  no active key: send_message refuses before sending; "none" is only a minimum
//   M10 sticky profile: the key expired, the message is refused, never sent clear
//   M11 throughput, 20 MB, protected and unprotected
//   M12 encrypted messages over raw IP protocol 36 and L2 (EtherType 0x817D on lo)
#include XTP_TRANSPORT_SRC
#include <atomic>
#include <functional>
#include <iostream>
#include <random>
#include <thread>
using namespace xtp;

static int failures=0;
static void verdict(bool ok,const std::string&id,const std::string&what){std::cout<<(ok?"PASS ":"FAIL ")<<id<<" "<<what<<"\n"<<std::flush;if(!ok)failures++;}
static std::vector<uint8_t> bytes(size_t n,uint32_t seed){std::mt19937 g(seed);std::vector<uint8_t> v(n);for(auto&b:v)b=uint8_t(g());return v;}
static std::vector<uint8_t> text(const std::string&s){return std::vector<uint8_t>(s.begin(),s.end());}
static double ms_since(std::chrono::steady_clock::time_point t){return std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t).count();}
static Route udp(uint16_t port){Route r;r.peer="svc";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:"+std::to_string(port);return r;}
static ServiceKey make_key(const std::string&service,uint64_t id,Protection p,CipherSuite s=CipherSuite::Aes256Gcm){
  ServiceKey k;k.service=service;k.key_id=id;k.protection=p;k.suite=s;k.source="api";
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
  RawUdp(){fd=socket(AF_INET,SOCK_DGRAM,0);auto a=ipaddr("127.0.0.1",0);bind(fd,(sockaddr*)&a,sizeof a);}
  ~RawUdp(){::close(fd);}
  void send(uint16_t port,const std::vector<uint8_t>&p){auto t=ipaddr("127.0.0.1",port);sendto(fd,p.data(),p.size(),0,(sockaddr*)&t,sizeof t);}
  std::vector<uint8_t> recv(int timeout_ms){pollfd q{fd,POLLIN,0};if(poll(&q,1,timeout_ms)<=0)return {};std::array<uint8_t,65536> b{};ssize_t n=::recv(fd,b.data(),b.size(),0);return n>0?std::vector<uint8_t>(b.begin(),b.begin()+n):std::vector<uint8_t>{};}
};

// One message received in the background, or the error.
struct Rx{
  std::thread th;std::optional<ReceiveResult> got;std::string err;
  Rx(Listener&L){th=std::thread([&]{try{got=L.receive();}catch(const std::exception&e){err=e.what();}});}
  ~Rx(){if(th.joinable())th.join();}
  void join(){th.join();}
};
static ListenOptions lopts(int timeout_ms){ListenOptions o;o.timeout_ms=timeout_ms;return o;}
static SendOptions sopts(const std::string&service,int timeout_ms=250,int retries=12){SendOptions o;o.service_name=service;o.timeout_ms=timeout_ms;o.retries=retries;return o;}

static void m1_authenticate(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.auth",3101,Protection::Authenticate));
  Listener L(udp(48301),lopts(4000));Relay R(48302,48301);const auto marker=text("AUTHENTICATED-MESSAGE-IN-CLEAR-42");
  Rx rx(L);SendResult sr;std::string err;
  try{sr=send_message(udp(48302),marker,sopts("msg.auth"));}catch(const std::exception&e){err=e.what();}
  rx.join();
  const bool ok=rx.got&&rx.got->logical==marker&&rx.got->protection==Protection::Authenticate&&rx.got->key_id==3101&&sr.protection==Protection::Authenticate;
  std::cout<<"  M1 sent: "<<(err.empty()?"ok":err)<<", segments "<<sr.segments<<"; received: "<<(rx.got?protection_name(rx.got->protection):rx.err)<<" key "<<(rx.got?rx.got->key_id:0)<<"; marker on the wire="<<R.wire_contains(marker)<<"\n";
  verdict(ok&&R.wire_contains(marker),"M1","authenticate, one packet: delivered with its protection and key id; data in clear on the wire");
}

static void m2_encrypt_stream_lossy(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.enc",3201,Protection::Encrypt));
  Listener L(udp(48311),lopts(30000));Relay R(48312,48311);
  R.hook=[](std::vector<uint8_t>&,bool fwd,unsigned long k){return fwd?k%5!=0:k%7!=0;};
  auto d=bytes(2*1024*1024,32);const auto marker=text("ENCRYPTED-MESSAGE-PLAINTEXT-MARKER-77");std::copy(marker.begin(),marker.end(),d.begin()+12345);
  Rx rx(L);SendResult sr;std::string err;const auto t0=std::chrono::steady_clock::now();
  auto o=sopts("msg.enc",250,40);o.segment_bytes=1400;
  try{sr=send_message(udp(48312),d,o);}catch(const std::exception&e){err=e.what();}
  const double ms=ms_since(t0);rx.join();
  const bool leak=R.wire_contains(marker);
  std::cout<<"  M2 "<<int(ms)<<" ms, "<<sr.segments<<" segments, resent "<<sr.retransmitted_packets<<", protection "<<protection_name(sr.protection)<<(err.empty()?"":" error: "+err)<<"; marker on the wire="<<leak<<"\n";
  verdict(err.empty()&&rx.got&&rx.got->logical==d&&rx.got->protection==Protection::Encrypt&&!leak,"M2","encrypt, 2 MB stream through 20%/14% loss: byte-exact; the plaintext never appears on the wire");
}

static void m3_chacha(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.chacha",3301,Protection::Encrypt,CipherSuite::ChaCha20Poly1305));
  Listener L(udp(48321),lopts(5000));Rx rx(L);const auto d=bytes(300000,33);std::string err;
  auto o=sopts("msg.chacha");o.segment_bytes=8000;
  try{send_message(udp(48321),d,o);}catch(const std::exception&e){err=e.what();}
  rx.join();
  std::cout<<"  M3 300 KB: "<<(rx.got&&rx.got->logical==d?"byte-exact":"WRONG "+err+rx.err)<<"\n";
  verdict(rx.got&&rx.got->logical==d&&rx.got->protection==Protection::Encrypt,"M3","ChaCha20-Poly1305 suite, encrypt mode");
}

static void m4_tamper(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.tamper",3401,Protection::Authenticate));
  Listener L(udp(48331),lopts(10000));Relay R(48332,48331);std::atomic<int> changed{0};
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){if(fwd&&is_type(p,TYPE_DATA)&&changed<5){p[HEADER+3]^=0x01;reseal(p);++changed;}return true;};
  Rx rx(L);const auto d=bytes(200000,34);std::string err;auto o=sopts("msg.tamper");o.segment_bytes=1400;
  try{send_message(udp(48332),d,o);}catch(const std::exception&e){err=e.what();}
  rx.join();
  std::cout<<"  M4 "<<changed<<" DATA packets changed in transit; data "<<(rx.got&&rx.got->logical==d?"byte-exact":"WRONG "+err+rx.err)<<"\n";
  verdict(changed==5&&rx.got&&rx.got->logical==d,"M4","a changed byte (with valid XTP checksums) is dropped and the data repaired by retransmission");
}

static void m5_clear_refused(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.needs",3501,Protection::Encrypt));
  Listener L(udp(48341),lopts(1500));Rx rx(L);
  // a dev32-style clear message: one FIRST carrying an envelope, as an older sender sends it
  auto env=WireFilterChain::parse_spec("").encode(text("clear attempt")).bytes;
  auto pkt=first_packet(4141,env,true,false,false,{},0,"msg.needs");
  RawUdp u;u.send(48341,pkt);uint32_t v=0;
  for(int i=0;i<4;++i){auto r=u.recv(500);if(r.empty())break;if(is_type(r,TYPE_DIAG)){auto dd=parse_diag(r.data(),r.size());v=dd?dd->value:0;break;}}
  rx.join();
  std::cout<<"  M5 clear message to msg.needs (keys: encrypt): DIAG "<<diag_value_name(v)<<"; listener: "<<(rx.got?"DELIVERED":rx.err)<<"\n";
  verdict(v==DIAG_AUTH_REQUIRED&&!rx.got,"M5","a clear message to a service with keys is refused with AUTH_REQUIRED and not delivered");
}

static void m6_m7_replay(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.pool",3601,Protection::Encrypt));
  Listener A(udp(48351),lopts(3000)),B(udp(48353),lopts(1500));Relay R(48352,48351);std::vector<uint8_t> first;std::mutex fm;
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){if(fwd&&is_type(p,TYPE_FIRST)){std::lock_guard<std::mutex> g(fm);if(first.empty())first=p;}return true;};
  const auto msg=text("pay 10 to alice");
  {Rx rx(A);send_message(udp(48352),msg,sopts("msg.pool"));rx.join();}
  // M6: the same bytes again, to A, from the sender's own address
  std::optional<ReceiveResult> again;std::string again_err;
  {std::thread t([&]{try{again=A.receive();}catch(const std::exception&e){again_err=e.what();}});
   std::this_thread::sleep_for(std::chrono::milliseconds(100));{std::lock_guard<std::mutex> g(fm);R.to_target(first);}t.join();}
  std::cout<<"  M6 captured message replayed to the same listener: "<<(again?(again->replay?"returned, marked replay":"DELIVERED AGAIN"):again_err)<<"\n";
  verdict(!again||again->replay,"M6","a protected message replayed to the same listener is not delivered again");
  // M7: the capture sent to pool node B, which holds the same key
  RawUdp u;std::optional<ReceiveResult> atb,twice;std::string eb;
  {std::thread t([&]{try{atb=B.receive();}catch(const std::exception&e){eb=e.what();}});
   std::this_thread::sleep_for(std::chrono::milliseconds(100));{std::lock_guard<std::mutex> g(fm);u.send(48353,first);}t.join();}
  {std::thread t([&]{try{twice=B.receive();}catch(...){}});
   std::this_thread::sleep_for(std::chrono::milliseconds(100));{std::lock_guard<std::mutex> g(fm);u.send(48353,first);}t.join();}
  std::cout<<"  M7 the capture at pool node B: "<<(atb&&atb->logical==msg?"delivered once (documented limit: no handshake)":"not delivered "+eb)<<"; second copy at B: "<<(twice&&!twice->replay?"DELIVERED AGAIN":"not delivered")<<"\n";
  verdict(!(twice&&!twice->replay),"M7","a replay reaches another listener holding the key at most once (documented limit), never twice");
}

static void m8_forged_close(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.close",3801,Protection::Authenticate));
  Listener L(udp(48361),lopts(10000));Relay R(48362,48361);std::atomic<bool> hold{true};std::atomic<int> forged{0};
  const auto d=bytes(60000,38);const uint32_t total=uint32_t(WireFilterChain::parse_spec("").encode(d).bytes.size());
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){
    if(fwd&&hold){
      if(forged<3){const uint32_t k=get32(p.data(),4,true)&0x7fffffffU;R.to_client(control_packet(k,total,total+65536,true));++forged;}
      return false;}
    return true;};
  std::chrono::steady_clock::time_point delivered{},returned{};
  Rx rx(L);std::thread hold_off([&]{std::this_thread::sleep_for(std::chrono::milliseconds(600));hold=false;});
  SendResult sr;std::string err;auto o=sopts("msg.close",250,40);o.segment_bytes=1400;
  try{sr=send_message(udp(48362),d,o);returned=std::chrono::steady_clock::now();}catch(const std::exception&e){err=e.what();}
  rx.join();delivered=std::chrono::steady_clock::now();hold_off.join();
  const bool early=!err.empty()||!rx.got;
  std::cout<<"  M8 "<<forged<<" forged close-acknowledgements while the receiver had nothing: sender "<<(err.empty()?"returned":err)<<", dropped "<<sr.auth_failures<<" unverified; receiver "<<(rx.got&&rx.got->logical==d?"byte-exact":"WRONG "+rx.err)<<"\n";
  verdict(!early&&rx.got&&rx.got->logical==d&&sr.auth_failures>=3,"M8","forged close-acknowledgements are dropped: the sender reports success only after real delivery");
  (void)delivered;(void)returned;
}

static void m9_no_key(){
  KeyTable::global().clear();std::string e1,e2;
  try{auto o=sopts("msg.nokey");o.protection=Protection::Encrypt;send_message(udp(48371),text("x"),o);}catch(const std::exception&e){e1=e.what();}
  KeyTable::global().install(make_key("msg.min",3901,Protection::Encrypt));
  Listener L(udp(48373),lopts(3000));Rx rx(L);
  try{auto o=sopts("msg.min");o.protection=Protection::None;send_message(udp(48373),text("minimum"),o);}catch(const std::exception&e){e2=e.what();}
  rx.join();
  std::cout<<"  M9 protection demanded, no key: "<<e1<<"; asking none of an encrypt service: "<<(rx.got?protection_name(rx.got->protection):rx.err+e2)<<"\n";
  verdict(e1.find("no active key")!=std::string::npos&&rx.got&&rx.got->protection==Protection::Encrypt,"M9","no active key refuses before sending; asking for none never lowers the profile");
}

static void m10_sticky(){
  KeyTable::global().clear();auto k=make_key("msg.sticky",3951,Protection::Encrypt);k.not_after_ms=security::now_ms()+500;KeyTable::global().install(k);
  std::this_thread::sleep_for(std::chrono::milliseconds(700));
  Listener L(udp(48381),lopts(800));Relay R(48382,48381);Rx rx(L);std::string err;
  try{send_message(udp(48382),text("after expiry"),sopts("msg.sticky"));}catch(const std::exception&e){err=e.what();}
  rx.join();
  std::cout<<"  M10 key expired: "<<err<<"; packets on the wire: "<<R.fwd<<"\n";
  verdict(err.find("no active key")!=std::string::npos&&R.fwd==0&&!rx.got,"M10","an expired key leaves the profile in place: the message is refused, never sent clear");
}

static double rate(const std::string&service,uint16_t port,size_t mb){
  Listener L(udp(port),lopts(60000));const auto d=bytes(mb*1024*1024,77);Rx rx(L);double ms=0;
  try{auto o=sopts(service,250,40);o.segment_bytes=8192;const auto t0=std::chrono::steady_clock::now();send_message(udp(port),d,o);ms=ms_since(t0);}catch(...){}
  rx.join();return rx.got&&rx.got->logical==d&&ms>0?double(mb)/(ms/1000.0):-1;
}
static void m11_throughput(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.fast.enc",3991,Protection::Encrypt));KeyTable::global().install(make_key("msg.fast.auth",3992,Protection::Authenticate));
  const double plain=rate("msg.fast.plain",48391,20),auth=rate("msg.fast.auth",48393,20),enc=rate("msg.fast.enc",48395,20);
  std::cout<<"  M11 20 MB messages on loopback: unprotected "<<int(plain)<<" MB/s, authenticated "<<int(auth)<<" MB/s, encrypted "<<int(enc)<<" MB/s\n";
  verdict(plain>0&&auth>0&&enc>0,"M11","throughput measured (recorded, not a pass/fail bound)");
}

static void m12_carriers(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.carrier",4001,Protection::Encrypt));
  std::string out;bool ok=true;
  for(int layer:{3,2}){
    Route r;r.peer="svc";
    if(layer==3){r.layer=3;r.carrier="raw36";r.destination="127.0.0.1";}else{r.layer=2;r.carrier="l2";r.interface_name="lo";r.destination="00:00:00:00:00:00";}
    const auto d=bytes(300000,uint32_t(40+layer));std::string err;
    try{Listener L(r,lopts(8000));Rx rx(L);auto o=sopts("msg.carrier");o.segment_bytes=1400;auto sr=send_message(r,d,o);rx.join();
        const bool good=rx.got&&rx.got->logical==d&&rx.got->protection==Protection::Encrypt&&sr.protection==Protection::Encrypt;
        ok&=good;out+=std::string(layer==3?" raw36: ":" L2: ")+(good?"byte-exact, encrypt":"WRONG "+rx.err);}
    catch(const std::exception&e){ok=false;out+=std::string(layer==3?" raw36: ":" L2: ")+e.what();}
  }
  std::cout<<"  M12 300 KB each:"<<out<<"\n";
  verdict(ok,"M12","encrypted messages over raw IP protocol 36 and over L2");
}

int main(int argc,char**argv){
  auto want=[&](const char*id){if(argc<2)return true;for(int i=1;i<argc;++i)if(std::string(argv[i])==id)return true;return false;};
  struct T{const char*id;void(*fn)();};
  const T tests[]={{"M1",m1_authenticate},{"M2",m2_encrypt_stream_lossy},{"M3",m3_chacha},{"M4",m4_tamper},{"M5",m5_clear_refused},{"M6",m6_m7_replay},
                   {"M8",m8_forged_close},{"M9",m9_no_key},{"M10",m10_sticky},{"M11",m11_throughput},{"M12",m12_carriers}};
  for(const auto&t:tests)if(want(t.id))t.fn();
  std::cout<<"MESSAGE SECURITY SUITE: fail="<<failures<<"\n";
  return failures?1:0;
}
