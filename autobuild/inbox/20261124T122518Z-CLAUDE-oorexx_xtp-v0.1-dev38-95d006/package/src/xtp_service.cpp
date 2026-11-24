#include "xtp/xtp_service.hpp"
#include <algorithm>
#include <cctype>
#include <stdexcept>

namespace xtp {
namespace {
void put16(std::vector<uint8_t>& b,size_t o,uint16_t v,bool l){
    if(l){b[o]=uint8_t(v);b[o+1]=uint8_t(v>>8);}else{b[o]=uint8_t(v>>8);b[o+1]=uint8_t(v);}
}
uint16_t get16(const std::vector<uint8_t>& b,size_t o,bool l){
    if(l)return uint16_t(b[o])|(uint16_t(b[o+1])<<8);
    return (uint16_t(b[o])<<8)|uint16_t(b[o+1]);
}
void put64(std::vector<uint8_t>& b,size_t o,uint64_t v,bool l){
    for(size_t i=0;i<8;i++){size_t s=l?i:(7-i);b[o+i]=uint8_t(v>>(8*s));}
}
uint64_t get64(const std::vector<uint8_t>& b,size_t o,bool l){
    uint64_t v=0;
    if(l){for(int i=7;i>=0;--i)v=(v<<8)|b[o+size_t(i)];}
    else {for(size_t i=0;i<8;i++)v=(v<<8)|b[o+i];}
    return v;
}
bool ipv4_literal(const std::string&s){
    int dots=0,part=-1,digits=0;
    for(size_t i=0;i<=s.size();++i){
        char c=i<s.size()?s[i]:'.';
        if(c=='.'){
            if(digits==0||part<0||part>255)return false;
            dots++;part=-1;digits=0;
            continue;
        }
        if(!std::isdigit(static_cast<unsigned char>(c)))return false;
        if(part<0) part=0;
        part=part*10+(c-'0');
        digits++;
        if(digits>3)return false;
    }
    return dots==4; // synthetic final delimiter included
}
}

bool valid_service_name(const std::string& name){
    if(name.empty()||name.size()>255)return false;
    if(ipv4_literal(name))return false;
    if(name.find('[')!=std::string::npos||name.find(']')!=std::string::npos)return false;
    if(std::count(name.begin(),name.end(),':')>1)return false; // fail closed for IPv6 literals
    for(unsigned char c: name){
        if(c<=0x20||c==0x7f)return false;
    }
    return true;
}

uint64_t service_name_token(const std::string& name){
    uint64_t h=1469598103934665603ull;
    for(unsigned char c:name){h^=c;h*=1099511628211ull;}
    return h;
}

std::vector<uint8_t> encode_named_service(const std::string& name,bool little,uint8_t flags){
    if(!valid_service_name(name))throw std::runtime_error("invalid XTP named service: "+name);
    const size_t logical=16+name.size();
    const size_t padded=(logical+7u)&~size_t(7u);
    if(logical>0xffffu)throw std::runtime_error("XTP named service descriptor too large");
    std::vector<uint8_t>b(padded,0);
    put16(b,0,uint16_t(logical),little);
    put16(b,2,XTP_NAMED_SERVICE_FORMAT,little);
    // byte 4: flags (dev31); bytes 5..7 reserved for this private profile.
    b[4]=flags;
    put64(b,8,service_name_token(name),little);
    std::copy(name.begin(),name.end(),b.begin()+16);
    return b;
}

bool decode_named_service(std::vector<uint8_t>& data,bool little,NamedServiceDescriptor&out){
    if(data.size()<16)return false;
    const uint16_t logical=get16(data,0,little);
    const uint16_t format=get16(data,2,little);
    if(format!=XTP_NAMED_SERVICE_FORMAT)return false;
    if(logical<17||logical>data.size())throw std::runtime_error("malformed XTP named-service address segment");
    const size_t padded=(size_t(logical)+7u)&~size_t(7u);
    if(padded>data.size())throw std::runtime_error("truncated XTP named-service address segment");
    std::string name(data.begin()+16,data.begin()+logical);
    if(!valid_service_name(name))throw std::runtime_error("invalid XTP named-service name on wire");
    const uint64_t token=get64(data,8,little);
    if(token!=service_name_token(name))throw std::runtime_error("XTP named-service token mismatch");
    out.name=name;out.token=token;out.flags=data[4];
    data.erase(data.begin(),data.begin()+padded);
    return true;
}

} // namespace xtp
