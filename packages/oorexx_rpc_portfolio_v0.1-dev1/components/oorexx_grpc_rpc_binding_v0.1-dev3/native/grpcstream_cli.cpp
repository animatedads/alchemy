/* Test-only driver: exercises the exact transport engine used by ooRexx. */
#include "grpcstream_core.hpp"
#include <iostream>
#include <iomanip>
#include <string>
#include <chrono>
#include <cstdlib>
int main(int argc,char**argv){
 if(argc<4){std::cerr<<"usage: stream_cli base path deadline_ms [cancel_after_messages] [ca_file]\n";return 2;}
 grpcstream::Options o;o.base=argv[1];o.path=argv[2];o.timeoutMs=std::strtol(argv[3],nullptr,10);
 if(argc>5)o.caFile=argv[5];
 o.request=std::string("\0\0\0\0\2\10\1",7);
 const int cancelAfter=argc>4?std::atoi(argv[4]):-1;
 auto validation=grpcstream::validate(o);
 if(validation.kind=="END"){std::cout<<"END "<<validation.code<<" "<<validation.message<<"\n";return validation.code?1:0;}
 auto s=std::make_shared<grpcstream::Session>(o);s->start();
 std::string pending;int count=0;bool completed=false;
 while(!completed){
     auto e=s->poll(100);
     if(e.kind=="IDLE")continue;
     if(e.kind=="DATA"){
         pending+=e.chunk;
         while(pending.size()>=5){
             unsigned char flag=pending[0];
             std::size_t n=0;for(int i=1;i<5;++i)n=n*256+(unsigned char)pending[i];
             if(flag!=0||n>4194304){std::cerr<<"BAD FRAME\n";s->cancel();s->close();return 10;}
             if(pending.size()<n+5)break;
             std::string value=pending.substr(5,n);
             pending.erase(0,n+5);
             std::cout<<"DATA "<<value.size()<<" ";
             for(unsigned char c:value)std::cout<<std::hex<<std::setw(2)<<std::setfill('0')<<(int)c;
             std::cout<<std::dec<<"\n"<<std::flush;
             ++count;
             if(cancelAfter>=0&&count>=cancelAfter){s->cancel();break;}
         }
         continue;
     }
     if(e.kind=="END"){
         std::cout<<"END "<<e.code<<" "<<e.message<<"\n";
         if(!pending.empty()){
             std::cerr<<"INCOMPLETE FRAME\n";s->close();return 11;
         }
         s->close();return e.code==0||e.code==1?0:1;
     }
     std::cerr<<"UNKNOWN EVENT\n";return 12;
 }
 return 0;
}
