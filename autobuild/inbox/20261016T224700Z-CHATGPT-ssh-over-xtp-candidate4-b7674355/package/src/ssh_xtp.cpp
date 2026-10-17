// SSH over XTP proof-of-integration. Transport: libxtp v0.1-dev22.
// Security: 256-bit shared-key HMAC over all application frames, challenged
// server admission, local mode gate, OpenSSH still provides SSH security.
// Scope: one authorized client/one active session per gateway process.
#include "xtp/xtp_socket.hpp"
#include "operational/operational_planner.hpp"
#include <openssl/crypto.h>
#include <openssl/hmac.h>
#include <openssl/rand.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <poll.h>
#include <unistd.h>
#include <signal.h>
#include <atomic>
#include <chrono>
#include <cstring>
#include <cerrno>
#include <fstream>
#include <sstream>
#include <iostream>
#include <map>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>
#include <array>
#include <algorithm>
#include <memory>

namespace {
using Byte = uint8_t;
using Bytes = std::vector<Byte>;
constexpr size_t HLEN=28, TAG=32, MAX_PAYLOAD=1024;
enum Type : uint8_t { OPEN=1,CHALLENGE=2,PROOF=3,READY=4,DATA=5,FIN=6,DENY=7,SEALED=8 };
enum class Mode { Open, Locked, Sealed };
struct Frame {Type type;uint64_t sid=0,seq=0;Bytes payload;};
std::atomic<bool> shutting{false};
void signal_handler(int) {shutting=true;}
void put32(Bytes& v,uint32_t n){for(int i=3;i>=0;--i)v.push_back(Byte(n>>(i*8)));}
void put64(Bytes& v,uint64_t n){for(int i=7;i>=0;--i)v.push_back(Byte(n>>(i*8)));}
uint32_t get32(const Byte*p){uint32_t n=0;for(int i=0;i<4;i++)n=(n<<8)|p[i];return n;}
uint64_t get64(const Byte*p){uint64_t n=0;for(int i=0;i<8;i++)n=(n<<8)|p[i];return n;}
std::string syserr(const std::string&s){return s+": "+std::strerror(errno);}
void fail(const std::string&s){throw std::runtime_error(s);}
std::array<Byte,32> key_from_file(const std::string& file){
 int fd=::open(file.c_str(),O_RDONLY|O_CLOEXEC|O_NOFOLLOW);if(fd<0)fail(syserr("secure key open"));
 struct stat st{};if(fstat(fd,&st)||!S_ISREG(st.st_mode)||st.st_size>128||st.st_size<64||
    (st.st_mode&077)!=0||(st.st_uid!=geteuid()&&st.st_uid!=0)) {::close(fd);fail("key must be regular, owned by root/service uid, and have no group/other permissions");}
 char b[129]{};ssize_t n=::read(fd,b,sizeof(b));::close(fd);if(n<64||n>66)fail("key must be 64 hex digits and optional newline");
 if(n>64 && !(n==65&&b[64]=='\n'))fail("invalid key terminator");
 std::array<Byte,32> key{};
 auto nib=[](char c)->int{if(c>='0'&&c<='9')return c-'0';if(c>='a'&&c<='f')return c-'a'+10;if(c>='A'&&c<='F')return c-'A'+10;return -1;};
 for(int i=0;i<32;i++){int a=nib(b[2*i]),c=nib(b[2*i+1]);if(a<0||c<0)fail("invalid key hex");key[i]=Byte(a*16+c);}OPENSSL_cleanse(b,sizeof(b));return key;
}
Bytes encode(const Frame& f,const std::array<Byte,32>& key){
 if(f.payload.size()>MAX_PAYLOAD)fail("oversized SSH-XTP application frame");
 Bytes b{'S','X','T','P',1,Byte(f.type),0,0};put64(b,f.sid);put64(b,f.seq);put32(b,uint32_t(f.payload.size()));
 b.insert(b.end(),f.payload.begin(),f.payload.end());Byte hash[EVP_MAX_MD_SIZE]{};unsigned len=0;
 if(!HMAC(EVP_sha256(),key.data(),int(key.size()),b.data(),b.size(),hash,&len)||len!=TAG)fail("HMAC generation failed");
 b.insert(b.end(),hash,hash+TAG);OPENSSL_cleanse(hash,sizeof(hash));return b;
}
bool decode(const Bytes& b,const std::array<Byte,32>& key,Frame&f){
 if(b.size()<HLEN+TAG||b.size()>HLEN+MAX_PAYLOAD+TAG||
    b[0]!='S'||b[1]!='X'||b[2]!='T'||b[3]!='P'||b[4]!=1||b[6]!=0||b[7]!=0||b[5]<1||b[5]>8)return false;
 auto sz=get32(b.data()+24);if(sz>MAX_PAYLOAD||HLEN+sz+TAG!=b.size())return false;
 if((b[5]==DATA&&sz==0)||((b[5]==READY||b[5]==FIN||b[5]==DENY||b[5]==SEALED)&&sz!=0)||
    ((b[5]==CHALLENGE||b[5]==PROOF)&&sz!=32))return false;
 Byte hash[EVP_MAX_MD_SIZE]{};unsigned len=0;
 if(!HMAC(EVP_sha256(),key.data(),int(key.size()),b.data(),HLEN+sz,hash,&len)||len!=TAG)return false;
 bool ok=CRYPTO_memcmp(hash,b.data()+HLEN+sz,TAG)==0;OPENSSL_cleanse(hash,sizeof(hash));if(!ok)return false;
 f.type=Type(b[5]);f.sid=get64(b.data()+8);f.seq=get64(b.data()+16);f.payload.assign(b.begin()+HLEN,b.begin()+HLEN+sz);return true;
}
uint64_t rand64(){Byte b[8];if(RAND_bytes(b,sizeof(b))!=1)fail("secure RNG failure");return get64(b);}
uint32_t rand_key(){Byte b[4];if(RAND_bytes(b,sizeof(b))!=1)fail("secure RNG failure");return get32(b)&0x7fffffffu;}
Bytes rand_nonce(){Bytes b(32);if(RAND_bytes(b.data(),int(b.size()))!=1)fail("secure RNG failure");return b;}
Mode mode_file(const std::string&file,bool allow_user_policy){
 int fd=::open(file.c_str(),O_RDONLY|O_CLOEXEC|O_NOFOLLOW);if(fd<0)return Mode::Sealed;
 struct stat st{};if(fstat(fd,&st)||!S_ISREG(st.st_mode)||st.st_size>32||st.st_size<5||
    (st.st_mode&0022)!=0||(st.st_uid!=0&&!(allow_user_policy&&st.st_uid==geteuid()))){::close(fd);return Mode::Sealed;}
 char b[33]{};ssize_t n=::read(fd,b,32);::close(fd);if(n<=0)return Mode::Sealed;
 std::string v(b,size_t(n));if(v=="OPEN\n"||v=="OPEN")return Mode::Open;
 if(v=="LOCKED\n"||v=="LOCKED")return Mode::Locked;
 return Mode::Sealed;
}
void write_all(int fd,const Byte*p,size_t n){while(n){ssize_t rc=::write(fd,p,n);if(rc<0&&errno==EINTR)continue;if(rc<=0)fail(syserr("write to local SSH stream"));p+=rc;n-=size_t(rc);}}
int connect_local(const std::string&host,unsigned port){
 if(host!="127.0.0.1")fail("only localhost sshd is supported");
 int s=::socket(AF_INET,SOCK_STREAM|SOCK_CLOEXEC,0);if(s<0)fail(syserr("TCP socket"));
 sockaddr_in a{};a.sin_family=AF_INET;a.sin_port=htons(uint16_t(port));inet_pton(AF_INET,"127.0.0.1",&a.sin_addr);
 if(::connect(s,(sockaddr*)&a,sizeof(a))<0){int e=errno;::close(s);errno=e;fail(syserr("local sshd connect"));}return s;
}
struct Options {
 bool server=false;std::string receive,send,key,policy,client_id="node-client";
 std::string service="ssh.management",service_registry,operational_registry,operating_state="normal";
 unsigned ssh_port=22,idle_s=1200;bool allow_user_policy=false,allow_user_registry=false;
};
struct RegisteredService {
 std::string name,op_class,logical_peer,access_point;
};
// Read a snapshot of the existing ooRexx Service Descriptor TSV contract. This
// adapter does NOT create or mutate a competing service registry.
std::string secure_registry_data(const std::string& path,bool allow_user){
 int fd=::open(path.c_str(),O_RDONLY|O_CLOEXEC|O_NOFOLLOW);
 if(fd<0)fail(syserr("service/policy registry open"));
 struct stat st{};
 if(fstat(fd,&st)||!S_ISREG(st.st_mode)||st.st_size<1||st.st_size>1024*1024||
    (st.st_mode&0022)||(st.st_uid!=0&&!(allow_user&&st.st_uid==geteuid()))){::close(fd);fail("registry must be root-owned, regular, bounded and not group/other-writable");}
 std::string data;char buf[4096];ssize_t n;
 while((n=::read(fd,buf,sizeof(buf)))>0){data.append(buf,size_t(n));if(data.size()>1024*1024){::close(fd);fail("oversized registry");}}
 int saved=errno;::close(fd);if(n<0){errno=saved;fail(syserr("registry read"));}
 return data;
}
std::vector<std::string> split_tabs(const std::string& text){
 std::vector<std::string> f;size_t at=0;
 for(;;){auto end=text.find('\t',at);if(end==std::string::npos){f.push_back(text.substr(at));break;}f.push_back(text.substr(at,end-at));at=end+1;}
 return f;
}
RegisteredService resolve_registered(const Options& o){
 const auto service_data=secure_registry_data(o.service_registry,o.allow_user_registry);
 const auto op_data=secure_registry_data(o.operational_registry,o.allow_user_registry);
 RegisteredService found;unsigned matches=0;
 std::istringstream lines(service_data);std::string line;
 while(std::getline(lines,line)){
   if(line.empty()||line[0]=='#')continue;
   auto f=split_tabs(line);
   if(f.size()<5||f.size()>6)fail("invalid Service Descriptor TSV row");
   if(f[0]!=o.service)continue;
   ++matches;
   if(f[4]!="1")fail("service is disabled");
   found={f[0],f[1],f[2],f[3].empty()?f[0]:f[3]};
 }
 if(matches!=1||found.op_class.empty()||found.logical_peer!=o.receive||
    !xtp::valid_service_name(found.name)||!xtp::valid_service_name(found.access_point))
   fail("service missing, duplicated or not registered for this XTP logical peer");
 // The Operational Planner is the single class policy authority. Avoid feeding
 // untrusted caller-supplied classes into the decision path.
 std::istringstream policies(op_data);operational::Registry registry;unsigned matching_classes=0;
 while(std::getline(policies,line)){
   if(line.empty()||line[0]=='#')continue;
   auto f=split_tabs(line);
   if(f.size()<5||f.size()>7)fail("invalid Operational Planner TSV row");
   if(f[0]!=found.op_class)continue;
   ++matching_classes;
   operational::OperationalClass c;c.name=f[0];
   for(size_t i=0;i<4;i++)c.states[i]=operational::parse_state_policy(f[i+1]);
   registry.register_class(c);
 }
 if(matching_classes!=1)fail("operational class missing or duplicated");
 operational::Planner planner(registry);
 auto decision=planner.decide(found.op_class,operational::parse_state(o.operating_state));
 // THROTTLE / protected-path enforcement is not wired into this single-session
 // bridge; refusing the context is safer than silently ignoring those controls.
 if(decision.policy.disposition!=operational::Disposition::Allow||
    decision.policy.fallback!=operational::FallbackPolicy::Allow||
    decision.policy.protected_path_only||
    decision.policy.rate_percent!=100||
    decision.policy.per_context_cap_percent!=100||
    decision.policy.max_parallel_contexts!=1||
    decision.policy.aggregate_cap_percent!=100||
    decision.transport_sort.has_value()||
    decision.transport_deadline_us.has_value())
   fail("service refused by operational degradation policy or requires unsupported enforcement");
 return found;
}
Options args(int argc,char**argv){
 Options a; if(argc<2)fail("usage: ssh-xtp client|gateway --rx-peer PEER --tx-peer PEER --key-file PATH [gateway: --policy-file PATH --ssh-port N --client-id ID]");
 std::string role=argv[1];if(role!="client"&&role!="gateway")fail("first argument must be client or gateway");a.server=role=="gateway";
 std::map<std::string,std::string>opts;for(int i=2;i<argc;++i){std::string key=argv[i];if(key.rfind("--",0)!=0||i+1>=argc)fail("invalid option "+key);if(opts.count(key))fail("duplicate option "+key);opts[key]=argv[++i];}
 for(auto&[k,v]:opts)if(k!="--rx-peer"&&k!="--tx-peer"&&k!="--key-file"&&k!="--policy-file"&&k!="--client-id"&&k!="--ssh-port"&&k!="--idle-seconds"&&k!="--allow-user-owned-policy-for-test"&&k!="--service"&&k!="--service-registry"&&k!="--operational-registry"&&k!="--operating-state"&&k!="--allow-user-owned-registry-for-test")fail("unsupported option "+k);
 a.receive=opts["--rx-peer"];a.send=opts["--tx-peer"];a.key=opts["--key-file"];
 if(opts.count("--service"))a.service=opts.at("--service");
 if(opts.count("--service-registry"))a.service_registry=opts.at("--service-registry");
 if(opts.count("--operational-registry"))a.operational_registry=opts.at("--operational-registry");
 if(opts.count("--operating-state"))a.operating_state=opts.at("--operating-state");
 if(opts.count("--allow-user-owned-registry-for-test")){
   if(opts.at("--allow-user-owned-registry-for-test")!="yes")fail("registry test override must be yes");
   a.allow_user_registry=true;
 }a.policy=opts.count("--policy-file")?opts.at("--policy-file"):"";
 if(opts.count("--client-id"))a.client_id=opts["--client-id"];
 if(opts.count("--allow-user-owned-policy-for-test")){if(opts["--allow-user-owned-policy-for-test"]!="yes")fail("test-only policy override requires explicit yes");a.allow_user_policy=true;}
 if(opts.count("--ssh-port")) {auto v=std::stoul(opts["--ssh-port"]);if(v==0||v>65535)fail("invalid SSH port");a.ssh_port=unsigned(v);}
 if(opts.count("--idle-seconds")){auto v=std::stoul(opts["--idle-seconds"]);if(v<5||v>86400)fail("invalid idle timeout");a.idle_s=unsigned(v);}
 if(a.receive.empty()||a.send.empty()||a.key.empty()||(a.server&&a.policy.empty())||
    (a.server&&(a.service_registry.empty()||a.operational_registry.empty()))||
    !xtp::valid_service_name(a.service)||a.client_id.empty()||a.client_id.size()>100)fail("missing/invalid required parameters");
 if(!a.server&&(opts.count("--policy-file")||opts.count("--ssh-port")||opts.count("--allow-user-owned-policy-for-test")||opts.count("--service-registry")||opts.count("--operational-registry")||opts.count("--operating-state")||opts.count("--allow-user-owned-registry-for-test")))fail("gateway-only option given to client");
 return a;
}
struct Bridge {
 Options o;std::array<Byte,32>key;xtp::SocketProvider provider;std::unique_ptr<xtp::Listener> listener;
 std::atomic<bool>stop{false},local_fin{false},remote_fin{false},active{false};
 std::mutex tx_lock;std::atomic<uint64_t>next_tx{0};uint32_t next_xtp=0;
 uint64_t sid=0;int local_fd=-1;std::thread sender;
 std::atomic<int64_t> last_activity_ms{0};
 static int64_t now_ms(){return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();}
 void tick(){last_activity_ms=now_ms();}
 explicit Bridge(Options a):o(std::move(a)),key(key_from_file(o.key)),next_xtp(rand_key()){
    xtp::ListenOptions lo;lo.timeout_ms=200;lo.max_logical_bytes=4096;
    if(o.server){const auto d=resolve_registered(o);o.service=d.access_point;}
    lo.allowed_services={o.service}; // Never permit native XTP's empty accept-any compatibility mode.
    listener=provider.listen(o.receive,lo);tick();
 }
 ~Bridge(){stop=true;if(sender.joinable())sender.join();if(local_fd>=0)::close(local_fd);OPENSSL_cleanse(key.data(),key.size());}
 void send(Type kind,const Bytes&payload={}){
   std::lock_guard<std::mutex> g(tx_lock);
   Frame f{kind,sid,next_tx++,payload};auto wire=encode(f,key);
   xtp::SendOptions so;so.key=(++next_xtp)&0x7fffffffu;so.timeout_ms=200;so.retries=10;so.service_name=o.service;
   provider.send(o.send,wire,so);tick();
 }
 bool recv(Frame&f){
   xtp::ReceiveResult r;
   try{r=listener->receive();}catch(const std::exception&e){if(std::string(e.what())=="XTP listener timeout")return false;throw;}
   if(r.replay)return false;
   if(r.service_name!=o.service){std::cerr<<"ssh-xtp: mismatched native XTP service\n";return false;}
   if(!decode(r.logical,key,f)){std::cerr<<"ssh-xtp: rejected invalid frame\n";return false;}
   tick();return true;
 }
 void start_sender(){sender=std::thread([this]{
    int fd=o.server?local_fd:STDIN_FILENO;
    try{
      while(!stop&&!shutting){pollfd p{fd,POLLIN|POLLHUP,0};int n=::poll(&p,1,150);
        if(n<0){if(errno==EINTR)continue;fail(syserr("poll stream"));}
        if(!n)continue;
        if(p.revents&(POLLERR|POLLNVAL))fail("local stream poll error");
        if(p.revents&(POLLIN|POLLHUP)){
          Byte buffer[MAX_PAYLOAD];ssize_t m=::read(fd,buffer,sizeof(buffer));
          if(m<0){if(errno==EINTR)continue;fail(syserr("local SSH stream read"));}
          if(!m){local_fin=true;send(FIN);break;}
          send(DATA,Bytes(buffer,buffer+m));
        }
      }
    }catch(const std::exception&e){std::cerr<<"ssh-xtp: sender: "<<e.what()<<"\n";stop=true;}
 });}
 void check_timeout(){if(now_ms()-last_activity_ms.load()>int64_t(o.idle_s)*1000){std::cerr<<"ssh-xtp: idle timeout\n";stop=true;}}
 void handle_data(const Frame&f,uint64_t &rx_next){
   if(!active||f.sid!=sid)return;
   // Messages are delivered in-order. Replays are not written twice.
   if(f.seq<rx_next)return;
   if(f.seq!=rx_next){std::cerr<<"ssh-xtp: application sequence gap\n";stop=true;return;}
   rx_next++;
   if(f.type==DATA&&!remote_fin){write_all(o.server?local_fd:STDOUT_FILENO,f.payload.data(),f.payload.size());}
   else if(f.type==FIN){remote_fin=true;if(o.server)::shutdown(local_fd,SHUT_WR);}
   else if(f.type==SEALED){std::cerr<<"ssh-xtp: access sealed\n";stop=true;}
   else {std::cerr<<"ssh-xtp: unexpected active frame\n";stop=true;}
 }
 int client(){
    sid=rand64();next_tx=0;send(OPEN,Bytes(o.client_id.begin(),o.client_id.end()));
    auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(10);
    bool proof=false;Bytes nonce;
    while(!stop&&!shutting&&std::chrono::steady_clock::now()<deadline){
       Frame f;if(!recv(f))continue;if(f.sid!=sid)continue;
       if(f.type==DENY||f.type==SEALED)fail("gateway denied SSH admission");
       if(!proof&&f.type==CHALLENGE&&f.seq==0&&f.payload.size()==32){
          nonce=f.payload;send(PROOF,nonce);proof=true;
       }else if(proof&&f.type==READY&&f.seq==1&&f.payload.empty()){
          active=true;break;
       }
    }
    if(!active)fail("SSH-XTP authenticated handshake timed out");
    std::cerr<<"ssh-xtp: gateway authenticated; SSH handshake remains end-to-end\n";
    start_sender();uint64_t rx=2;
    while(!stop&&!shutting){Frame f;if(recv(f))handle_data(f,rx);if(local_fin&&remote_fin)break;check_timeout();}
    stop=true;return remote_fin?0:4;
 }
 int gateway(){
    std::cerr<<"ssh-xtp: service="<<o.service<<"; gateway ready; local sshd 127.0.0.1:"<<o.ssh_port<<"; initial policy "<<(mode_file(o.policy,o.allow_user_policy)==Mode::Open?"OPEN":"NOT_OPEN")<<"\n";
    bool challenged=false;Bytes nonce;uint64_t rx=0;
    auto challenge_started=std::chrono::steady_clock::now();
    while(!stop&&!shutting){
      Mode policy=mode_file(o.policy,o.allow_user_policy);
      if(active&&policy==Mode::Sealed){
        std::cerr<<"ssh-xtp: SEALED; terminating active session\n";
        stop=true;
        try{send(SEALED);}catch(const std::exception&e){std::cerr<<"ssh-xtp: seal notification failed: "<<e.what()<<"\n";}
        break;
      }
      if(challenged&&!active&&std::chrono::steady_clock::now()-challenge_started>std::chrono::seconds(10)){
        challenged=false;sid=0;nonce.clear();
      }
      Frame f;bool present=recv(f);if(!present){check_timeout();continue;}
      if(active){handle_data(f,rx);if(local_fin&&remote_fin)break;continue;}
      if(challenged&&policy!=Mode::Open){
        try{send(DENY);}catch(const std::exception&e){std::cerr<<"ssh-xtp: deny notification failed: "<<e.what()<<"\n";}
        challenged=false;sid=0;continue;
      }
      if(!challenged){
        if(f.type!=OPEN||f.sid==0||f.seq!=0||f.payload!=Bytes(o.client_id.begin(),o.client_id.end()))continue;
        if(policy!=Mode::Open){sid=f.sid;next_tx=0;send(DENY);sid=0;continue;}
        sid=f.sid;next_tx=0;nonce=rand_nonce();send(CHALLENGE,nonce);challenged=true;challenge_started=std::chrono::steady_clock::now();
        continue;
      }
      if(f.sid!=sid||f.type!=PROOF||f.seq!=1||f.payload!=nonce)continue;
      if(policy!=Mode::Open){send(DENY);challenged=false;sid=0;continue;}
      // No network listener is opened: only loopback sshd after authentication.
      try {local_fd=connect_local("127.0.0.1",o.ssh_port);}
      catch(const std::exception&e){std::cerr<<"ssh-xtp: "<<e.what()<<"\n";send(DENY);challenged=false;sid=0;continue;}
      next_tx=1;send(READY);rx=2;active=true;
      std::cerr<<"ssh-xtp: authorized session accepted for "<<o.client_id<<"\n";
      start_sender();
    }
    stop=true;return active?0:5;
 }
};
} // namespace
int main(int argc,char**argv){
 ::signal(SIGPIPE,SIG_IGN);::signal(SIGTERM,signal_handler);::signal(SIGINT,signal_handler);
 try{auto o=args(argc,argv);Bridge b(o);return o.server?b.gateway():b.client();}
 catch(const std::exception&e){std::cerr<<"ssh-xtp: "<<e.what()<<"\n";return 3;}
}
