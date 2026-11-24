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
//   M13 (dev34) multipath: chunks protected per service; a clear chunk claiming the same
//       transfer is never mixed in; a malformed chunk does not end receive()
// Third review (dev34):
//   M14 H1 a clear FIRST with the return bit set is not delivered
//   M15 H2 a clear FIRST flagged INTERACTIVE and AUTHENTICATED is not delivered
//   M16 M1 two listeners answering the same FIRST never use the same counter
//   M17 M2 an empty protected message is delivered
//   M18 L2 a protected segment too small for the open block and tail is refused
//   M19 L1 a finished context is evicted before one in the middle of a stream
//   M20 L3 a key revoked mid-stream stops the send
//   M21 (dev36) a new secret under the same key id mid-stream stops the send, as a revocation does
//   M22 (dev37) the same secret held for another principal, or with another suite, ends the session
//   M23 (dev37) multipath chunks under an old and a new secret are never joined into one transfer
//   M24 (dev37) close() from another thread ends a receive() that waits with no timeout
#include XTP_TRANSPORT_SRC
#include "xtp/xtp_multipath.hpp"
#include <atomic>
#include <functional>
#include <iostream>
#include <random>
#include <thread>
#include <fstream>
#include <unistd.h>
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

static size_t rss_bytes(){std::ifstream f("/proc/self/statm");size_t pages=0,res=0;f>>pages>>res;return res*size_t(sysconf(_SC_PAGESIZE));}
static std::vector<uint8_t> xmp1(uint64_t tid,uint32_t index,uint32_t count,uint32_t total,size_t n){
  std::vector<uint8_t> f(32+n,'F');const char m[4]={'X','M','P','1'};std::copy(m,m+4,f.begin());
  auto put=[&](size_t o,uint32_t v){f[o]=uint8_t(v>>24);f[o+1]=uint8_t(v>>16);f[o+2]=uint8_t(v>>8);f[o+3]=uint8_t(v);};
  put(4,1);for(int i=0;i<8;++i)f[8+size_t(i)]=uint8_t(tid>>(56-8*i));put(16,index);put(20,count);put(24,total);put(28,uint32_t(n));
  return f;
}
static void m13_multipath(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.multi",4101,Protection::Encrypt));
  std::vector<Route> routes{udp(48401),udp(48402)};
  ListenOptions lo=lopts(5000);std::optional<MultipathReceiveResult> got;std::string err;std::atomic<bool> done{false};
  MultipathListener L(routes,lo);
  std::thread rx([&]{try{got=L.receive();}catch(const std::exception&e){err=e.what();}done=true;});
  std::thread watchdog([&]{for(int i=0;i<300&&!done;++i)std::this_thread::sleep_for(std::chrono::milliseconds(100));if(!done){err+=" (watchdog: receive did not return in 30 s)";L.close();}});
  const uint64_t tid=0x5eed5eed5eedULL;const auto d=bytes(200000,43);
  SendOptions co;co.timeout_ms=200;co.retries=5;
  // a clear chunk claiming chunk 0 of the protected transfer's id
  send_message(routes[0],xmp1(tid,0,13,uint32_t(d.size()),16),co);
  // a chunk count of 2^32-1 under its own transfer id: dropped by the bound
  send_message(routes[1],xmp1(tid+1,0,0xffffffffu,1000,16),co);
  // 40 transfers each claiming 2^20 chunks (within the bounds): no slots allocated up front
  const size_t before=rss_bytes();
  for(uint32_t i=0;i<40;++i)send_message(routes[i%2],xmp1(tid+100+i,0,1u<<20,1u<<20,16),co);
  const size_t grew=rss_bytes()>before?rss_bytes()-before:0;
  MultipathOptions mo;mo.chunk_bytes=16384;mo.transfer_id=tid;mo.generation=1;mo.send.service_name="msg.multi";mo.send.segment_bytes=1400;
  try{send_multipath(routes,d,mo);}catch(const std::exception&e){err+=std::string(" send: ")+e.what();}
  rx.join();watchdog.join();
  std::cout<<"  M13 200 KB over 2 paths after a clear chunk for the same id, a 2^32-1 count and 40 transfers claiming 2^20 chunks: "<<(got?(got->logical==d?"byte-exact":"WRONG"):"none "+err)<<", protection "<<(got?protection_name(got->protection):"-")<<", key "<<(got?got->key_id:0)<<"; memory grew "<<grew/1024<<" KB (eager slots would be about 960 MB)\n";
  verdict(got&&got->logical==d&&got->protection==Protection::Encrypt&&got->key_id==4101&&got->service_name=="msg.multi"&&grew<64u*1024u*1024u,"M13","multipath chunks are protected per service; a clear chunk is never mixed in; claimed chunk counts commit no memory");
}

