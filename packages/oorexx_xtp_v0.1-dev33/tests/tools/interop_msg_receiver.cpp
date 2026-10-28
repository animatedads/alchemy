// dev33 interop: a plain message listener (any libxtp version).  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
#include "xtp/xtp_transport.hpp"
#include <iostream>
using namespace xtp;
int main(int,char**argv){Route r;r.peer="p";r.layer=4;r.carrier="udp";r.destination=std::string("127.0.0.1:")+argv[1];
 ListenOptions o;o.timeout_ms=4000;Listener L(r,o);std::cout<<"READY"<<std::endl;
 try{auto x=L.receive();std::cout<<"RECEIVED "<<x.logical.size()<<" bytes\n";}catch(const std::exception&e){std::cout<<"NOTHING: "<<e.what()<<"\n";}}
