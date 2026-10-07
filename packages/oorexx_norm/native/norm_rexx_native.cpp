#include <oorexxapi.h>
#include <normApi.h>
#include <atomic>
#include <cstdint>
#include <memory>
#include <cstdio>
#include <mutex>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>

namespace {
struct Sender {
  NormInstanceHandle instance{NORM_INSTANCE_INVALID};
  NormSessionHandle session{NORM_SESSION_INVALID};
  std::mutex lock;
  std::unordered_map<const void*, std::shared_ptr<std::vector<char>>> retained;
  ~Sender() {
    if (session != NORM_SESSION_INVALID) { NormStopSender(session); NormDestroySession(session); }
    if (instance != NORM_INSTANCE_INVALID) NormDestroyInstance(instance);
  }
};
struct Listener {
  NormInstanceHandle instance{NORM_INSTANCE_INVALID};
  NormSessionHandle session{NORM_SESSION_INVALID};
  std::mutex lock;
  ~Listener() {
    if (session != NORM_SESSION_INVALID) { NormStopReceiver(session); NormDestroySession(session); }
    if (instance != NORM_INSTANCE_INVALID) NormDestroyInstance(instance);
  }
};
std::atomic<uint64_t> nextHandle{1};
std::mutex tableLock;
std::unordered_map<uint64_t,std::unique_ptr<Sender>> senders;
std::unordered_map<uint64_t,std::unique_ptr<Listener>> listeners;
void fail(RexxCallContext *c, const std::string &m) { c->RaiseException1(Rexx_Error_Incorrect_call_user_defined,c->NewStringFromAsciiz(m.c_str())); }
Sender *sender(uint64_t h){ auto i=senders.find(h); return i==senders.end()?nullptr:i->second.get(); }
Listener *listener(uint64_t h){ auto i=listeners.find(h); return i==listeners.end()?nullptr:i->second.get(); }
NormNodeId nodeId(uint32_t n){ return n==0 ? NORM_NODE_ANY : static_cast<NormNodeId>(n); }
bool configureCommon(NormSessionHandle s,const char *iface,const char *source,bool loopback) {
  if (iface && *iface && !NormSetMulticastInterface(s,iface)) return false;
  if (source && *source && !NormSetSSM(s,source)) return false;
  if (!NormSetMulticastLoopback(s,loopback)) return false;
  return true;
}
}

RexxRoutine0(RexxStringObject,normNativeVersion) {
  int a=0,b=0,c=0; NormGetVersion(&a,&b,&c);
  std::string v=std::to_string(a)+"."+std::to_string(b)+"."+std::to_string(c);
  return context->NewStringFromAsciiz(v.c_str());
}

RexxRoutine10(uint64_t,normNativeSenderOpen,
 CSTRING,group,uint16_t,port,uint32_t,localNode,CSTRING,iface,CSTRING,source,
 int,ttl,int,loopback,double,txRate,uint32_t,bufferBytes,CSTRING,fecSpec) {
  unsigned int segmentValue=0,dataValue=0,parityValue=0;
  if(!fecSpec || 3!=sscanf(fecSpec,"%u:%u:%u",&segmentValue,&dataValue,&parityValue)) {
    fail(context,"NORM sender open: invalid FEC specification"); return 0;
  }
  if(segmentValue>65535u || dataValue>65535u || parityValue>65535u) {
    fail(context,"NORM sender open: FEC values out of range"); return 0;
  }
  const uint16_t segmentSize=(uint16_t)segmentValue;
  const uint16_t dataSymbols=(uint16_t)dataValue;
  const uint16_t paritySymbols=(uint16_t)parityValue;
  try {
    auto s=std::make_unique<Sender>();
    s->instance=NormCreateInstance(); if(s->instance==NORM_INSTANCE_INVALID) throw std::runtime_error("NormCreateInstance failed");
    s->session=NormCreateSession(s->instance,group,port,nodeId(localNode)); if(s->session==NORM_SESSION_INVALID) throw std::runtime_error("NormCreateSession failed");
    if(!configureCommon(s->session,iface,source,loopback!=0)) throw std::runtime_error("NORM multicast configuration failed");
    if(ttl<0||ttl>255||!NormSetTTL(s->session,(unsigned char)ttl)) throw std::runtime_error("NORM TTL configuration failed");
    NormSetTxRate(s->session,txRate);
    if(!NormStartSender(s->session,NormGetRandomSessionId(),bufferBytes,segmentSize,dataSymbols,paritySymbols)) throw std::runtime_error("NormStartSender failed");
    uint64_t h=nextHandle.fetch_add(1); std::lock_guard<std::mutex> g(tableLock); senders.emplace(h,std::move(s)); return h;
  } catch(const std::exception &e){ fail(context,std::string("NORM sender open: ")+e.what()); return 0; }
}

