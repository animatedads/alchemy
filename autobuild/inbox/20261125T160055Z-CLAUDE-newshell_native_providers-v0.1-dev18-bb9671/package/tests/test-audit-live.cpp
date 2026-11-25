// Architecture: Tom Dyer. Coding: ChatGPT. EXPLICIT opt-in on an approved
// isolated MU. This is test-only; it sends a harmless unique AUDIT_USER.
#include "../native/audit_netlink.h"
#include <iostream>
#include <signal.h>
using namespace auditwire;
static volatile sig_atomic_t interrupted=0;
static void stop(int){interrupted=1;}
struct Restore {
    unsigned initial;bool required,done;
    bool run(){if(!required){done=true;return true;}audit_status s={};int e=setEnabled(initial,s);done=!e&&s.enabled==initial;if(!done)std::cerr<<"FAIL AUDIT RESTORATION errno="<<e<<" original="<<initial<<'\n';return done;}
    ~Restore(){if(required&&!done)run();}
};
int main(){
    signal(SIGINT,stop);signal(SIGTERM,stop);signal(SIGHUP,stop);
    audit_status before={};int e=exchange(false,0,before);if(e||before.enabled==2){std::cerr<<"FAIL audit live initial status errno="<<e<<" enabled="<<before.enabled<<'\n';return 1;}
    std::cout<<"PASS audit live original status read\n";
    Restore restore{before.enabled,false,false}; // C++11 aggregate fix below if needed
    int fd=openSocket(true);if(fd<0){std::cerr<<"FAIL audit live readlog join errno="<<errno<<'\n';return 1;}
    struct Close{int f;~Close(){close(f);}} reader{fd};
    std::cout<<"PASS audit live readlog membership\n";
    restore.required=true;audit_status enabled={};e=setEnabled(1,enabled);
    bool ok=!e&&enabled.enabled==1;if(ok)std::cout<<"PASS audit live enabled readback\n";else std::cerr<<"FAIL audit live enable errno="<<e<<'\n';
    bool matched=false;
    if(ok&&!interrupted){unsigned port=0;int sendfd=openSocket(false,&port);if(sendfd>=0){Close sender{sendfd};std::string marker="alchemy_dev18_test="+std::to_string(getpid())+"_"+std::to_string(std::chrono::steady_clock::now().time_since_epoch().count());
        std::vector<char> bytes(NLMSG_SPACE(marker.size()+1),0);nlmsghdr h={};h.nlmsg_len=NLMSG_LENGTH(marker.size()+1);h.nlmsg_type=AUDIT_USER;h.nlmsg_flags=NLM_F_REQUEST;h.nlmsg_seq=1;h.nlmsg_pid=port;memcpy(bytes.data(),&h,sizeof(h));memcpy(bytes.data()+NLMSG_HDRLEN,marker.c_str(),marker.size()+1);
        e=sendKernel(sendfd,bytes.data(),h.nlmsg_len);if(!e){std::cout<<"PASS audit live test message sent\n";auto until=std::chrono::steady_clock::now()+std::chrono::seconds(5);while(!matched&&!interrupted&&std::chrono::steady_clock::now()<until){pollfd p={fd,POLLIN,0};int k=poll(&p,1,100);if(k<0&&errno==EINTR)continue;if(k<0)break;if(!k)continue;char buf[65536];size_t n=0;std::vector<Record> records;int z=receive(fd,buf,sizeof(buf),n);if(z==EAGAIN)continue;if(z||parseRecords(buf,n,records))break;for(auto& r:records)if(r.type==AUDIT_USER&&r.text.find(marker)!=std::string::npos)matched=true;}}}}
    if(matched)std::cout<<"PASS audit live generated message received through READLOG\n";else std::cerr<<"FAIL audit live generated message not observed\n";
    bool restored=restore.run();if(restored)std::cout<<"PASS audit live original enabled state restored\n";
    return ok&&matched&&restored&&!interrupted?0:1;
}
