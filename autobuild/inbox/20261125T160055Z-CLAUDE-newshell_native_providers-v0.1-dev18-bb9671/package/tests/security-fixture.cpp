// Architecture: Tom Dyer. Coding: ChatGPT. Disposable local observation fixture.
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <fstream>
#include <vector>
#include <string>
#include <chrono>
#include <thread>
static bool exists(const std::string& p){return access(p.c_str(),F_OK)==0;}
int main(int argc,char** argv){if(argc!=2)return 1;std::string root=argv[1];int s=socket(AF_INET,SOCK_STREAM|SOCK_CLOEXEC,0);if(s<0)return 2;sockaddr_in a{};a.sin_family=AF_INET;a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);if(bind(s,(sockaddr*)&a,sizeof(a)))return 3;socklen_t len=sizeof(a);if(getsockname(s,(sockaddr*)&a,&len))return 4;{std::ofstream f(root+"/port");f<<ntohs(a.sin_port)<<'\n';}for(int i=0;i<400&&!exists(root+"/go");++i)std::this_thread::sleep_for(std::chrono::milliseconds(25));if(!exists(root+"/go"))return 5;std::vector<unsigned char> mem(32*1024*1024,42);volatile unsigned char* p=mem.data();for(size_t i=0;i<mem.size();i+=4096)p[i]=static_cast<unsigned char>(i);if(listen(s,8))return 6;int c=socket(AF_INET,SOCK_STREAM|SOCK_CLOEXEC,0);if(c<0||connect(c,(sockaddr*)&a,sizeof(a)))return 7;int peer=accept(s,nullptr,nullptr);if(peer<0)return 8;char bytes[4096]{};if(send(c,bytes,sizeof(bytes),0)!=sizeof(bytes))return 9;{std::ofstream f(root+"/ready");f<<"ready\n";}bool burst=false;for(int i=0;i<600&&!exists(root+"/stop");++i){if(!burst&&exists(root+"/burst")){for(int j=0;j<2;++j){if(send(c,bytes,sizeof(bytes),0)!=sizeof(bytes)||send(peer,bytes,sizeof(bytes),0)!=sizeof(bytes))return 10;}burst=true;std::ofstream f(root+"/burst.done");f<<"done\n";}std::this_thread::sleep_for(std::chrono::milliseconds(25));}close(peer);close(c);close(s);return p[0];}