static uint32_t answer_value(RawUdp&u){for(int i=0;i<4;++i){auto r=u.recv(500);if(r.empty())return 0;if(is_type(r,TYPE_DIAG)){auto d=parse_diag(r.data(),r.size());return d?d->value:0;}if(is_type(r,TYPE_CNTL))return 1;}return 0;}

static void m14_return_bit(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.rb",4201,Protection::Encrypt));
  Listener L(udp(48411),lopts(1200));Rx rx(L);
  auto env=WireFilterChain::parse_spec("").encode(text("return bit bypass")).bytes;
  auto pkt=first_packet(4242,env,true,false,false,{},0,"msg.rb");
  put32(pkt,4,4242u|0x80000000U,true);reseal(pkt);
  RawUdp u;u.send(48411,pkt);const uint32_t a=answer_value(u);rx.join();
  // and a clear DATA with the return bit, slipped in ahead of each genuine DATA of an authenticated stream
  KeyTable::global().install(make_key("msg.rb2",4202,Protection::Authenticate));
  Listener L2(udp(48409),lopts(10000));Relay R(48410,48409);std::atomic<int> slipped{0};
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){
    if(fwd&&is_type(p,TYPE_DATA)&&slipped<5){
      // replace a genuine DATA by a clear one at the same sequence, with the return bit
      const uint32_t k=get32(p.data(),4,true),seq=get32(p.data(),16,true);
      std::vector<uint8_t> evil(1376,'X');
      p=payload_packet(TYPE_DATA,k,seq,evil,true,false,false,false,true,{},0);put32(p,4,k|0x80000000U,true);reseal(p);++slipped;}   // payload_packet masks the bit
    return true;};
  const auto d=bytes(100000,44);Rx rx2(L2);std::string e2;
  try{auto o=sopts("msg.rb2");o.segment_bytes=1400;send_message(udp(48410),d,o);}catch(const std::exception&e){e2=e.what();}
  rx2.join();
  std::cout<<"  M14 clear FIRST with the return bit to msg.rb: listener "<<(rx.got?"DELIVERED":rx.err)<<", answer "<<a<<"; "<<slipped<<" genuine DATA replaced in transit by clear DATA with the return bit: "<<(rx2.got?(rx2.got->logical==d?"data byte-exact":"DATA CHANGED"):"nothing "+e2)<<"\n";
  verdict(!rx.got&&a==0&&slipped>0&&rx2.got&&rx2.got->logical==d,"M14","a FIRST or DATA with the return bit set is dropped: never delivered, never answered, never mixed into a stream");
}

static void m15_interactive_flag(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.ia",4301,Protection::Encrypt));
  Listener L(udp(48413),lopts(1200));Rx rx(L);
  auto env=WireFilterChain::parse_spec("").encode(text("interactive flag bypass")).bytes;
  auto sd=encode_named_service("msg.ia",true,uint8_t(XTP_SERVICE_FLAG_INTERACTIVE|XTP_SERVICE_FLAG_AUTHENTICATED));
  sd.insert(sd.end(),env.begin(),env.end());
  auto pkt=payload_packet(TYPE_FIRST,4343,0,sd,true,false,false,true,true,{},0);
  RawUdp u;u.send(48413,pkt);u.recv(300);rx.join();
  std::cout<<"  M15 clear FIRST flagged INTERACTIVE|AUTHENTICATED to msg.ia: listener "<<(rx.got?"DELIVERED":rx.err)<<"\n";
  verdict(!rx.got,"M15","a FIRST flagged interactive (and claiming protection) is never delivered as a message");
}

