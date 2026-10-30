// dev33 interop: a protected message sender (dev33 and later).  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
#include "xtp/xtp_transport.hpp"
#include <iostream>
using namespace xtp;
int main(int,char**argv){Route r;r.peer="p";r.layer=4;r.carrier="udp";r.destination=std::string("127.0.0.1:")+argv[1];
 ServiceKey k;k.service="svc.m";k.key_id=77;k.protection=Protection::Encrypt;k.source="api";for(auto&b:k.secret)b=7;KeyTable::global().install(k);
 SendOptions o;o.service_name="svc.m";o.timeout_ms=100;o.retries=5;
 try{send_message(r,std::vector<uint8_t>(5000,'x'),o);std::cout<<"SENT\n";}catch(const std::exception&e){std::cout<<"REFUSED: "<<e.what()<<"\n";}}