RexxRoutine2(int,normNativeSenderSend,uint64_t,handle,RexxStringObject,bytes) {
  try {
    Sender *s; { std::lock_guard<std::mutex> g(tableLock); s=sender(handle); }
    if(!s) throw std::runtime_error("unknown sender handle");
    const size_t n=context->StringLength(bytes); if(n>UINT32_MAX) throw std::runtime_error("payload exceeds NORM data object size");
    auto storage=std::make_shared<std::vector<char>>(context->StringData(bytes),context->StringData(bytes)+n);
    std::lock_guard<std::mutex> g(s->lock);
    NormObjectHandle o=NormDataEnqueue(s->session,storage->data(),(UINT32)n,nullptr,0);
    if(o==NORM_OBJECT_INVALID) return -1;
    s->retained[(const void*)o]=storage;
    NormEvent ev;
    while(NormGetNextEvent(s->instance,&ev,false)) if(ev.type==NORM_TX_OBJECT_PURGED) s->retained.erase((const void*)ev.object);
    return (int)n;
  } catch(const std::exception &e){ fail(context,std::string("NORM sender send: ")+e.what()); return -1; }
}
RexxRoutine1(int,normNativeSenderDescriptor,uint64_t,handle){ (void)context; std::lock_guard<std::mutex> g(tableLock); auto*s=sender(handle); return s?NormGetDescriptor(s->instance):-1; }
RexxRoutine1(int,normNativeSenderClose,uint64_t,handle){ (void)context; std::unique_ptr<Sender>s; {std::lock_guard<std::mutex>g(tableLock);auto i=senders.find(handle);if(i==senders.end())return 0;s=std::move(i->second);senders.erase(i);} return 0; }

RexxRoutine7(uint64_t,normNativeListenerOpen,CSTRING,group,uint16_t,port,uint32_t,localNode,CSTRING,iface,CSTRING,source,int,loopback,uint32_t,rxBuffer) {
  try {
    auto r=std::make_unique<Listener>();
    r->instance=NormCreateInstance(); if(r->instance==NORM_INSTANCE_INVALID) throw std::runtime_error("NormCreateInstance failed");
    r->session=NormCreateSession(r->instance,group,port,nodeId(localNode)); if(r->session==NORM_SESSION_INVALID) throw std::runtime_error("NormCreateSession failed");
    if(!configureCommon(r->session,iface,source,loopback!=0)) throw std::runtime_error("NORM multicast configuration failed");
    NormSetRxPortReuse(r->session,true,nullptr,nullptr,0);
    if(!NormStartReceiver(r->session,rxBuffer)) throw std::runtime_error("NormStartReceiver failed");
    uint64_t h=nextHandle.fetch_add(1); std::lock_guard<std::mutex>g(tableLock); listeners.emplace(h,std::move(r)); return h;
  } catch(const std::exception&e){ fail(context,std::string("NORM listener open: ")+e.what()); return 0; }
}
RexxRoutine1(RexxObjectPtr,normNativeListenerReceive,uint64_t,handle) {
  try {
    Listener*r; {std::lock_guard<std::mutex>g(tableLock);r=listener(handle);} if(!r) throw std::runtime_error("unknown listener handle");
    std::lock_guard<std::mutex> g(r->lock); NormEvent ev;
    while(NormGetNextEvent(r->instance,&ev,true)) {
      if(ev.type==NORM_RX_OBJECT_COMPLETED && NormObjectGetType(ev.object)==NORM_OBJECT_DATA) {
        NormSize size=NormObjectGetSize(ev.object); if(size<0 || (uint64_t)size>SIZE_MAX) throw std::runtime_error("invalid received object size");
        const char*p=NormDataAccessData(ev.object); if(!p && size) throw std::runtime_error("received data unavailable");
        return context->NewString(p,(size_t)size);
      }
      if(ev.type==NORM_RX_OBJECT_ABORTED) throw std::runtime_error("received object aborted");
    }
    return NULLOBJECT;
  } catch(const std::exception&e){ fail(context,std::string("NORM listener receive: ")+e.what()); return NULLOBJECT; }
}
RexxRoutine1(int,normNativeListenerDescriptor,uint64_t,handle){ (void)context; std::lock_guard<std::mutex>g(tableLock);auto*r=listener(handle);return r?NormGetDescriptor(r->instance):-1; }
RexxRoutine1(int,normNativeListenerClose,uint64_t,handle){ (void)context; std::unique_ptr<Listener>r; {std::lock_guard<std::mutex>g(tableLock);auto i=listeners.find(handle);if(i==listeners.end())return 0;r=std::move(i->second);listeners.erase(i);} return 0; }

RexxRoutineEntry routines[]={
 REXX_TYPED_ROUTINE(normNativeVersion,normNativeVersion),
 REXX_TYPED_ROUTINE(normNativeSenderOpen,normNativeSenderOpen),REXX_TYPED_ROUTINE(normNativeSenderSend,normNativeSenderSend),REXX_TYPED_ROUTINE(normNativeSenderDescriptor,normNativeSenderDescriptor),REXX_TYPED_ROUTINE(normNativeSenderClose,normNativeSenderClose),
 REXX_TYPED_ROUTINE(normNativeListenerOpen,normNativeListenerOpen),REXX_TYPED_ROUTINE(normNativeListenerReceive,normNativeListenerReceive),REXX_TYPED_ROUTINE(normNativeListenerDescriptor,normNativeListenerDescriptor),REXX_TYPED_ROUTINE(normNativeListenerClose,normNativeListenerClose),REXX_LAST_ROUTINE()};
RexxPackageEntry oorexx_norm_native_package_entry={STANDARD_PACKAGE_HEADER REXX_INTERPRETER_5_0_0,"oorexx_norm_native","0.1-dev1",nullptr,nullptr,routines,nullptr};
OOREXX_GET_PACKAGE(oorexx_norm_native);
