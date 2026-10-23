#include "pharo_alchemy_message_contract.h"
pa_message_validation pa_validate_live_message(const pa_live_message *m) {
 if (!m || !m->receiver.identity || !m->receiver.generation) return PA_M_BAD_RECEIVER;
 if (!m->selector || !m->selector_length) return PA_M_BAD_SELECTOR;
 if (m->argc && (!m->argv || !m->present)) return PA_M_BAD_SHAPE;
 for (size_t i=0;i<m->argc;i++) {
  if (m->present[i]>1) return PA_M_BAD_SHAPE;
  if (!m->present[i]) { if (m->argv[i].kind!=PA_V_OMITTED) return PA_M_BAD_ARGUMENT; continue; }
  switch(m->argv[i].kind) {
   case PA_V_NIL: case PA_V_INT64: break;
   case PA_V_STRING: if (m->argv[i].as.string.length && !m->argv[i].as.string.bytes) return PA_M_BAD_ARGUMENT; break;
   case PA_V_HANDLE: if (!m->argv[i].as.handle.identity || !m->argv[i].as.handle.generation) return PA_M_BAD_ARGUMENT; break;
   default: return PA_M_BAD_ARGUMENT;
  }
 }
 return PA_M_VALID;
}
