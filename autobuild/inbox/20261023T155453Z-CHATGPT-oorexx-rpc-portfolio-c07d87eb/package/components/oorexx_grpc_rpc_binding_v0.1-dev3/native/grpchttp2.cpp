/* ooRexx gRPC unary HTTP/2 outbound native channel.
 * Transport only: libcurl owns TLS, ALPN, h2 stream framing; gRPC binding
 * owns protobuf, gRPC message frames, service dispatch and status projection.
 * No shell, no redirects, no retries, no insecure TLS override.
 */
#include <oorexxapi.h>
#include <curl/curl.h>
#include <string>
#include <vector>
#include <algorithm>
#include <limits>
#include <cctype>
#include <cstdlib>
#include <mutex>

namespace {
struct Response {
 std::string body, contentType, grpcStatus, grpcMessage;
 bool headEnded=false, hasStatus=false, statusDuplicate=false, statusInHeaders=false, overflow=false;
 size_t maxResponse=4194309; // 4MiB gRPC payload + 5 frame bytes
};
std::string trim(std::string s) {
 const auto a=s.find_first_not_of(" \t\r\n");
 if(a==std::string::npos)return "";
 const auto b=s.find_last_not_of(" \t\r\n");
 return s.substr(a,b-a+1);
}
std::string lower(std::string s) {
 for(auto &c:s)c=char(std::tolower((unsigned char)c));
 return s;
}
size_t receive(char *data,size_t size,size_t nmemb,void *user) {
 auto &r=*static_cast<Response*>(user);
 if(size && nmemb > std::numeric_limits<size_t>::max()/size) return 0;
 const size_t n=size*nmemb;
 if(n>r.maxResponse || r.body.size()>r.maxResponse-n){r.overflow=true;return 0;}
 r.body.append(data,n);
 return n;
}
size_t header(char *data,size_t size,size_t nmemb,void *user) {
 auto &r=*static_cast<Response*>(user);
 if(size && nmemb > std::numeric_limits<size_t>::max()/size) return 0;
 const size_t n=size*nmemb;
 if(n>16384) return 0;
 const std::string line(data,n);
 if(line.rfind("HTTP/",0)==0){
   r.contentType.clear();r.grpcStatus.clear();r.grpcMessage.clear();
   r.headEnded=false;r.hasStatus=false;r.statusDuplicate=false;r.statusInHeaders=false;
   return n;
 }
 if(line=="\r\n" || line=="\n"){r.headEnded=true;return n;}
 const auto sep=line.find(':'); if(sep==std::string::npos)return n;
 const auto key=lower(trim(line.substr(0,sep))),value=trim(line.substr(sep+1));
 if(key=="content-type")r.contentType=value;
 if(key=="grpc-status"){
   if(r.hasStatus)r.statusDuplicate=true;
   if(!r.headEnded)r.statusInHeaders=true;
   r.hasStatus=true;r.grpcStatus=value;
 }
 if(key=="grpc-message")r.grpcMessage=value;
 return n;
}
void put(RexxCallContext *c,RexxDirectoryObject d,const char *key,RexxObjectPtr v){c->DirectoryPut(d,v,key);}
RexxObjectPtr str(RexxCallContext *c,const std::string &s){return c->String(s.data(),s.size());}
RexxDirectoryObject outcome(RexxCallContext *c,bool ok,const char *code,const std::string &message,
                             const Response &r,long httpStatus,long httpVersion){
 auto d=c->NewDirectory();
 put(c,d,"ok",ok?c->True():c->False());
 put(c,d,"code",c->String(code));
 put(c,d,"message",str(c,message));
 put(c,d,"body",str(c,r.body));
 put(c,d,"httpStatus",c->WholeNumber(httpStatus));
 put(c,d,"httpVersion",c->WholeNumber(httpVersion));
 put(c,d,"grpcStatus",str(c,r.grpcStatus));
 put(c,d,"grpcMessage",str(c,r.grpcMessage));
 return d;
}
bool validPath(const std::string &s){
 if(s.size()<4||s.size()>500||s[0]!='/')return false;
 const auto split=s.rfind('/'); if(split==0||split==s.size()-1)return false;
 for(size_t i=1;i<s.size();++i){
   const char c=s[i];
   if(!((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='.'||c=='_'||c=='/'))return false;
 }
 if(s.find("..")!=std::string::npos || s.find("//")!=std::string::npos ||
    s.find('/',1)!=split) return false;
 return true;
}
bool validBase(const std::string &s,bool &secure){
 secure=s.rfind("https://",0)==0;
 if(!secure && s.rfind("http://",0)!=0)return false;
 if(s.size()>1024 || s.find_first_of("?#@\r\n\t")!=std::string::npos)return false;
 const auto authority=s.substr(secure?8:7);
 if(authority.empty()||authority.back()=='/'||authority.find('/')!=std::string::npos)return false;
 if(secure)return true;
 // Cleartext HTTP/2 prior knowledge is restricted to the local loopback.
 return authority=="localhost"||authority.rfind("localhost:",0)==0||
        authority=="127.0.0.1"||authority.rfind("127.0.0.1:",0)==0||
        authority=="[::1]"||authority.rfind("[::1]:",0)==0;
}
bool metaName(const std::string &s){
 if(s.empty()||s.size()>128||s[0]==':'||s.rfind("grpc-",0)==0||(s.size()>=4&&s.substr(s.size()-4)=="-bin"))return false;
 for(const char *blocked:{"content-type","content-length","te","host","connection",
      "upgrade","transfer-encoding","accept-encoding","user-agent","http2-settings",
      "proxy-connection","keep-alive"})if(s==blocked)return false;
 for(char c:s)if(!((c>='a'&&c<='z')||(c>='0'&&c<='9')||c=='-'||c=='_'||c=='.'))return false;
 return true;
}
bool metaValue(const std::string &s){
 if(s.size()>4096)return false;
 for(char c:s)if(c<' '||c>'~')return false;
 return true;
}
}
RexxRoutine6(RexxObjectPtr,GrpcNativeHttp2Post,RexxStringObject,baseArg,RexxStringObject,pathArg,
             RexxStringObject,frameArg,CSTRING,timeoutArg,RexxObjectPtr,metadataObj,CSTRING,caFileArg){
 Response r;long httpStatus=0,httpVersion=0;
 const std::string base(context->StringData(baseArg),context->StringLength(baseArg));
 const std::string path(context->StringData(pathArg),context->StringLength(pathArg));
 bool secure=false;
 if(!validBase(base,secure)||!validPath(path))return outcome(context,false,"3","Invalid gRPC endpoint/path",r,0,0);
 const std::string caFile(caFileArg);
 if(!caFile.empty() && (!secure || caFile.size()>4096 || caFile[0]!='/' ||
     caFile.find_first_of("\r\n\t")!=std::string::npos))
   return outcome(context,false,"3","Invalid trusted CA configuration",r,0,0);
 char *end=nullptr;unsigned long millis=strtoul(timeoutArg,&end,10);
 if(end==timeoutArg||*end!='\0'||millis<1||millis>600000)return outcome(context,false,"3","Invalid gRPC timeout",r,0,0);
 if(context->StringLength(frameArg)>4194309)return outcome(context,false,"8","gRPC request too large",r,0,0);
 const char *framed=context->StringData(frameArg);
 const auto framedSize=context->StringLength(frameArg);
 // Only one length-delimited *uncompressed* gRPC request on unary channel.
 if(framedSize<5||(unsigned char)framed[0]!=0)return outcome(context,false,"3","Invalid unary gRPC frame",r,0,0);
 size_t expected=0;
 for(int i=1;i<5;++i)expected=expected*256+(unsigned char)framed[i];
 if(expected!=framedSize-5)return outcome(context,false,"3","Invalid unary gRPC length",r,0,0);
 // Initialise libcurl once before any activity makes a request.
 static std::once_flag globalInit;
 static CURLcode initCode=CURLE_OK;
 std::call_once(globalInit,[]{initCode=curl_global_init(CURL_GLOBAL_DEFAULT);});
 if(initCode!=CURLE_OK)return outcome(context,false,"14","HTTP/2 transport unavailable",r,0,0);
 CURL *curl=curl_easy_init();
 if(!curl)return outcome(context,false,"14","HTTP/2 transport unavailable",r,0,0);
 curl_slist *headers=nullptr;
 headers=curl_slist_append(headers,"content-type: application/grpc+proto");
 headers=curl_slist_append(headers,"te: trailers");
 headers=curl_slist_append(headers,"grpc-accept-encoding: identity");
 // Client-side deadline also enforced by curl timeout, even when server ignores grpc-timeout.
 const std::string grpcTimeout="grpc-timeout: "+std::to_string(millis)+"m";
 headers=curl_slist_append(headers,grpcTimeout.c_str());
 bool metaOk=true;
 if(!context->IsDirectory(metadataObj)){curl_slist_free_all(headers);curl_easy_cleanup(curl);return outcome(context,false,"3","Invalid gRPC metadata type",r,0,0);}
 auto metadata=(RexxDirectoryObject)metadataObj;
 auto indexes=context->SendMessage0(metadata,"ALLINDEXES");
 if(!context->IsArray(indexes))metaOk=false;
 else if(context->ArrayItems((RexxArrayObject)indexes)>32)metaOk=false;
 else for(size_t i=1;i<=context->ArrayItems((RexxArrayObject)indexes);++i){
   auto keyObj=context->ArrayAt((RexxArrayObject)indexes,i);
   auto keyString=context->ObjectToString(keyObj);
   const std::string key=lower(std::string(context->StringData(keyString),context->StringLength(keyString)));
   auto valObj=context->DirectoryAt(metadata,key.c_str());
   if(!context->IsString(valObj)){metaOk=false;break;}
   auto valString=context->ObjectToString(valObj);
   const std::string val(context->StringData(valString),context->StringLength(valString));
   if(!metaName(key)||!metaValue(val)){metaOk=false;break;}
   const std::string entry=key+": "+val;
   headers=curl_slist_append(headers,entry.c_str());
 }
 if(!metaOk){curl_slist_free_all(headers);curl_easy_cleanup(curl);return outcome(context,false,"3","Invalid gRPC metadata",r,0,0);}
 const std::string url=base+path;
 curl_easy_setopt(curl,CURLOPT_URL,url.c_str());
 curl_easy_setopt(curl,CURLOPT_POST,1L);
 curl_easy_setopt(curl,CURLOPT_POSTFIELDS,framed);
 curl_easy_setopt(curl,CURLOPT_POSTFIELDSIZE_LARGE,(curl_off_t)framedSize);
 curl_easy_setopt(curl,CURLOPT_HTTPHEADER,headers);
 curl_easy_setopt(curl,CURLOPT_HTTP_VERSION,secure?CURL_HTTP_VERSION_2TLS:CURL_HTTP_VERSION_2_PRIOR_KNOWLEDGE);
 curl_easy_setopt(curl,CURLOPT_TIMEOUT_MS,(long)millis);
 curl_easy_setopt(curl,CURLOPT_CONNECTTIMEOUT_MS,(long)std::min<unsigned long>(millis,5000));
 curl_easy_setopt(curl,CURLOPT_FOLLOWLOCATION,0L);
 curl_easy_setopt(curl,CURLOPT_SSL_VERIFYPEER,1L);
 curl_easy_setopt(curl,CURLOPT_SSL_VERIFYHOST,2L);
 if(!caFile.empty())curl_easy_setopt(curl,CURLOPT_CAINFO,caFile.c_str());
 curl_easy_setopt(curl,CURLOPT_WRITEFUNCTION,receive);
 curl_easy_setopt(curl,CURLOPT_WRITEDATA,&r);
 curl_easy_setopt(curl,CURLOPT_HEADERFUNCTION,header);
 curl_easy_setopt(curl,CURLOPT_HEADERDATA,&r);
 curl_easy_setopt(curl,CURLOPT_NOSIGNAL,1L);
 curl_easy_setopt(curl,CURLOPT_PROXY,""); // Explicit endpoint, no environment-driven proxy routing.
 const CURLcode rc=curl_easy_perform(curl);
 curl_easy_getinfo(curl,CURLINFO_RESPONSE_CODE,&httpStatus);
 curl_easy_getinfo(curl,CURLINFO_HTTP_VERSION,&httpVersion);
 curl_slist_free_all(headers);
 curl_easy_cleanup(curl);
 if(r.overflow)return outcome(context,false,"8","gRPC response too large",r,httpStatus,httpVersion);
 if(rc==CURLE_OPERATION_TIMEDOUT)return outcome(context,false,"4","gRPC deadline exceeded",r,httpStatus,httpVersion);
 if(rc!=CURLE_OK)return outcome(context,false,"14","HTTP/2 transport failure",r,httpStatus,httpVersion);
 if(httpVersion!=CURL_HTTP_VERSION_2_0)return outcome(context,false,"14","HTTP/2 was not negotiated",r,httpStatus,httpVersion);
 if(httpStatus!=200)return outcome(context,false,"14","HTTP/2 gRPC response not successful",r,httpStatus,httpVersion);
 const std::string content=lower(trim(r.contentType));
 const std::string baseContent=trim(content.substr(0,content.find(';')));
 if(baseContent!="application/grpc" && baseContent!="application/grpc+proto")
   return outcome(context,false,"13","Invalid gRPC content type",r,httpStatus,httpVersion);
 // Accept trailers-only for an error, or trailers after DATA for a normal reply.
 // A grpc-status in initial headers is only valid as trailers-only (no DATA).
 if(r.statusDuplicate || !r.hasStatus || (r.statusInHeaders && !r.body.empty()))
   return outcome(context,false,"13","Missing/duplicate/early gRPC status",r,httpStatus,httpVersion);
 bool digits=!r.grpcStatus.empty() && r.grpcStatus.size()<=2;
 for(char c:r.grpcStatus) if(c<'0'||c>'9')digits=false;
 if(!digits)return outcome(context,false,"13","Invalid gRPC status",r,httpStatus,httpVersion);
 const unsigned long status=std::strtoul(r.grpcStatus.c_str(),nullptr,10);
 if(status>16)return outcome(context,false,"13","Invalid gRPC status",r,httpStatus,httpVersion);
 return outcome(context,true,"0","",r,httpStatus,httpVersion);
}
RexxRoutineEntry routines[]={REXX_TYPED_ROUTINE(GrpcNativeHttp2Post,GrpcNativeHttp2Post),REXX_LAST_ROUTINE()};
RexxPackageEntry GrpcHttp2_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,"GrpcHttp2","0.1.0",NULL,NULL,routines,NULL};
OOREXX_GET_PACKAGE(GrpcHttp2);