static void m16_receiver_counters(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.ctr",4401,Protection::Authenticate));
  Listener A(udp(48415),lopts(3000));Relay R(48416,48415);std::vector<uint8_t> first;std::mutex fm;
  R.hook=[&](std::vector<uint8_t>&p,bool fwd,unsigned long){if(fwd&&is_type(p,TYPE_FIRST)){std::lock_guard<std::mutex> g(fm);if(first.empty())first=p;}return true;};
  {Rx rx(A);send_message(udp(48416),text("one"),sopts("msg.ctr"));rx.join();}
  std::vector<uint64_t> ctrs;
  for(uint16_t port:{uint16_t(48417),uint16_t(48418)}){
    Listener B(udp(port),lopts(1000));Rx rx(B);RawUdp u;{std::lock_guard<std::mutex> g(fm);u.send(port,first);}
    for(int i=0;i<3;++i){auto r=u.recv(400);if(r.empty())break;if(is_type(r,TYPE_CNTL)&&r.size()>=HEADER+CONTROL+detail::TAIL+TRAILER){ctrs.push_back(detail::from_be64(r.data()+r.size()-TRAILER-detail::TAIL));break;}}
    rx.join();
  }
  std::cout<<"  M16 the same FIRST at two listeners holding the key: their first counters "<<(ctrs.size()>0?std::to_string(ctrs[0]):"-")<<" and "<<(ctrs.size()>1?std::to_string(ctrs[1]):"-")<<"\n";
  verdict(ctrs.size()==2&&ctrs[0]!=ctrs[1]&&ctrs[0]>(uint64_t(1)<<61)&&ctrs[1]>(uint64_t(1)<<61),"M16","two listeners answering one FIRST start from different random counters: no AEAD nonce repeats");
}

static void m17_empty(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.empty",4501,Protection::Encrypt));
  Listener L(udp(48421),lopts(3000));Rx rx(L);std::string err;
  try{send_message(udp(48421),{},sopts("msg.empty"));}catch(const std::exception&e){err=e.what();}
  rx.join();
  std::cout<<"  M17 empty protected message: "<<(err.empty()?"sent":err)<<"; received "<<(rx.got?std::to_string(rx.got->logical.size())+" bytes, "+protection_name(rx.got->protection):rx.err)<<"\n";
  verdict(err.empty()&&rx.got&&rx.got->logical.empty()&&rx.got->protection==Protection::Encrypt,"M17","an empty protected message is sent as one FIRST and delivered");
}

static void m18_small_segment(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.small",4601,Protection::Encrypt));
  std::string err;auto o=sopts("msg.small");o.segment_bytes=64;
  try{send_message(udp(48423),bytes(1000,46),o);}catch(const std::exception&e){err=e.what();}
  std::cout<<"  M18 segment_bytes 64: "<<err<<"\n";
  verdict(err.find("too small for a protected message")!=std::string::npos,"M18","a protected segment that cannot hold the open block and tail is refused");
}

