#include "xtp/xtp_service.hpp"
#include <cassert>
#include <iostream>
int main(){
    const std::string n="ssh.management";
    assert(xtp::valid_service_name(n));
    assert(!xtp::valid_service_name("192.0.2.10"));
    assert(!xtp::valid_service_name("2001:db8::1"));
    auto b=xtp::encode_named_service(n,true);
    b.push_back('x');b.push_back('y');b.push_back('z');
    xtp::NamedServiceDescriptor d;
    bool ok=xtp::decode_named_service(b,true,d);
    assert(ok);assert(d.name==n);assert(b.size()==3&&b[0]=='x'&&b[2]=='z');
    std::cout<<"PASS XTP named-service address segment and IP rejection\n";
}
