/* Architecture: Tom Dyer. Coding: ChatGPT. Exercise same private table reader,
   no production proc path override. Fixture is not an IPv4-only running kernel. */
#include "../native/posix.cpp"
#include <fstream>
#include <iostream>
int main(int argc,char**argv){
    if(argc!=2)return 1;
    Fd base(open(argv[1],O_PATH|O_DIRECTORY|O_CLOEXEC));if(base.n<0)return 1;
    auto check=[](bool ok,const char* label){std::cout<<(ok?"PASS ":"FAIL ")<<label<<std::endl;if(!ok)std::exit(1);};
    std::string data;
    for(auto proto:{"tcp","udp"}){
        data.clear();check(readPortTable(base.n,proto,false,data)==1&&!data.empty(),"IPv4 fixture mandatory table read");
        data.clear();check(readPortTable(base.n,proto,true,data)==0,"IPv4 fixture optional IPv6 table absent");
        std::string p=std::string(argv[1])+"/net/"+proto+"6";
        if(mkdir(p.c_str(),0700))return 1;
        data.clear();check(readPortTable(base.n,proto,true,data)==-1,"IPv4 fixture existing unreadable table fails closed");
        if(rmdir(p.c_str()))return 1;
        std::ofstream(p)<<"local_address\n";
        data.clear();check(readPortTable(base.n,proto,true,data)==1,"IPv4 fixture present IPv6 table read");
    }
    return 0;
}