static void m19_eviction(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.evict",4701,Protection::Authenticate));
  ListenOptions lo=lopts(20000);lo.protected_contexts=2;Listener L(udp(48425),lo);
  std::vector<ReceiveResult> got;std::mutex gm;std::atomic<bool> stop{false};
  std::thread rx([&]{while(!stop){try{auto r=L.receive();std::lock_guard<std::mutex> g(gm);got.push_back(r);if(got.size()==3)return;}catch(...){return;}}});
  const auto big=bytes(400000,47);std::string err;
  std::thread a([&]{try{auto o=sopts("msg.evict",250,20);o.segment_bytes=1400;o.max_rate_bytes_per_sec=400000;send_message(udp(48425),big,o);}catch(const std::exception&e){err=e.what();}});
  std::this_thread::sleep_for(std::chrono::milliseconds(200));
  try{send_message(udp(48425),text("b"),sopts("msg.evict"));send_message(udp(48425),text("c"),sopts("msg.evict"));}catch(const std::exception&e){err+=" small: "+std::string(e.what());}
  a.join();rx.join();stop=true;
  bool big_ok=false;for(auto&r:got)if(r.logical==big)big_ok=true;
  std::cout<<"  M19 a 400 KB stream with two small messages arriving during it, protected_contexts=2: stream "<<(big_ok?"byte-exact":"LOST "+err)<<", messages received "<<got.size()<<"\n";
  verdict(big_ok&&err.empty()&&got.size()==3,"M19","a finished context is evicted before one in the middle of a stream");
}

static void m20_revoked_mid_stream(){
  KeyTable::global().clear();KeyTable::global().install(make_key("msg.revoke",4801,Protection::Encrypt));
  // capture this process's stderr, where the listener logs a forgotten context
  const std::string logf="/tmp/claude-0/-home-claude/cb53fb2f-253f-5d25-837b-5e3749f69612/scratchpad/m20_stderr.log";
  fflush(stderr);const int saved=dup(2);{FILE*f=fopen(logf.c_str(),"w");dup2(fileno(f),2);fclose(f);}
  Listener L(udp(48427),lopts(8000));Rx rx(L);std::string err;
  // revoked 1.1 s in: the receiver's once-a-second check falls before the sender's next one
  std::thread revoker([&]{std::this_thread::sleep_for(std::chrono::milliseconds(1100));KeyTable::global().revoke(4801);});
  try{auto o=sopts("msg.revoke",250,20);o.segment_bytes=1400;o.max_rate_bytes_per_sec=500000;send_message(udp(48427),bytes(2000000,48),o);}catch(const std::exception&e){err=e.what();}
  revoker.join();rx.join();
  fflush(stderr);dup2(saved,2);close(saved);
  std::ifstream in(logf);std::string line;int forgotten=0;while(std::getline(in,line))if(line.find("revoked, replaced or expired; context forgotten")!=std::string::npos)++forgotten;
  std::cout<<"  M20 key revoked 1.1 s into a 4 s stream: sender "<<(err.empty()?"FINISHED":err)<<"; receiver "<<(rx.got?"DELIVERED":"nothing")<<", contexts it forgot "<<forgotten<<"\n";
  verdict(err.find("revoked")!=std::string::npos&&!rx.got&&forgotten>=1,"M20","a key revoked mid-stream ends the context at the receiver too, and stops the send");
}

