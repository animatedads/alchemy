// NEGATIVE TEST E7 (dev26): replay suppression is per (peer host, KEY, payload)
// and bounded.
// Part A (both versions): key 777 "m" from 127.0.0.1, key 777 from 127.0.0.2,
//   then key 777 "m" from 127.0.0.1 again (a genuine retransmission).
//   Expected replay flags: no, no, yes.  dev25 keys on KEY alone and wrongly
//   suppresses the second host.
// Part C (both versions): same host, same KEY, DIFFERENT payload, as when two
//   XMP1 chunks of different transfers collide on the 31-bit KEY.  Expected:
//   delivered.  dev25 ACKs it and silently drops it.
// Part B (dev26 only, -DXTP_DEV26): window of 2 entries; keys 1,2,3 then 1 and 3
//   resent with identical payloads.  Expected: key 1 was evicted and is
//   delivered again; key 3 is a replay.
// Build: -DXTP_TRANSPORT_SRC='"path/to/xtp_transport.cpp"'
#include XTP_TRANSPORT_SRC
#include <iostream>
#include <thread>
using namespace xtp;
static ReceiveResult from_host(Listener&l,const char*src_ip,uint16_t dport,uint32_t key,const std::string&msg){
  ReceiveResult got; std::string err;
  std::thread t([&]{ try{ got=l.receive(); }catch(const std::exception&e){ err=e.what(); } });
  std::vector<uint8_t> logical(msg.begin(),msg.end());
  auto env=WireFilterChain::parse_spec("").encode(logical).bytes;
  auto pkt=first_packet(key,env,true);
  int s=socket(AF_INET,SOCK_DGRAM,0); auto src=ipaddr(src_ip,0); bind(s,(sockaddr*)&src,sizeof src);
  auto d=ipaddr("127.0.0.1",dport); sendto(s,pkt.data(),pkt.size(),0,(sockaddr*)&d,sizeof d); close(s);
  t.join(); if(!err.empty()) std::cout<<"listener error: "<<err<<"\n";
  return got;
}
int main(){
  int rc=0;
  { Route lr; lr.peer="svc"; lr.layer=4; lr.carrier="udp"; lr.destination="127.0.0.1:45301";
    ListenOptions lo; lo.timeout_ms=2000; Listener l(lr,lo);
    auto a=from_host(l,"127.0.0.1",45301,777,"from-host-1");
    auto b=from_host(l,"127.0.0.2",45301,777,"from-host-2");
    auto c=from_host(l,"127.0.0.1",45301,777,"from-host-1");
    std::cout<<"A: host1 key777 replay="<<a.replay<<" | host2 key777 replay="<<b.replay<<" data="<<std::string(b.logical.begin(),b.logical.end())<<" | host1 again replay="<<c.replay<<"\n";
    if(a.replay||b.replay||!c.replay||std::string(b.logical.begin(),b.logical.end())!="from-host-2"){ std::cout<<"FAIL A: replay must be scoped per peer host\n"; rc=1; }
    else std::cout<<"PASS A: replay scoped per peer host; identical retransmission suppressed\n";
    auto d=from_host(l,"127.0.0.1",45301,777,"different-context-same-key");
    std::cout<<"C: host1 key777 different payload replay="<<d.replay<<" data="<<std::string(d.logical.begin(),d.logical.end())<<"\n";
    if(d.replay||std::string(d.logical.begin(),d.logical.end())!="different-context-same-key"){ std::cout<<"FAIL C: a colliding KEY with a different payload was dropped as a replay\n"; rc=1; }
    else std::cout<<"PASS C: colliding KEY with different payload delivered\n";
  }
#ifdef XTP_DEV26
  { Route lr; lr.peer="svc"; lr.layer=4; lr.carrier="udp"; lr.destination="127.0.0.1:45302";
    ListenOptions lo; lo.timeout_ms=2000; lo.replay_window_entries=2; Listener l(lr,lo);
    from_host(l,"127.0.0.1",45302,1,"k1"); from_host(l,"127.0.0.1",45302,2,"k2"); from_host(l,"127.0.0.1",45302,3,"k3");
    auto e1=from_host(l,"127.0.0.1",45302,1,"k1"); auto e3=from_host(l,"127.0.0.1",45302,3,"k3");
    std::cout<<"B: window=2 key1-after-eviction replay="<<e1.replay<<" key3 replay="<<e3.replay<<"\n";
    if(e1.replay||!e3.replay){ std::cout<<"FAIL B: window is not bounded as specified\n"; rc=1; }
    else std::cout<<"PASS B: replay window bounded at 2 entries\n";
    bool refused=false; try{ ListenOptions z; z.replay_window_entries=0; Route zr=lr; zr.destination="127.0.0.1:45303"; Listener bad(zr,z); }catch(const std::exception&){ refused=true; }
    if(!refused){ std::cout<<"FAIL B: replay_window_entries=0 accepted\n"; rc=1; } else std::cout<<"PASS B: replay_window_entries=0 refused\n";
  }
#endif
  return rc;
}
