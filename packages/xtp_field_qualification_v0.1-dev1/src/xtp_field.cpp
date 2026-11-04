// xtp-field: protected named-service sessions between real hosts, for the
// ED209 field run (qualification/field/run_protected_matrix.sh).
// Architecture: Tom Dyer (D-07).  Coding: Claude (Opus 5.5).
//
// It uses libxtp itself (open_session, SessionListener, KeyTable), not a
// separate packet engine, and prints the dev36 protection evidence at both
// ends (docs/SECURITY.md, "Protection evidence").  No secret is ever printed.
//
//   xtp-field probe
//   xtp-field serve --carrier udp|raw36 --bind ADDR --services S[,S] --keys FILE
//                   [--max N] [--idle-s N]
//   xtp-field open  --carrier udp|raw36 --to ADDR --service S --keys FILE|none
//                   [--bytes N] [--protection auto|none|authenticate|encrypt]
//                   [--timeout-ms N] [--expect ok|refused]
//
// ADDR is host:port for udp, host for raw36.  Lines that matter start FIELD_.
// Exit 0 when the outcome matches --expect (default ok), 1 otherwise, 2 on usage.
#include "xtp/xtp_session.hpp"
#include "xtp/xtp_security.hpp"
#include "xtp/xtp_service.hpp"
#include <openssl/evp.h>
#include <sys/socket.h>
#include <sys/utsname.h>
#include <netinet/in.h>
#include <unistd.h>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

using namespace xtp;