// dev36 (evidence review 3): the secret under a key id replaced mid-stream
// (a reload with a changed key) ends the context as a revocation would.
static void m21_replaced_mid_stream(){
  KeyTable::global().clear();auto k=make_key("msg.replace",4901,Protection::Encrypt);KeyTable::global().install(k);
  const std::string logf="/tmp/claude-0/-home-claude/cb53fb2f-253f-5d25-837b-5e3749f69612/scratchpad/m21_stderr.log";
  fflush(stderr);const int saved=dup(2);{FILE*f=fopen(logf.c_str(),"w");dup2(fileno(f),2);fclose(f);}
  Listener L(udp(48429),lopts(8000));Rx rx(L);std::string err;
  // the same key again first (same secret: nothing changes), then a new secret
  std::thread replacer([&]{std::this_thread::sleep_for(std::chrono::milliseconds(400));KeyTable::global().install(k);
    std::this_thread::sleep_for(std::chrono::milliseconds(700));auto n=make_key("msg.replace",4901,Protection::Encrypt);KeyTable::global().install(n);});
  try{auto o=sopts("msg.replace",250,20);o.segment_bytes=1400;o.max_rate_bytes_per_sec=500000;send_message(udp(48429),bytes(2000000,49),o);}catch(const std::exception&e){err=e.what();}
  replacer.join();rx.join();
  fflush(stderr);dup2(saved,2);close(saved);
  std::ifstream in(logf);std::string line;int forgotten=0;while(std::getline(in,line))if(line.find("replaced or expired; context forgotten")!=std::string::npos)++forgotten;
  // and a session: the same secret again keeps it, a new one ends it
  KeyTable::global().clear();auto s1=make_key("ses.replace",4902,Protection::Encrypt);KeyTable::global().install(s1);
  SessionListener SL(udp(48431));std::unique_ptr<Session> acc;std::thread at([&]{acc=SL.accept(3000);});
  SessionOptions so;so.service_name="ses.replace";auto c=open_session(udp(48431),so);at.join();
  KeyTable::global().install(s1);std::this_thread::sleep_for(std::chrono::milliseconds(1500));
  const bool kept=c->is_open()&&acc&&acc->is_open();
  const auto t0=std::chrono::steady_clock::now();KeyTable::global().install(make_key("ses.replace",4902,Protection::Encrypt));
  while(c->is_open()&&std::chrono::steady_clock::now()-t0<std::chrono::seconds(3))std::this_thread::sleep_for(std::chrono::milliseconds(20));
  const auto took=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-t0).count();
  std::cout<<"  M21 secret replaced 1.1 s into a 4 s stream: sender "<<(err.empty()?"FINISHED":err)<<"; receiver "<<(rx.got?"DELIVERED":"nothing")<<", contexts it forgot "<<forgotten
           <<"; session kept after the same secret: "<<(kept?"yes":"NO")<<", closed "<<took<<" ms after a new one: "<<c->error()<<"\n";
  verdict(err.find("replaced")!=std::string::npos&&!rx.got&&forgotten>=1&&kept&&!c->is_open()&&took<2500,"M21","a new secret under the same key id ends message and session contexts; the same secret again changes nothing");
}

// dev37 (second review 4): who holds a key, or how it is used, is part of it
static void m22_holder_changed(){
  std::string out;bool ok=true;
  for(int variant=0;variant<2;++variant){
    KeyTable::global().clear();auto k=make_key("ses.holder",5001+uint64_t(variant),Protection::Encrypt);KeyTable::global().install(k);
    SessionListener SL(udp(uint16_t(48433+variant)));std::unique_ptr<Session> acc;std::thread at([&]{acc=SL.accept(3000);});
    SessionOptions so;so.service_name="ses.holder";auto c=open_session(udp(uint16_t(48433+variant)),so);at.join();
    auto changed=k;
    if(variant==0)changed.principal="service:ses.holder/client:mallory";else changed.suite=CipherSuite::ChaCha20Poly1305;
    const auto t0=std::chrono::steady_clock::now();KeyTable::global().install(changed);
    while(c->is_open()&&std::chrono::steady_clock::now()-t0<std::chrono::seconds(3))std::this_thread::sleep_for(std::chrono::milliseconds(20));
    const auto took=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-t0).count();
    out+=std::string(variant==0?" principal changed: ":" suite changed: ")+(c->is_open()?"STILL OPEN":"closed after "+std::to_string(took)+" ms");
    ok=ok&&!c->is_open()&&took<2500;
  }
  std::cout<<"  M22 same secret under the same id:"<<out<<"\n";
  verdict(ok,"M22","the same secret held for another principal, or used with another suite, ends the session as a new secret does");
}

