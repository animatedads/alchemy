#include <oorexxapi.h>
#include <normApi.h>
#include <atomic>
#include <chrono>
#include <cerrno>
#include <cstdint>
#include <memory>
#include <cstdio>
#include <mutex>
#include <poll.h>
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

void fail(RexxCallContext *c, const std::string &m) {
  c->RaiseException1(Rexx_Error_Incorrect_call_user_defined,c->NewStringFromAsciiz(m.c_str()));
}
Sender *sender(uint64_t h){ auto i=senders.find(h); return i==senders.end()?nullptr:i->second.get(); }
Listener *listener(uint64_t h){ auto i=listeners.find(h); return i==listeners.end()?nullptr:i->second.get(); }
NormNodeId nodeId(uint32_t n){ return n==0 ? NORM_NODE_ANY : static_cast<NormNodeId>(n); }

bool configureSender(NormSessionHandle s,const char *iface,bool loopback) {
  if (iface && *iface && !NormSetMulticastInterface(s,iface)) return false;
  if (!NormSetMulticastLoopback(s,loopback)) return false;
  return true;
}
bool configureReceiver(NormSessionHandle s,const char *iface,const char *source,bool loopback) {
  if (iface && *iface && !NormSetMulticastInterface(s,iface)) return false;
  if (source && *source && !NormSetSSM(s,source)) return false;
  if (!NormSetMulticastLoopback(s,loopback)) return false;
  return true;
}

int waitDescriptor(NormDescriptor fd, int timeoutMs) {
  if (fd == NORM_DESCRIPTOR_INVALID) return -1;
  if (timeoutMs < -1) timeoutMs = -1;
  pollfd p{};
  p.fd = fd;
  p.events = POLLIN;
  for (;;) {
    int rc = poll(&p,1,timeoutMs);
    if (rc < 0 && errno == EINTR) continue;
    if (rc <= 0) return rc;
    if (p.revents & (POLLERR|POLLHUP|POLLNVAL)) return -1;
    return (p.revents & POLLIN) ? 1 : 0;
  }
}

void drainSenderEvents(Sender *s) {
  NormEvent ev;
  while (NormGetNextEvent(s->instance,&ev,false)) {
    if (ev.type==NORM_TX_OBJECT_PURGED) s->retained.erase((const void*)ev.object);
    if (ev.type==NORM_SEND_ERROR) throw std::runtime_error("NORM send error");
  }
}

