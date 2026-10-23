/* ooRexx native adapter for the shared streaming engine.
 * Network I/O runs on a worker; caller polls from its own ooRexx activity.
 * No foreign thread ever calls into an ooRexx object.
 */
#include <oorexxapi.h>
#include "grpcstream_core.hpp"
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <cstdlib>
#include <climits>
#include <limits>
#include <algorithm>
#include <cctype>

namespace {
std::mutex sessionsMutex;
std::map<std::string,std::shared_ptr<grpcstream::Session>> sessions;
unsigned long long nextId=1;
void put(RexxCallContext *context,RexxDirectoryObject d,const char*key,RexxObjectPtr value){
    context->DirectoryPut(d,value,key);
}
RexxDirectoryObject result(RexxCallContext*context,bool ok,const std::string &handle,
                            const grpcstream::Event &event){
    auto d=context->NewDirectory();
    put(context,d,"ok",ok?context->True():context->False());
    put(context,d,"handle",context->String(handle.c_str()));
    put(context,d,"kind",context->String(event.kind.c_str()));
    put(context,d,"chunk",context->String(event.chunk.data(),event.chunk.size()));
    put(context,d,"code",context->WholeNumber(event.code));
    put(context,d,"message",context->String(event.message.c_str()));
    put(context,d,"grpcStatus",context->String(event.grpcStatus.c_str()));
    put(context,d,"grpcMessage",context->String(event.grpcMessage.c_str()));
    put(context,d,"httpStatus",context->WholeNumber(event.httpStatus));
    put(context,d,"httpVersion",context->WholeNumber(event.httpVersion));
    return d;
}
std::shared_ptr<grpcstream::Session> lookup(const std::string &handle){
    std::lock_guard<std::mutex> lock(sessionsMutex);
    auto i=sessions.find(handle);
    return i==sessions.end()?nullptr:i->second;
}
}
RexxRoutine6(RexxObjectPtr,GrpcNativeStreamOpen,RexxStringObject,baseArg,RexxStringObject,pathArg,
             RexxStringObject,requestArg,CSTRING,timeoutArg,RexxObjectPtr,metadataObj,CSTRING,caFileArg){
    grpcstream::Options o;
    o.base=std::string(context->StringData(baseArg),context->StringLength(baseArg));
    o.path=std::string(context->StringData(pathArg),context->StringLength(pathArg));
    o.request=std::string(context->StringData(requestArg),context->StringLength(requestArg));
    o.caFile=caFileArg;
    char *last=nullptr;
    long deadline=std::strtol(timeoutArg,&last,10);
    if(last==timeoutArg||*last!='\0')return result(context,false,"",grpcstream::Event{"END","","Invalid deadline","","",3});
    o.timeoutMs=deadline;
    if(!context->IsDirectory(metadataObj))
        return result(context,false,"",grpcstream::Event{"END","","Invalid metadata","","",3});
    auto indexes=context->SendMessage0(metadataObj,"ALLINDEXES");
    if(!context->IsArray(indexes))
        return result(context,false,"",grpcstream::Event{"END","","Invalid metadata","","",3});
    auto idx=(RexxArrayObject)indexes;
    if(context->ArrayItems(idx)>32)
        return result(context,false,"",grpcstream::Event{"END","","Excessive metadata","","",3});
    for(std::size_t i=1;i<=context->ArrayItems(idx);++i){
        auto keyObject=context->ArrayAt(idx,i);
        auto keyString=context->ObjectToString(keyObject);
        auto name=std::string(context->StringData(keyString),context->StringLength(keyString));
        auto value=context->DirectoryAt((RexxDirectoryObject)metadataObj,name.c_str());
        if(!context->IsString(value))
            return result(context,false,"",grpcstream::Event{"END","","Invalid metadata value","","",3});
        auto valString=context->ObjectToString(value);
        auto val=std::string(context->StringData(valString),context->StringLength(valString));
        std::string lowered=name;
        std::transform(lowered.begin(),lowered.end(),lowered.begin(),[](unsigned char c){return static_cast<char>(std::tolower(c));});
        if(o.metadata.find(lowered)!=o.metadata.end())
            return result(context,false,"",grpcstream::Event{"END","","Duplicate metadata","","",3});
        o.metadata[lowered]=val;
    }
    auto validation=grpcstream::validate(o);
    if(validation.kind=="END")return result(context,false,"",validation);
    auto session=std::make_shared<grpcstream::Session>(std::move(o));
    std::string id;
    {
        std::lock_guard<std::mutex> lock(sessionsMutex);
        // Bounded active connection count; handles never reused in-process.
        if(sessions.size()>=128 || nextId==ULLONG_MAX)
            return result(context,false,"",grpcstream::Event{"END","","Stream session resource limit","","",8});
        id=std::to_string(nextId++);
        sessions.emplace(id,session);
    }
    session->start();
    return result(context,true,id,grpcstream::Event{});
}
RexxRoutine2(RexxObjectPtr,GrpcNativeStreamPoll,CSTRING,handle,CSTRING,interval){
    auto s=lookup(handle);
    if(!s)return result(context,false,"",grpcstream::Event{"END","","Unknown stream handle","","",3});
    char *end=nullptr;
    long wait=std::strtol(interval,&end,10);
    if(end==interval||*end!='\0'||wait<0||wait>1000)
        return result(context,false,"",grpcstream::Event{"END","","Invalid poll interval","","",3});
    return result(context,true,handle,s->poll((int)wait));
}
RexxRoutine1(RexxObjectPtr,GrpcNativeStreamCancel,CSTRING,handle){
    auto s=lookup(handle);
    if(!s)return context->False();
    s->cancel();return context->True();
}
RexxRoutine1(RexxObjectPtr,GrpcNativeStreamClose,CSTRING,handle){
    std::shared_ptr<grpcstream::Session> s;
    {
        std::lock_guard<std::mutex> lock(sessionsMutex);
        auto i=sessions.find(handle);
        if(i==sessions.end())return context->False();
        s=i->second;
        sessions.erase(i);
    }
    s->close();return context->True();
}
RexxRoutineEntry routines[]={
 REXX_TYPED_ROUTINE(GrpcNativeStreamOpen,GrpcNativeStreamOpen),
 REXX_TYPED_ROUTINE(GrpcNativeStreamPoll,GrpcNativeStreamPoll),
 REXX_TYPED_ROUTINE(GrpcNativeStreamCancel,GrpcNativeStreamCancel),
 REXX_TYPED_ROUTINE(GrpcNativeStreamClose,GrpcNativeStreamClose),
 REXX_LAST_ROUTINE()
};
RexxPackageEntry GrpcHttp2Stream_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,
 "GrpcHttp2Stream","0.1.0",NULL,NULL,routines,NULL};
OOREXX_GET_PACKAGE(GrpcHttp2Stream);