// dev37 (second review 3): chunk 0 under the old secret, chunk 1 under the new one
static void m23_multipath_secret_split(){
  KeyTable::global().clear();auto k=make_key("msg.split",5101,Protection::Encrypt);KeyTable::global().install(k);
  std::vector<Route> routes{udp(48437)};
  MultipathListener L(routes,lopts(3000));std::optional<MultipathReceiveResult> got;std::string err;
  std::atomic<bool> done{false};
  std::thread rx([&]{try{got=L.receive();}catch(const std::exception&e){err=e.what();}done=true;});
  // receive() waits for a whole transfer: 6 s after starting, close() ends it (M24)
  std::thread watchdog([&]{for(int i=0;i<60&&!done;++i)std::this_thread::sleep_for(std::chrono::milliseconds(100));if(!done)L.close();});
  const uint64_t tid=0x5b11750b11ULL;SendOptions co;co.timeout_ms=200;co.retries=5;co.service_name="msg.split";
  std::string e0,e1;
  try{send_message(routes[0],xmp1(tid,0,2,32,16),co);}catch(const std::exception&e){e0=e.what();}
  KeyTable::global().install(make_key("msg.split",5101,Protection::Encrypt));   // a new secret under the same id
  try{send_message(routes[0],xmp1(tid,1,2,32,16),co);}catch(const std::exception&e){e1=e.what();}
  rx.join();watchdog.join();
  std::cout<<"  M23 chunk 0 under the old secret, chunk 1 under the new: "<<(got?"DELIVERED AS ONE TRANSFER":"not joined"+(err.empty()?std::string():" ("+err+")"))<<"; sends: "<<(e0.empty()?"ok":e0)<<" / "<<(e1.empty()?"ok":e1)<<"\n";
  verdict(!got&&e0.empty()&&e1.empty(),"M23","multipath chunks sent under an old and a new secret are never joined into one transfer");
}

// dev37: found while writing M23.  close() used to close the descriptor under a
// receive() waiting in recvfrom; the number could then be reused by a new
// socket, and the waiting thread blocked on that socket instead.
static void m24_close_wakes_receive(){
  KeyTable::global().clear();
  Listener L(udp(48439),lopts(0));   // no timeout: receive() waits until something arrives or close()
  std::atomic<bool> done{false};std::string err;
  std::thread rx([&]{try{L.receive();}catch(const std::exception&e){err=e.what();}done=true;});
  std::this_thread::sleep_for(std::chrono::milliseconds(200));
  const auto t0=std::chrono::steady_clock::now();L.close();
  // a new socket straight after close(): under the old code it could take the closed number
  int other=socket(AF_INET,SOCK_DGRAM,0);
  while(!done&&std::chrono::steady_clock::now()-t0<std::chrono::seconds(3))std::this_thread::sleep_for(std::chrono::milliseconds(10));
  const auto took=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-t0).count();
  if(!done){::shutdown(other,SHUT_RDWR);}   // free a thread stuck on the reused number, so the test can end
  if(other>=0)::close(other);
  if(!done)std::this_thread::sleep_for(std::chrono::milliseconds(200));
  if(done)rx.join();else rx.detach();
  std::cout<<"  M24 close() from another thread: receive "<<(done?"returned after "+std::to_string(took)+" ms ("+err+")":"STILL WAITING after 3 s")<<"\n";
  verdict(done&&took<1000&&err.find("closed")!=std::string::npos,"M24","close() from another thread ends a receive() that waits with no timeout");
}

int main(int argc,char**argv){
  auto want=[&](const char*id){if(argc<2)return true;for(int i=1;i<argc;++i)if(std::string(argv[i])==id)return true;return false;};
  struct T{const char*id;void(*fn)();};
  const T tests[]={{"M1",m1_authenticate},{"M2",m2_encrypt_stream_lossy},{"M3",m3_chacha},{"M4",m4_tamper},{"M5",m5_clear_refused},{"M6",m6_m7_replay},
                   {"M8",m8_forged_close},{"M9",m9_no_key},{"M10",m10_sticky},{"M11",m11_throughput},{"M12",m12_carriers},{"M13",m13_multipath},
                   {"M14",m14_return_bit},{"M15",m15_interactive_flag},{"M16",m16_receiver_counters},{"M17",m17_empty},{"M18",m18_small_segment},
                   {"M19",m19_eviction},{"M20",m20_revoked_mid_stream},{"M21",m21_replaced_mid_stream},{"M22",m22_holder_changed},{"M23",m23_multipath_secret_split},{"M24",m24_close_wakes_receive}};
  for(const auto&t:tests)if(want(t.id))t.fn();
  std::cout<<"MESSAGE SECURITY SUITE: fail="<<failures<<"\n";
  return failures?1:0;
}