namespace {
std::map<std::string,std::string> args(int argc,char**argv,int from){
    std::map<std::string,std::string> a;
    for(int i=from;i<argc;++i){
        std::string k=argv[i];
        if(k.rfind("--",0)!=0||i+1>=argc)throw std::invalid_argument("bad argument: "+k);
        a[k.substr(2)]=argv[++i];
    }
    return a;
}
std::string need(const std::map<std::string,std::string>&a,const std::string&k){
    auto it=a.find(k);if(it==a.end()||it->second.empty())throw std::invalid_argument("missing --"+k);return it->second;
}
std::string opt(const std::map<std::string,std::string>&a,const std::string&k,const std::string&d){
    auto it=a.find(k);return it==a.end()?d:it->second;
}
Route route_of(const std::string&carrier,const std::string&addr){
    Route r;r.peer="field";r.destination=addr;
    if(carrier=="udp"){r.layer=4;r.carrier="udp";}
    else if(carrier=="raw36"){r.layer=3;r.carrier="raw36";}
    else throw std::invalid_argument("carrier must be udp or raw36");
    return r;
}
std::string hex64(uint64_t v){char b[17];std::snprintf(b,sizeof b,"%016llx",(unsigned long long)v);return b;}
std::string sha256(const std::vector<uint8_t>&d){
    unsigned char md[32];unsigned int n=0;EVP_Digest(d.data(),d.size(),md,&n,EVP_sha256(),nullptr);
    std::string s;char b[3];for(unsigned i=0;i<n;++i){std::snprintf(b,sizeof b,"%02x",md[i]);s+=b;}return s;
}
// The key's fields and state now, as xtpNativeSessionEvidence reports them.
std::string key_fields(uint64_t id,const std::string&service,uint64_t serial){
    if(!id)return "keySource=- keyState=-";
    const int64_t now=security::now_ms();
    for(const auto&k:KeyTable::global().list()){
        if(k.key_id!=id)continue;
        if(k.service!=service)return "keySource=- keyState=absent";
        if(serial&&k.serial!=serial)return "keySource=- keyState=replaced";
        std::string st=(k.not_before_ms&&now<k.not_before_ms)?"notyet":(k.not_after_ms&&now>=k.not_after_ms)?"expired":(k.active?"active":"retiring");
        return "keySource="+k.source+" keyState="+st;
    }
    return "keySource=- keyState=absent";
}
std::string session_evidence(const Session&s,const char*role){
    const auto p=s.protection();const uint64_t id=s.key_id();
    return "schema=xtp.protection.evidence/1 bound=session role="+std::string(role)+" service="+s.service_name()+" peer="+s.peer_address()+
        " open="+(s.is_open()?"1":"0")+" protection="+protection_name(p)+" suite="+(p==Protection::None?std::string("-"):std::string(suite_name(s.suite())))+
        " keyId="+(id?hex64(id):std::string("-"))+" keyPrincipal="+(s.key_principal().empty()?std::string("-"):s.key_principal())+
        " profile="+protection_name(KeyTable::global().required(s.service_name()))+" "+key_fields(id,s.service_name(),s.key_serial())+
        " atMs="+std::to_string(security::now_ms());
}
std::string host(){utsname u{};uname(&u);return std::string(u.nodename)+" "+u.release;}
void load_keys(const std::string&path){
    if(path=="none"){std::cout<<"FIELD_KEYS none\n";return;}
    const size_t n=KeyTable::global().load_file(path);
    std::cout<<"FIELD_KEYS loaded="<<n<<" source=file\n";
}
std::vector<uint8_t> pattern(size_t n,uint32_t seed){
    std::vector<uint8_t> d(n);uint32_t x=seed?seed:1;
    for(auto&b:d){x^=x<<13;x^=x>>17;x^=x<<5;b=uint8_t(x);}
    return d;
}

int probe(){
    std::cout<<"FIELD_HOST "<<host()<<"\n";
    std::cout<<"FIELD_CLOCK_MS "<<security::now_ms()<<"\n";
    int fd=socket(AF_INET,SOCK_RAW,36);
    if(fd>=0){std::cout<<"FIELD_RAW36 available\n";close(fd);}else std::cout<<"FIELD_RAW36 unavailable "<<std::strerror(errno)<<"\n";
    fd=socket(AF_INET,SOCK_DGRAM,0);
    if(fd>=0){std::cout<<"FIELD_UDP available\n";close(fd);}else std::cout<<"FIELD_UDP unavailable "<<std::strerror(errno)<<"\n";
    return 0;
}

// Accept up to max sessions, one after another.  Each: read to the end of the
// peer's stream, answer with the bytes reversed, close.
int serve(const std::map<std::string,std::string>&a){
    load_keys(need(a,"keys"));
    SessionListenOptions o;
    const std::string list=need(a,"services");
    for(size_t p=0;;){auto c=list.find(',',p);o.allowed_services.push_back(list.substr(p,c==std::string::npos?std::string::npos:c-p));if(c==std::string::npos)break;p=c+1;}
    const int max=std::stoi(opt(a,"max","1"));const int idle=std::stoi(opt(a,"idle-s","60"));
    SessionListener L(route_of(need(a,"carrier"),need(a,"bind")),o);
    std::cout<<"FIELD_LISTENING carrier="<<need(a,"carrier")<<" bind="<<need(a,"bind")<<" services="<<list<<" host="<<host()<<"\n"<<std::flush;
    int served=0;
    for(int i=0;i<max;++i){
        auto s=L.accept(idle*1000);
        if(!s){std::cout<<"FIELD_IDLE no session within "<<idle<<" s\n";break;}
        std::cout<<"FIELD_ACCEPT "<<session_evidence(*s,"acceptor")<<"\n"<<std::flush;
        try{
            std::vector<uint8_t> got;
            for(;;){auto c=s->read(65536,20000);if(c.end)break;if(c.data.empty())throw std::runtime_error("read timed out");got.insert(got.end(),c.data.begin(),c.data.end());}
            std::vector<uint8_t> back(got.rbegin(),got.rend());
            s->write(back);s->close(10000);
            const auto st=s->stats();
            std::cout<<"FIELD_SERVED service="<<s->service_name()<<" bytes="<<got.size()<<" sha256="<<sha256(got)
                     <<" authFailures="<<st.auth_failures<<" replaysRejected="<<st.replays_rejected<<"\n"<<std::flush;
            ++served;
        }catch(const std::exception&e){std::cout<<"FIELD_SERVE_FAIL "<<e.what()<<"\n"<<std::flush;}
    }
    std::cout<<"FIELD_SERVER_DONE served="<<served<<"\n";
    return 0;
}

int open_(const std::map<std::string,std::string>&a){
    load_keys(need(a,"keys"));
    const std::string carrier=need(a,"carrier"),to=need(a,"to"),service=need(a,"service");
    const std::string expect=opt(a,"expect","ok");const std::string prot=opt(a,"protection","auto");
    const size_t bytes=std::stoul(opt(a,"bytes","1048576"));
    SessionOptions o;o.service_name=service;o.open_timeout_ms=std::stoi(opt(a,"timeout-ms","3000"));
    if(prot!="auto")o.protection=parse_protection(prot);
    // route evidence: the choice open_session is about to make
    {
        Protection want=KeyTable::global().required(service);
        if(o.protection&&uint8_t(*o.protection)>uint8_t(want))want=*o.protection;
        std::string key="keyId=-";
        if(want!=Protection::None){auto k=KeyTable::global().for_open(service,"");if(k){key="keyId="+hex64(k->key_id)+" "+key_fields(k->key_id,service,k->serial);if(uint8_t(k->protection)>uint8_t(want))want=k->protection;}else key="keyId=- openable=0 reason=no_active_key";}
        std::cout<<"FIELD_ROUTE schema=xtp.protection.evidence/1 bound=route carrier="<<carrier<<" to="<<to<<" service="<<service
                 <<" profile="<<protection_name(KeyTable::global().required(service))<<" protection="<<protection_name(want)<<" "<<key<<"\n"<<std::flush;
    }
    const auto t0=std::chrono::steady_clock::now();
    std::unique_ptr<Session> s;
    try{s=open_session(route_of(carrier,to),o);}
    catch(const std::exception&e){
        const double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t0).count();
        if(expect=="refused"){std::cout<<"FIELD_REFUSED_OK after_ms="<<int(ms)<<" reason="<<e.what()<<"\n";return 0;}
        std::cout<<"FIELD_FAIL open after_ms="<<int(ms)<<": "<<e.what()<<"\n";return 1;
    }
    const double open_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t0).count();
    std::cout<<"FIELD_SESSION open_ms="<<int(open_ms)<<" "<<session_evidence(*s,"opener")<<"\n"<<std::flush;
    if(expect=="refused"){std::cout<<"FIELD_FAIL an open that should have been refused was accepted\n";s->abort();return 1;}
    try{
        const auto d=pattern(bytes,uint32_t(bytes*2654435761u));
        const auto t1=std::chrono::steady_clock::now();
        s->write(d);s->shutdown_write();
        std::vector<uint8_t> got;
        for(;;){auto c=s->read(65536,20000);if(c.end)break;if(c.data.empty())throw std::runtime_error("read timed out");got.insert(got.end(),c.data.begin(),c.data.end());}
        const double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-t1).count();
        const bool same=got.size()==d.size()&&std::equal(got.begin(),got.end(),d.rbegin());
        const auto st=s->stats();const std::string ev=session_evidence(*s,"opener");
        s->close(10000);
        if(!same){std::cout<<"FIELD_FAIL echo: sent "<<d.size()<<" got "<<got.size()<<" bytes, not the reversed bytes\n";return 1;}
        char rate[32];std::snprintf(rate,sizeof rate,"%.2f",ms>0?(2.0*d.size()*8/1e6)/(ms/1000):0.0);
        std::cout<<"FIELD_OK carrier="<<carrier<<" service="<<service<<" bytes="<<d.size()<<" sha256="<<sha256(d)<<" echo_ms="<<int(ms)
                 <<" mbit_s_both_ways="<<rate<<" srtt_ms="<<int(st.srtt_ms)<<" retransmitted="<<st.retransmitted_packets
                 <<" authFailures="<<st.auth_failures<<" replaysRejected="<<st.replays_rejected<<" protection="<<protection_name(s->protection())
                 <<" keyId="<<(s->key_id()?hex64(s->key_id()):std::string("-"))<<"\n";
        return 0;
    }catch(const std::exception&e){std::cout<<"FIELD_FAIL transfer: "<<e.what()<<"\n";s->abort();return 1;}
}
}

int main(int argc,char**argv){
    std::ios::sync_with_stdio(true);
    if(argc<2){std::cerr<<"usage: xtp-field probe | serve ... | open ...\n";return 2;}
    try{
        const std::string cmd=argv[1];
        if(cmd=="probe")return probe();
        auto a=args(argc,argv,2);
        if(cmd=="serve")return serve(a);
        if(cmd=="open")return open_(a);
        std::cerr<<"unknown command "<<cmd<<"\n";return 2;
    }catch(const std::invalid_argument&e){std::cerr<<"xtp-field: "<<e.what()<<"\n";return 2;}
    catch(const std::exception&e){std::cout<<"FIELD_FAIL "<<e.what()<<"\n";return 1;}
}
