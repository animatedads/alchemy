#include "grpcstream_core.hpp"
#include <curl/curl.h>
#include <algorithm>
#include <chrono>
#include <cctype>
#include <cstdlib>
#include <limits>
#include <mutex>

namespace grpcstream {
namespace {
constexpr std::size_t MAX_BUFFERED=512*1024, MAX_TRANSFER=64*1024*1024;
std::once_flag initFlag;
CURLcode initCode=CURLE_FAILED_INIT;
std::string trim(const std::string &s) {
    auto begin=s.find_first_not_of(" \t\r\n");
    if(begin==std::string::npos)return {};
    auto end=s.find_last_not_of(" \t\r\n");
    return s.substr(begin,end-begin+1);
}
std::string lower(std::string s){
    for(auto &c:s)c=static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return s;
}
bool validPath(const std::string &s){
    if(s.size()<4 || s.size()>500 || s[0]!='/')return false;
    const auto split=s.rfind('/');
    if(split<=1 || split==s.size()-1 || s.find('/',1)!=split)return false;
    if(s.find("..")!=std::string::npos || s.find("//")!=std::string::npos)return false;
    for(std::size_t i=1;i<s.size();++i){
        auto c=s[i];
        if(!((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='_'||c=='.'||c=='/'))return false;
    }
    return true;
}
bool validBase(const std::string &s,bool &secure){
    secure=s.rfind("https://",0)==0;
    if(!secure && s.rfind("http://",0)!=0)return false;
    if(s.size()>1024 || s.find_first_of("?#@\r\n\t")!=std::string::npos)return false;
    const std::string authority=s.substr(secure?8:7);
    if(authority.empty() || authority.back()=='/' || authority.find('/')!=std::string::npos)return false;
    if(secure)return true;
    return authority=="localhost" || authority.rfind("localhost:",0)==0 || authority=="127.0.0.1" ||
           authority.rfind("127.0.0.1:",0)==0 || authority=="[::1]" || authority.rfind("[::1]:",0)==0;
}
bool validMetaName(const std::string &s){
    if(s.empty()||s.size()>128||s[0]==':'||s.rfind("grpc-",0)==0 ||
       (s.size()>=4 && s.substr(s.size()-4)=="-bin"))return false;
    for(const char *blocked: {"content-type","content-length","te","host","connection","upgrade",
        "transfer-encoding","accept-encoding","user-agent","http2-settings","proxy-connection","keep-alive"})
        if(s==blocked)return false;
    for(auto c:s)if(!((c>='a'&&c<='z')||(c>='0'&&c<='9')||c=='-'||c=='_'||c=='.'))return false;
    return true;
}
bool validMetaValue(const std::string &s){
    if(s.size()>4096)return false;
    for(unsigned char c:s)if(c<' '||c>'~')return false;
    return true;
}
Event fail(int code,const std::string &message){Event e;e.kind="END";e.code=code;e.message=message;return e;}
}
Event validate(const Options &o){
    bool secure=false;
    if(!validBase(o.base,secure)||!validPath(o.path))return fail(3,"Invalid gRPC endpoint/path");
    if(!o.caFile.empty() && (!secure || o.caFile[0]!='/' || o.caFile.size()>4096 ||
       o.caFile.find_first_of("\r\n\t")!=std::string::npos))return fail(3,"Invalid CA configuration");
    if(o.timeoutMs<1 || o.timeoutMs>600000)return fail(3,"Invalid deadline");
    if(o.request.size()<5||o.request.size()>4194309||o.request[0]!=0)return fail(3,"Invalid request frame");
    std::size_t length=0;
    for(int i=1;i<5;++i)length=length*256+static_cast<unsigned char>(o.request[i]);
    if(length!=o.request.size()-5)return fail(3,"Invalid request frame length");
    if(o.metadata.size()>32)return fail(3,"Excessive metadata");
    for(const auto &m:o.metadata){
        if(!validMetaName(m.first)||!validMetaValue(m.second))return fail(3,"Invalid metadata");
    }
    return Event{};
}
Session::Session(Options o):options_(std::move(o)){}
Session::~Session(){close();}
void Session::start(){
    std::lock_guard<std::mutex> guard(mutex_);
    if(worker_.joinable()||ended_)return;
    worker_=std::thread([this]{run();});
}
void Session::cancel(){cancelled_.store(true);cv_.notify_all();}
void Session::close(){
    cancel();
    if(worker_.joinable())worker_.join();
}
Event Session::poll(int waitMs){
    Event ev;
    if(waitMs<0 || waitMs>1000)return fail(3,"Invalid poll interval");
    std::unique_lock<std::mutex> lock(mutex_);
    cv_.wait_for(lock,std::chrono::milliseconds(waitMs),[this]{return !chunks_.empty()||ended_;});
    if(!chunks_.empty()){
        ev.kind="DATA";
        ev.chunk=std::move(chunks_.front());chunks_.pop_front();
        buffered_-=ev.chunk.size();
        lock.unlock();cv_.notify_all();return ev;
    }
    if(ended_)return final_;
    return ev;
}
std::size_t Session::receive(char *data,std::size_t size,std::size_t count,void *ptr){
    auto &s=*static_cast<Session*>(ptr);
    if(size && count>std::numeric_limits<std::size_t>::max()/size)return 0;
    std::size_t n=size*count;
    if(s.cancelled_.load())return 0;
    std::unique_lock<std::mutex> lock(s.mutex_);
    if(n>MAX_BUFFERED||s.total_>MAX_TRANSFER-n){s.overflow_=true;return 0;}
    s.cv_.wait(lock,[&]{return s.cancelled_.load()||s.buffered_+n<=MAX_BUFFERED;});
    if(s.cancelled_.load())return 0;
    s.chunks_.emplace_back(data,n);
    s.buffered_+=n;s.total_+=n;
    lock.unlock();s.cv_.notify_all();
    return n;
}
std::size_t Session::header(char *data,std::size_t size,std::size_t count,void *ptr){
    auto &s=*static_cast<Session*>(ptr);
    if(size && count>std::numeric_limits<std::size_t>::max()/size)return 0;
    std::size_t n=size*count;
    if(n>16384 || s.cancelled_.load())return 0;
    std::string line(data,n);
    auto &h=s.headers_;
    if(line.rfind("HTTP/",0)==0){h=ResponseHeaders{};return n;}
    if(line=="\r\n"||line=="\n"){h.headEnded=true;return n;}
    auto sep=line.find(':');
    if(sep==std::string::npos)return n;
    auto key=lower(trim(line.substr(0,sep)));
    auto val=trim(line.substr(sep+1));
    if(key=="content-type")h.type=val;
    if(key=="grpc-status"){
        if(h.sawStatus)h.duplicate=true;
        h.sawStatus=true;h.status=val;
        if(!h.headEnded)h.statusInHeaders=true;
    }
    if(key=="grpc-message")h.message=val;
    return n;
}
int Session::progress(void *ptr,long long,long long,long long,long long){
    return static_cast<Session*>(ptr)->cancelled_.load()?1:0;
}
void Session::finish(Event result){
    std::lock_guard<std::mutex> guard(mutex_);
    final_=std::move(result);ended_=true;cv_.notify_all();
}
void Session::run(){
    auto validation=validate(options_);
    if(validation.kind=="END"){finish(validation);return;}
    std::call_once(initFlag,[]{initCode=curl_global_init(CURL_GLOBAL_DEFAULT);});
    if(initCode!=CURLE_OK){finish(fail(14,"HTTP/2 transport unavailable"));return;}
    CURL *curl=curl_easy_init();
    if(!curl){finish(fail(14,"HTTP/2 transport unavailable"));return;}
    bool secure=false;validBase(options_.base,secure);
    curl_slist *hdr=nullptr;
    hdr=curl_slist_append(hdr,"content-type: application/grpc+proto");
    hdr=curl_slist_append(hdr,"te: trailers");
    hdr=curl_slist_append(hdr,"grpc-accept-encoding: identity");
    const std::string deadline="grpc-timeout: "+std::to_string(options_.timeoutMs)+"m";
    hdr=curl_slist_append(hdr,deadline.c_str());
    for(const auto &m:options_.metadata){
        const std::string item=m.first+": "+m.second;
        hdr=curl_slist_append(hdr,item.c_str());
    }
    const std::string url=options_.base+options_.path;
    curl_easy_setopt(curl,CURLOPT_URL,url.c_str());
    curl_easy_setopt(curl,CURLOPT_POST,1L);
    curl_easy_setopt(curl,CURLOPT_POSTFIELDS,options_.request.data());
    curl_easy_setopt(curl,CURLOPT_POSTFIELDSIZE_LARGE,static_cast<curl_off_t>(options_.request.size()));
    curl_easy_setopt(curl,CURLOPT_HTTPHEADER,hdr);
    curl_easy_setopt(curl,CURLOPT_HTTP_VERSION,secure?CURL_HTTP_VERSION_2TLS:CURL_HTTP_VERSION_2_PRIOR_KNOWLEDGE);
    curl_easy_setopt(curl,CURLOPT_TIMEOUT_MS,options_.timeoutMs);
    curl_easy_setopt(curl,CURLOPT_CONNECTTIMEOUT_MS,std::min<long>(options_.timeoutMs,5000));
    curl_easy_setopt(curl,CURLOPT_FOLLOWLOCATION,0L);
    curl_easy_setopt(curl,CURLOPT_SSL_VERIFYPEER,1L);
    curl_easy_setopt(curl,CURLOPT_SSL_VERIFYHOST,2L);
    if(!options_.caFile.empty())curl_easy_setopt(curl,CURLOPT_CAINFO,options_.caFile.c_str());
    curl_easy_setopt(curl,CURLOPT_WRITEFUNCTION,Session::receive);
    curl_easy_setopt(curl,CURLOPT_WRITEDATA,this);
    curl_easy_setopt(curl,CURLOPT_HEADERFUNCTION,Session::header);
    curl_easy_setopt(curl,CURLOPT_HEADERDATA,this);
    curl_easy_setopt(curl,CURLOPT_XFERINFOFUNCTION,+[](void *p,curl_off_t,curl_off_t,curl_off_t,curl_off_t)->int{
        return static_cast<Session*>(p)->cancelled_.load()?1:0;
    });
    curl_easy_setopt(curl,CURLOPT_XFERINFODATA,this);
    curl_easy_setopt(curl,CURLOPT_NOPROGRESS,0L);
    curl_easy_setopt(curl,CURLOPT_NOSIGNAL,1L);
    curl_easy_setopt(curl,CURLOPT_PROXY,"");
    CURLcode rc=curl_easy_perform(curl);
    long status=0,version=0;
    curl_easy_getinfo(curl,CURLINFO_RESPONSE_CODE,&status);
    curl_easy_getinfo(curl,CURLINFO_HTTP_VERSION,&version);
    curl_slist_free_all(hdr);curl_easy_cleanup(curl);
    Event ev;ev.kind="END";ev.httpStatus=status;ev.httpVersion=version;
    ev.grpcStatus=headers_.status;ev.grpcMessage=headers_.message;
    if(cancelled_.load())ev=fail(1,"RPC cancelled");
    else if(overflow_)ev=fail(8,"Stream size limit exceeded");
    else if(rc==CURLE_OPERATION_TIMEDOUT)ev=fail(4,"RPC deadline exceeded");
    else if(rc!=CURLE_OK)ev=fail(14,"HTTP/2 transport failure");
    else if(version!=CURL_HTTP_VERSION_2_0)ev=fail(14,"HTTP/2 not negotiated");
    else if(status!=200)ev=fail(14,"HTTP/2 RPC failed");
    else {
        auto ct=lower(trim(headers_.type));ct=trim(ct.substr(0,ct.find(';')));
        if(ct!="application/grpc"&&ct!="application/grpc+proto")ev=fail(13,"Invalid gRPC content type");
        else if(!headers_.sawStatus||headers_.duplicate||(headers_.statusInHeaders&&total_>0))ev=fail(13,"Missing/duplicate/early grpc-status");
        else {
            bool digits=!headers_.status.empty()&&headers_.status.size()<=2;
            for(char c:headers_.status)if(c<'0'||c>'9')digits=false;
            if(!digits)ev=fail(13,"Invalid grpc-status");
            else {
                long v=std::strtol(headers_.status.c_str(),nullptr,10);
                if(v>16)ev=fail(13,"Invalid grpc-status");
                else if(v!=0)ev=fail(static_cast<int>(v),"Remote gRPC method failed");
                else ev.code=0;
            }
        }
    }
    ev.httpStatus=status;ev.httpVersion=version;
    ev.grpcStatus=headers_.status;ev.grpcMessage=headers_.message;
    finish(ev);
}
} // namespace grpcstream
