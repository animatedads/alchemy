// dev30 DIAG hardening tests.
// Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"' (see make test-diag-hardening).
// The packets come from a plain UDP socket, so these tests see exactly what an
// unauthenticated (and possibly forged) source would get back.
//   H1 the wire reason is only the VALUE name: the requested service name is not echoed
//   H2 a malformed FIRST gets MALFORMED with no parser text, and a DIAG is never
//      larger than the packet that caused it (a minimum-size FIRST gets a bare DIAG)
//   H3 per-peer limit: a flood of refused FIRSTs gets at most burst + rate x time
//      DIAGs, and the peer is answered again once its bucket refills
//   H4 the global limit holds when the per-peer limit is set high
//   H5 diag_rate_per_sec = 0 turns DIAG off: the peer gets silence, as from dev28
//   H6 VALUEs 16-23 (reserved for the gateway) are named in a sender's error
#include XTP_TRANSPORT_SRC
#include <iostream>
#include <thread>
using namespace xtp;
// Built with -DXTP_BASELINE_DEV29 against dev29 source to show the problem: the
// dev30 options do not exist there, so H4 to H6 are skipped and H3 runs on dev29 defaults.
#ifdef XTP_BASELINE_DEV29
#define DIAG_OPTS(rate,burst,global)
#else
#define DIAG_OPTS(rate,burst,global) lo.diag_rate_per_sec=rate;lo.diag_burst=burst;lo.diag_global_rate_per_sec=global;
#endif

static int failures=0;
static void verdict(bool ok,const std::string&id,const std::string&what){std::cout<<(ok?"PASS ":"FAIL ")<<id<<" "<<what<<"\n";if(!ok)failures++;}

// A listener in its own thread; it refuses everything it is sent and ends at its timeout.
struct RefusingListener{
  Route r;std::unique_ptr<Listener> l;std::thread t;
  RefusingListener(uint16_t port,ListenOptions lo){
    r.peer="svc";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:"+std::to_string(port);
    if(lo.allowed_services.empty())lo.allowed_services={"only.this"};
    l=std::make_unique<Listener>(r,lo);
    t=std::thread([this]{try{for(;;)l->receive();}catch(...){}});
  }
  ~RefusingListener(){t.join();}
};
struct Client{
  int fd=-1;sockaddr_in to{};
  explicit Client(uint16_t port,int timeout_ms=150){fd=socket(AF_INET,SOCK_DGRAM,0);auto a=ipaddr("127.0.0.1",0);bind(fd,(sockaddr*)&a,sizeof a);to=ipaddr("127.0.0.1",port);set_timeout(fd,timeout_ms);}
  ~Client(){::close(fd);}
  void send(const std::vector<uint8_t>&p){sendto(fd,p.data(),p.size(),0,(sockaddr*)&to,sizeof to);}
  // the next DIAG, with its size; nullopt on timeout
  std::optional<std::pair<Diag,size_t>> diag(){
    std::array<uint8_t,65536> b{};
    for(;;){ssize_t n=recv(fd,b.data(),b.size(),0);if(n<=0)return std::nullopt;auto d=parse_diag(b.data(),size_t(n));if(d)return std::make_pair(*d,size_t(n));}
  }
};
static std::vector<uint8_t> named_first(uint32_t key,const std::string&service,size_t data_bytes){
  return first_packet(key,std::vector<uint8_t>(data_bytes,0x41),true,false,false,{},0,service);
}

static void h1_no_echo(){
  ListenOptions lo;lo.timeout_ms=600;RefusingListener L(46101,lo);
  Client c(46101);const std::string secret="customer.secret.service.name";
  auto f=named_first(101,secret,64);c.send(f);auto d=c.diag();
  std::cout<<"  H1 reason='"<<(d?d->first.reason:std::string("<none>"))<<"'\n";
  verdict(d&&d->first.value==DIAG_SERVICE_NOT_ADMITTED&&d->first.reason=="SERVICE_NOT_ADMITTED"&&d->first.reason.find(secret)==std::string::npos,
          "H1","a refused service is told SERVICE_NOT_ADMITTED and its requested name is not echoed");
}

