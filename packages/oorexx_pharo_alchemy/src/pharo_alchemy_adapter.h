#ifndef PHARO_ALCHEMY_ADAPTER_H
#define PHARO_ALCHEMY_ADAPTER_H
#include "pharo_alchemy_native.h"
typedef struct {
 void *runtime;
 pa_status_t (*understands)(void*,pa_handle_t,const char*,int*);
 pa_result_t (*send)(void*,const pa_message_t*);
 pa_status_t (*retain)(void*,pa_handle_t);
 pa_status_t (*release)(void*,pa_handle_t);
} pa_runtime_adapter_t;
/* Dispatch through a runtime adapter. Missing selector and a method that
 * throws remain distinct runtime outcomes. */
pa_result_t pa_adapter_dispatch(const pa_message_t*,void*);
/* Passive, live discovery. This must never execute the target selector. */
pa_status_t pa_adapter_understands(pa_runtime_adapter_t*,pa_handle_t,const char*,int*);
#endif
