// UDP relay that drops every Nth packet forward and every Mth back.
// usage: lossy_relay RELAY_PORT TARGET_PORT DROP_FWD_EVERY DROP_REV_EVERY SECONDS
#include <arpa/inet.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>
#include <array>
#include <chrono>
#include <cstdio>
#include <string>
int main(int argc,char**argv){
  if(argc<6){std::fprintf(stderr,"usage: lossy_relay RELAY_PORT TARGET_PORT DROP_FWD DROP_REV SECONDS\n");return 2;}
  auto addr=[](int port){sockaddr_in a{};a.sin_family=AF_INET;a.sin_port=htons(uint16_t(port));inet_pton(AF_INET,"127.0.0.1",&a.sin_addr);return a;};
  int front=socket(AF_INET,SOCK_DGRAM,0),back=socket(AF_INET,SOCK_DGRAM,0);
  auto fa=addr(std::stoi(argv[1]));if(bind(front,(sockaddr*)&fa,sizeof fa)<0){perror("bind");return 2;}
  auto ba=addr(0);bind(back,(sockaddr*)&ba,sizeof ba);
  auto target=addr(std::stoi(argv[2]));const unsigned df=std::stoul(argv[3]),dr=std::stoul(argv[4]);
  const auto stop=std::chrono::steady_clock::now()+std::chrono::seconds(std::stoi(argv[5]));
  sockaddr_in client{};bool have=false;unsigned long fwd=0,rev=0,fd_=0,rd_=0;std::array<unsigned char,65536> b{};
  while(std::chrono::steady_clock::now()<stop){
    pollfd p[2]={{front,POLLIN,0},{back,POLLIN,0}};if(poll(p,2,50)<=0)continue;
    if(p[0].revents&POLLIN){sockaddr_in f{};socklen_t fl=sizeof f;ssize_t n=recvfrom(front,b.data(),b.size(),0,(sockaddr*)&f,&fl);if(n>0){client=f;have=true;if(++fwd%df==0)fd_++;else sendto(back,b.data(),size_t(n),0,(sockaddr*)&target,sizeof target);}}
    if(p[1].revents&POLLIN){ssize_t n=recv(back,b.data(),b.size(),0);if(n>0&&have){if(++rev%dr==0)rd_++;else sendto(front,b.data(),size_t(n),0,(sockaddr*)&client,sizeof client);}}
  }
  std::printf("RELAY forwarded=%lu dropped_fwd=%lu reverse=%lu dropped_rev=%lu\n",fwd,fd_,rev,rd_);return 0;
}