RexxObjectPtr listenerReceiveEvent(RexxCallContext *context, Listener *r, bool wait) {
  NormEvent ev;
  for (;;) {
    if (!NormGetNextEvent(r->instance,&ev,wait)) return context->Nil();
    if (ev.type==NORM_RX_OBJECT_COMPLETED && NormObjectGetType(ev.object)==NORM_OBJECT_DATA) {
      NormSize size=NormObjectGetSize(ev.object);
      if(size<0 || (uint64_t)size>SIZE_MAX) throw std::runtime_error("invalid received object size");
      const char*p=NormDataAccessData(ev.object);
      if(!p && size) throw std::runtime_error("received data unavailable");
      return context->NewString(p,(size_t)size);
    }
    if(ev.type==NORM_RX_OBJECT_ABORTED) throw std::runtime_error("received object aborted");
    if(!wait) continue;
  }
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
  (void)source; // source filtering is receiver membership state, not sender state
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
    s->instance=NormCreateInstance(false); if(s->instance==NORM_INSTANCE_INVALID) throw std::runtime_error("NormCreateInstance failed");
    s->session=NormCreateSession(s->instance,group,port,nodeId(localNode)); if(s->session==NORM_SESSION_INVALID) throw std::runtime_error("NormCreateSession failed");
    if(!configureSender(s->session,iface,loopback!=0)) throw std::runtime_error("NORM µÕ±Ñ¥…ÍÐ½¹™¥ÕÉ…Ñ¥½¸™…¥±•ˆ¤ì(€€€¥˜¡ÑÑ°ðÁññÑÑ°øÈÔÕñð…9½ÉµM•ÑQQ0¡Ì´ùÍ•ÍÍ¥½¸°¡Õ¹Í¥¹•¡…È¥ÑÑ°¤¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰9=I4QQ0½¹™¥ÕÉ…Ñ¥½¸™…¥±•ˆ¤ì(€€€9½ÉµM•ÑIáA½ÉÑI•ÕÍ”¡Ì´ùÍ•ÍÍ¥½¸±ÑÉÕ”±¹Õ±±ÁÑÈ±¹Õ±±ÁÑÈ°À¤ì(€€€9½ÉµM•ÑQáI…Ñ”¡Ì´ùÍ•ÍÍ¥½¸±ÑáI…Ñ”¤ì(€€€¥˜ …9½ÉµMÑ…ÉÑM•¹‘•È¡Ì´ùÍ•ÍÍ¥½¸±9½Éµ•ÑI…¹‘½µM•ÍÍ¥½¹% ¤±‰Õ™™•É	åÑ•Ì±Í•µ•¹ÑM¥é”±‘…Ñ…Måµ‰½±Ì±Á…É¥ÑåMåµ‰½±Ì°À¤¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰9½ÉµMÑ…ÉÑM•¹‘•È™…¥±•ˆ¤ì(€€€Õ¥¹ÐØÑ}Ð õ¹•áÑ!…¹‘±”¹™•Ñ¡}…‘ Ä¤ì(€€€ÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡Ñ…‰±•1½¬¤ì(€€€Í•¹‘•ÉÌ¹•µÁ±…”¡ ±ÍÑèéµ½Ù”¡Ì¤¤ì(€€€É•ÑÕÉ¸ ì(€ô…Ñ ¡½¹ÍÐÍÑèé•á•ÁÑ¥½¸€™”¥ì™…¥°¡½¹Ñ•áÐ±ÍÑèéÍÑÉ¥¹œ ‰9=I4Í•¹‘•È½Á•¸è€ˆ¤­”¹Ý¡…Ð ¤¤ìÉ•ÑÕÉ¸€Àìô)ô()I•ááI½ÕÑ¥¹”È¡¥¹Ð±¹½Éµ9…Ñ¥Ù•M•¹‘•ÉM•¹±Õ¥¹ÐØÑ}Ð±¡…¹‘±”±I•ááMÑÉ¥¹=‰©•Ð±‰åÑ•Ì¤ì(€ÑÉäì(€€€M•¹‘•È€©ÌììÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡Ñ…‰±•1½¬¤ìÌõÍ•¹‘•È¡¡…¹‘±”¤ìô(€€€¥˜ …Ì¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰Õ¹­¹½Ý¸Í•¹‘•È¡…¹‘±”ˆ¤ì(€€€½¹ÍÐÍ¥é•}Ð¸õ½¹Ñ•áÐ´ùMÑÉ¥¹1•¹Ñ ¡‰åÑ•Ì¤ì¥˜¡¸ùU%9PÌÉ}5`¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰Á…å±½…•á••‘Ì9=I4‘…Ñ„½‰©•ÐÍ¥é”ˆ¤ì(€€€…ÕÑ¼ÍÑ½É…”õÍÑèéµ…­•}Í¡…É•ñÍÑèéÙ•Ñ½Èñ¡…Èøø¡½¹Ñ•áÐ´ùMÑÉ¥¹…Ñ„¡‰åÑ•Ì¤±½¹Ñ•áÐ´ùMÑÉ¥¹…Ñ„¡‰åÑ•Ì¤­¸¤ì(€€€ÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡Ì´ù±½¬¤ì(€€€‘É…¥¹M•¹‘•ÉÙ•¹ÑÌ¡Ì¤ì(€€€9½Éµ=‰©•Ñ!…¹‘±”¼õ9½Éµ…Ñ…¹ÅÕ•Õ”¡Ì´ùÍ•ÍÍ¥½¸±ÍÑ½É…”´ù‘…Ñ„ ¤°¡U%9PÌÈ¥¸±¹Õ±±ÁÑÈ°À¤ì(€€€¥˜¡¼ôõ9=I5}=	)Q}%9Y1%¤É•ÑÕÉ¸€´Äì(€€€Ì´ùÉ•Ñ…¥¹•‘l¡½¹ÍÐÙ½¥¨¥½tõÍÑ½É…”ì(€€€É•ÑÕÉ¸€¡¥¹Ð¥¸ì(€ô…Ñ ¡½¹ÍÐÍÑèé•á•ÁÑ¥½¸€™”¥ì™…¥°¡½¹Ñ•áÐ±ÍÑèéÍÑÉ¥¹œ ‰9=I4Í•¹‘•ÈÍ•¹è€ˆ¤­”¹Ý¡…Ð ¤¤ìÉ•ÑÕÉ¸€´Äìô)ô)I•ááI½ÕÑ¥¹”È¡¥¹Ð±¹½Éµ9…Ñ¥Ù•M•¹‘•ÉM•Ñ1½ÍÌ±Õ¥¹ÐØÑ}Ð±¡…¹‘±”±‘½Õ‰±”±Á•É•¹Ð¤ì(€ÑÉäì(€€€M•¹‘•È€©ÌììÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡Ñ…‰±•1½¬¤ìÌõÍ•¹‘•È¡¡…¹‘±”¤ìô(€€€¥˜ …Ì¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰Õ¹­¹½Ý¸Í•¹‘•È¡…¹‘±”ˆ¤ì(€€€¥˜¡Á•É•¹ÐðÀ¸ÀñðÁ•É•¹ÐøÄÀÀ¸À¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰±½ÍÌÁ•É•¹Ð½ÕÐ½˜É…¹”ˆ¤ì(€€€ÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡Ì´ù±½¬¤ì(€€€9½ÉµM•ÑQá1½ÍÌ¡Ì´ùÍ•ÍÍ¥½¸±Á•É•¹Ð¤ì(€€€É•ÑÕÉ¸€Àì(€ô…Ñ ¡½¹ÍÐÍÑèé•á•ÁÑ¥½¸€™”¥ì™…¥°¡½¹Ñ•áÐ±ÍÑèéÍÑÉ¥¹œ ‰9=I4Í•¹‘•È±½ÍÌè€ˆ¤­”¹Ý¡…Ð ¤¤ìÉ•ÑÕÉ¸€´Äìô)ô)I•ááI½ÕÑ¥¹”È¡¥¹Ð±¹½Éµ9…Ñ¥Ù•M•¹‘•É]…¥ÑÉ…¥¹•±Õ¥¹ÐØÑ}Ð±¡…¹‘±”±¥¹Ð±Ñ¥µ•½ÕÑ5Ì¤ì(€ÑÉäì(€€€M•¹‘•È€©ÌììÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡Ñ…‰±•1½¬¤ìÌõÍ•¹‘•È¡¡…¹‘±”¤ìô(€€€¥˜ …Ì¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰Õ¹­¹½Ý¸Í•¹‘•È¡…¹‘±”ˆ¤ì(€€€…ÕÑ¼‘•…‘±¥¹”õÍÑèé¡É½¹¼èéÍÑ•…‘å}±½¬èé¹½Ü ¤­ÍÑèé¡É½¹¼èéµ¥±±¥Í•½¹‘Ì¡Ñ¥µ•½ÕÑ5ÌðÀüÀéÑ¥µ•½ÕÑ5Ì¤ì(€€€ÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡Ì´ù±½¬¤ì(€€€™½È€ ìì¤ì(€€€€€‘É…¥¹M•¹‘•ÉÙ•¹ÑÌ¡Ì¤ì(€€€€€¥˜¡Ì´ùÉ•Ñ…¥¹•¹•µÁÑä ¤¤É•ÑÕÉ¸€Äì(€€€€€¥¹ÐÉ•µ…¥¹¥¹œõÑ¥µ•½ÕÑ5Ìì(€€€€€¥˜¡Ñ¥µ•½ÕÑ5ÌøôÀ¤ì(€€€€€€€…ÕÑ¼¹½ÜõÍÑèé¡É½¹¼èéÍÑ•…‘å}±½¬èé¹½Ü ¤ì(€€€€€€€¥˜¡¹½Üøõ‘•…‘±¥¹”¤É•ÑÕÉ¸€Àì(€€€€€€€É•µ…¥¹¥¹œô¡¥¹Ð¥ÍÑèé¡É½¹¼èé‘ÕÉ…Ñ¥½¹}…ÍÐñÍÑèé¡É½¹¼èéµ¥±±¥Í•½¹‘Ìø¡‘•…‘±¥¹”µ¹½Ü¤¹½Õ¹Ð ¤ì(€€€€€€€¥˜¡É•µ…¥¹¥¹œðÄ¤É•µ…¥¹¥¹œôÄì(€€€€€ô(€€€€€¥¹ÐÉ•…‘äõÝ…¥Ñ•ÍÉ¥ÁÑ½È¡9½Éµ•Ñ•ÍÉ¥ÁÑ½È¡Ì´ù¥¹ÍÑ…¹”¤±É•µ…¥¹¥¹œ¤ì(€€€€€¥˜¡É•…‘äðÀ¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰‘•ÍÉ¥ÁÑ½ÈÝ…¥Ð™…¥±•ˆ¤ì(€€€€€¥˜¡É•…‘äôôÀ¤É•ÑÕÉ¸€Àì(€€€ô(€ô…Ñ ¡½¹ÍÐÍÑèé•á•ÁÑ¥½¸€™”¥ì™…¥°¡½¹Ñ•áÐ±ÍÑèéÍÑÉ¥¹œ ‰9=I4Í•¹‘•ÈÝ…¥Ðè€ˆ¤­”¹Ý¡…Ð ¤¤ìÉ•ÑÕÉ¸€´Äìô)ô)I•ááI½ÕÑ¥¹”Ä¡¥¹Ð±¹½Éµ9…Ñ¥Ù•M•¹‘•É•ÍÉ¥ÁÑ½È±Õ¥¹ÐØÑ}Ð±¡…¹‘±”¥ì(€€¡Ù½¥¥½¹Ñ•áÐìÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡Ñ…‰±•1½¬¤ì…ÕÑ¼©ÌõÍ•¹‘•È¡¡…¹‘±”¤ìÉ•ÑÕÉ¸Ìý9½Éµ•Ñ•ÍÉ¥ÁÑ½È¡Ì´ù¥¹ÍÑ…¹”¤è´Äì)ô)I•ááI½ÕÑ¥¹”Ä¡¥¹Ð±¹½Éµ9…Ñ¥Ù•M•¹‘•É±½Í”±Õ¥¹ÐØÑ}Ð±¡…¹‘±”¥ì(€€¡Ù½¥¥½¹Ñ•áÐìÍÑèéÕ¹¥ÅÕ•}ÁÑÈñM•¹‘•ÈùÌìíÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àùœ¡Ñ…‰±•1½¬¤í…ÕÑ¼¤õÍ•¹‘•ÉÌ¹™¥¹¡¡…¹‘±”¤í¥˜¡¤ôõÍ•¹‘•ÉÌ¹•¹ ¤¥É•ÑÕÉ¸€ÀíÌõÍÑèéµ½Ù”¡¤´ùÍ•½¹¤íÍ•¹‘•ÉÌ¹•É…Í”¡¤¤íôÉ•ÑÕÉ¸€Àì)ô()I•ááI½ÕÑ¥¹”Ü¡Õ¥¹ÐØÑ}Ð±¹½Éµ9…Ñ¥Ù•1¥ÍÑ•¹•É=Á•¸±MQI%9±É½ÕÀ±Õ¥¹ÐÄÙ}Ð±Á½ÉÐ±Õ¥¹ÐÌÉ}Ð±±½…±9½‘”±MQI%9±¥™…”±MQI%9±Í½ÕÉ”±¥¹Ð±±½½Á‰…¬±Õ¥¹ÐÌÉ}Ð±Éá	Õ™™•È¤ì(€ÑÉäì(€€€…ÕÑ¼ÈõÍÑèéµ…­•}Õ¹¥ÅÕ”ñ1¥ÍÑ•¹•Èø ¤ì(€€€È´ù¥¹ÍÑ…¹”õ9½ÉµÉ•…Ñ•%¹ÍÑ…¹”¡™…±Í”¤ì¥˜¡È´ù¥¹ÍÑ…¹”ôõ9=I5}%9MQ9}%9Y1%¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰9½ÉµÉ•…Ñ•%¹ÍÑ…¹”™…¥±•ˆ¤ì(€€€È´ùÍ•ÍÍ¥½¸õ9½ÉµÉ•…Ñ•M•ÍÍ¥½¸¡È´ù¥¹ÍÑ…¹”±É½ÕÀ±Á½ÉÐ±¹½‘•%¡±½…±9½‘”¤¤ì¥˜¡È´ùÍ•ÍÍ¥½¸ôõ9=I5}MMM%=9}%9Y1%¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰9½ÉµÉ•…Ñ•M•ÍÍ¥½¸™…¥±•ˆ¤ì(€€€¥˜ …½¹™¥ÕÉ•I••¥Ù•È¡È´ùÍ•ÍÍ¥½¸±¥™…”±Í½ÕÉ”±±½½Á‰…¬„ôÀ¤¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰9=I4µÕ±Ñ¥…ÍÐ½¹™¥ÕÉ…Ñ¥½¸™…¥±•ˆ¤ì(€€€9½ÉµM•ÑIáA½ÉÑI•ÕÍ”¡È´ùÍ•ÍÍ¥½¸±ÑÉÕ”±¹Õ±±ÁÑÈ±¹Õ±±ÁÑÈ°À¤ì(€€€¥˜ …9½ÉµMÑ…ÉÑI••¥Ù•È¡È´ùÍ•ÍÍ¥½¸±Éá	Õ™™•È¤¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰9½ÉµMÑ…ÉÑI••¥Ù•È™…¥±•ˆ¤ì(€€€Õ¥¹ÐØÑ}Ð õ¹•áÑ!…¹‘±”¹™•Ñ¡}…‘ Ä¤ìÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àùœ¡Ñ…‰±•1½¬¤ì±¥ÍÑ•¹•ÉÌ¹•µÁ±…”¡ ±ÍÑèéµ½Ù”¡È¤¤ìÉ•ÑÕÉ¸ ì(€ô…Ñ ¡½¹ÍÐÍÑèé•á•ÁÑ¥½¸™”¥ì™…¥°¡½¹Ñ•áÐ±ÍÑèéÍÑÉ¥¹œ ‰9=I4±¥ÍÑ•¹•È½Á•¸è€ˆ¤­”¹Ý¡…Ð ¤¤ìÉ•ÑÕÉ¸€Àìô)ô)I•ááI½ÕÑ¥¹”Ä¡I•áá=‰©•ÑAÑÈ±¹½Éµ9…Ñ¥Ù•1¥ÍÑ•¹•ÉI••¥Ù”±Õ¥¹ÐØÑ}Ð±¡…¹‘±”¤ì(€ÑÉäì(€€€1¥ÍÑ•¹•È©ÈìíÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àùœ¡Ñ…‰±•1½¬¤íÈõ±¥ÍÑ•¹•È¡¡…¹‘±”¤íô¥˜ …È¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰Õ¹­¹½Ý¸±¥ÍÑ•¹•È¡…¹‘±”ˆ¤ì(€€€ÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡È´ù±½¬¤ì(€€€É•ÑÕÉ¸±¥ÍÑ•¹•ÉI••¥Ù•Ù•¹Ð¡½¹Ñ•áÐ±È±ÑÉÕ”¤ì(€ô…Ñ ¡½¹ÍÐÍÑèé•á•ÁÑ¥½¸™”¥ì™…¥°¡½¹Ñ•áÐ±ÍÑèéÍÑÉ¥¹œ ‰9=I4±¥ÍÑ•¹•ÈÉ••¥Ù”è€ˆ¤­”¹Ý¡…Ð ¤¤ìÉ•ÑÕÉ¸9U11=	)Pìô)ô)I•ááI½ÕÑ¥¹”Ä¡I•áá=‰©•ÑAÑÈ±¹½Éµ9…Ñ¥Ù•1¥ÍÑ•¹•ÉQÉåI••¥Ù”±Õ¥¹ÐØÑ}Ð±¡…¹‘±”¤ì(€ÑÉäì(€€€1¥ÍÑ•¹•È©ÈìíÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àùœ¡Ñ…‰±•1½¬¤íÈõ±¥ÍÑ•¹•È¡¡…¹‘±”¤íô¥˜ …È¤Ñ¡É½ÜÍÑèéÉÕ¹Ñ¥µ•}•ÉÉ½È ‰Õ¹­¹½Ý¸±¥ÍÑ•¹•È¡…¹‘±”ˆ¤ì(€€€ÍÑèé±½­}Õ…ÉñÍÑèéµÕÑ•àøœ¡È´ù±½¬¤ì(€€€É•ÑÕÉ¸±¥ÍÑ•¹•ÉI••¥Ù•Ù•¹Ð¡½¹Ñ•áÐ±È±™…±Í”¤ì(€ô…Ñ ¡½¹ÍÐÍÑèé•á•ÁÑ¥½¸™”¥ì™…¥°¡½¹Ñ•áÐ±ÍÑèéÍÑÉ¥¹œ ‰9=I4‚Æ—7FVæW"G'’&V6V—fS¢"’¶Rçv†B‚’“²&WGW&âåTÄÄô$¤T5C²Ð§Ð¥&W‡…&÷WF–æS"†–çBÆæ÷&ÔæF—fTÆ—7FVæW%v—BÇV–çCcE÷BÆ†æFÆRÆ–çBÇF–ÖV÷WD×2’°¢G'’°¢Æ—7FVæW"§#²·7FC£¦Æö6µöwV&CÇ7FC£¦×WFWƒær‡F&ÆTÆö6²“·#ÖÆ—7FVæW"††æFÆR“·Ò–b‚"’F‡&÷r7FC£§'VçF–ÖUöW'&÷"‚'Væ¶æ÷vâÆ—7FVæW"†æFÆR"“°¢&WGW&âv—DFW67&—F÷"„æ÷&ÔvWDFW67&—F÷"‡"Óæ–ç7Fæ6R’ÇF–ÖV÷WD×2“°¢Ò6F6‚†6öç7B7FC£¦W†6WF–öâfR—²f–Â†6öçFW‡BÇ7FC£§7G&–ær‚$äõ$ÒÆ—7FVæW"v—C¢"’¶Rçv†B‚’“²&WGW&âÓ²Ð§Ð¥&W‡…&÷WF–æS†–çBÆæ÷&ÔæF—fTÆ—7FVæW$FW67&—F÷"ÇV–çCcE÷BÆ†æFÆR—°¢‡fö–B–6öçFW‡C²7FC£¦Æö6µöwV&CÇ7FC£¦×WFWƒær‡F&ÆTÆö6²“¶WFò§#ÖÆ—7FVæW"††æFÆR“·&WGW&â#ôæ÷&ÔvWDFW67&—F÷"‡"Óæ–ç7Fæ6R“¢Ó°§Ð¥&W‡…&÷WF–æS†–çBÆæ÷&ÔæF—fTÆ—7FVæW$6Æ÷6RÇV–çCcE÷BÆ†æFÆR—°¢‡fö–B–6öçFW‡C²7FC£§Væ—VU÷G#ÄÆ—7FVæW#ç#²·7FC£¦Æö6µöwV&CÇ7FC£¦×WFWƒær‡F&ÆTÆö6²“¶WFò“ÖÆ—7FVæW'2æf–æB††æFÆR“¶–b†“ÓÖÆ—7FVæW'2æVæB‚’—&WGW&â·#×7FC£¦Ö÷fR†’Óç6V6öæB“¶Æ—7FVæW'2æW&6R†’“·Ò&WGW&â°§Ð ¥&W‡…&÷WF–æTVçG'’&÷WF–æW5µÓ×°¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fUfW'6–öâÆæ÷&ÔæF—fUfW'6–öâ’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fU6VæFW$÷VâÆæ÷&ÔæF—fU6VæFW$÷Vâ’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fU6VæFW%6VæBÆæ÷&ÔæF—fU6VæFW%6VæB’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fU6VæFW%6WDÆ÷72Ææ÷&ÔæF—fU6VæFW%6WDÆ÷72’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fU6VæFW%v—DG&–æVBÆæ÷&ÔæF—fU6VæFW%v—DG&–æVB’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fU6VæFW$FW67&—F÷"Ææ÷&ÔæF—fU6VæFW$FW67&—F÷"’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fU6VæFW$6Æ÷6RÆæ÷&ÔæF—fU6VæFW$6Æ÷6R’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fTÆ—7FVæW$÷VâÆæ÷&ÔæF—fTÆ—7FVæW$÷Vâ’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fTÆ—7FVæW%&V6V—fRÆæ÷&ÔæF—fTÆ—7FVæW%&V6V—fR’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fTÆ—7FVæW%G'•&V6V—fRÆæ÷&ÔæF—fTÆ—7FVæW%G'•&V6V—fR’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fTÆ—7FVæW%v—BÆæ÷&ÔæF—fTÆ—7FVæW%v—B’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fTÆ—7FVæW$FW67&—F÷"Ææ÷&ÔæF—fTÆ—7FVæW$FW67&—F÷"’À¢$U……õE•TEõ$õUD”äR†æ÷&ÔæF—fTÆ—7FVæW$6Æ÷6RÆæ÷&ÔæF—fTÆ—7FVæW$6Æ÷6R’À¢$U……ôÄ5Eõ$õUD”äR‚—Ó°¥&W‡…6¶vTVçG'’ö÷&W‡…öæ÷&ÕöæF—fU÷6¶vUöVçG'“×µ5DäD$Eõ4´tUô„TDU"$U……ô”åDU%$UDU%óUóóÂ&ö÷&W‡…öæ÷&ÕöæF—fR"Â#ãÖFWc2"ÆçVÆÇG"ÆçVÆÇG"Ç&÷WF–æW2ÆçVÆÇG'Ó°¤ôõ$U……ôtUEõ4´tR†ö÷&W‡…öæ÷&ÕöæF—fR“° 