static void h2_malformed_and_size(){
  ListenOptions lo;lo.timeout_ms=600;lo.allowed_services.clear();
  Route r;r.peer="svc";r.layer=4;r.carrier="udp";r.destination="127.0.0.1:46102";
  Listener l(r,lo);std::thread t([&]{try{for(;;)l.receive();}catch(...){}});
  Client c(46102);
  // A wire-filter envelope (magic XWF1) that claims 255 filters it does not
  // carry: decode_envelope throws "truncated wire-filter envelope", so the
  // listener refuses it as MALFORMED.  64 data bytes here; 5 in the small one.
  auto bad=[](size_t n){std::vector<uint8_t> v(n,0xEE);v[0]='X';v[1]='W';v[2]='F';v[3]='1';v[4]=0xFF;return v;};
  auto big=first_packet(102,bad(64),true);c.send(big);auto d1=c.diag();
  // the smallest FIRST that can be malformed (5 data bytes, padded to 8): 48 bytes
  auto small=first_packet(103,bad(5),true);c.send(small);auto d2=c.diag();
  t.join();
  std::cout<<"  H2 big: trigger="<<big.size()<<" diag="<<(d1?std::to_string(d1->second):"none")<<" reason='"<<(d1?d1->first.reason:"")<<"'"
           <<"; small: trigger="<<small.size()<<" diag="<<(d2?std::to_string(d2->second):"none")<<" reason='"<<(d2?d2->first.reason:"")<<"'\n";
  verdict(d1&&d1->first.value==DIAG_MALFORMED&&d1->first.reason=="MALFORMED"&&d1->second<=big.size(),
          "H2a","a malformed FIRST gets MALFORMED with no parser text, no larger than the FIRST");
  verdict(d2&&d2->first.value==DIAG_MALFORMED&&d2->first.reason.empty()&&d2->second<=small.size(),
          "H2b","a minimum-size FIRST gets a bare DIAG that is no larger than it");
}

static void h3_per_peer_limit(){
  ListenOptions lo;lo.timeout_ms=2500;DIAG_OPTS(10,20,1000)
  RefusingListener L(46103,lo);Client c(46103,100);
  const auto t0=std::chrono::steady_clock::now();
  for(uint32_t k=0;k<300;++k)c.send(named_first(1000+k,"other",32));
  const double sent_s=std::chrono::duration<double>(std::chrono::steady_clock::now()-t0).count();
  unsigned got=0;while(c.diag())++got;
  const double bound=20.0+10.0*sent_s+1.0;
  std::this_thread::sleep_for(std::chrono::milliseconds(1100));
  c.send(named_first(2000,"other",32));auto later=c.diag();
  std::cout<<"  H3 300 refused FIRSTs in "<<int(sent_s*1000)<<" ms -> "<<got<<" DIAGs (bound "<<bound<<"); after 1.1 s: "<<(later?"answered":"silent")<<"\n";
  verdict(got>=20&&got<=bound,"H3a","a flood from one peer gets at most burst + rate x time DIAGs");
  verdict(bool(later),"H3b","the peer is answered again once its bucket refills");
}

#ifndef XTP_BASELINE_DEV29
static void h4_global_limit(){
  ListenOptions lo;lo.timeout_ms=1500;lo.diag_rate_per_sec=1000;lo.diag_burst=1000;lo.diag_global_rate_per_sec=5;
  RefusingListener L(46104,lo);Client c(46104,100);
  const auto t0=std::chrono::steady_clock::now();
  for(uint32_t k=0;k<200;++k)c.send(named_first(3000+k,"other",32));
  const double sent_s=std::chrono::duration<double>(std::chrono::steady_clock::now()-t0).count();
  unsigned got=0;while(c.diag())++got;
  const double bound=10.0+5.0*sent_s+1.0;
  std::cout<<"  H4 200 refused FIRSTs -> "<<got<<" DIAGs (global bound "<<bound<<")\n";
  verdict(got>=1&&got<=bound,"H4","the global DIAG limit holds when the per-peer limit is high");
}

static void h5_off(){
  ListenOptions lo;lo.timeout_ms=600;lo.diag_rate_per_sec=0;RefusingListener L(46105,lo);
  Client c(46105,300);c.send(named_first(4000,"other",32));auto d=c.diag();
  verdict(!d,"H5","diag_rate_per_sec = 0 sends no DIAG (the dev28 behaviour)");
}

static void h6_reserved_names(){
  bool ok=true;std::string all;
  for(uint32_t v=16;v<=23;++v){
    auto p=diag_packet(77,DIAG_CONTEXT_REFUSED,v,"",true);std::string err;
    try{raise_if_diag(p.data(),p.size(),77);}catch(const std::exception&e){err=e.what();}
    if(err.empty()||err.find("UNKNOWN")!=std::string::npos)ok=false;
    all+=" "+std::string(diag_value_name(v));
  }
  std::cout<<"  H6"<<all<<"\n";
  verdict(ok&&std::string(diag_value_name(24))=="UNKNOWN","H6","VALUEs 16-23 are named in the sender's error; 24 is still UNKNOWN");
}
#endif

int main(){
  h1_no_echo();h2_malformed_and_size();h3_per_peer_limit();
#ifndef XTP_BASELINE_DEV29
  h4_global_limit();h5_off();h6_reserved_names();
#endif
  std::cout<<"DIAG HARDENING SUITE: fail="<<failures<<"\n";
  return failures?1:0;
}
