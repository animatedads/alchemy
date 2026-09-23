#include "pharo_alchemy_adapter.h"
#include <string.h>

pa_result_t pa_adapter_dispatch(const pa_message_t *m, void *userdata) {
    pa_runtime_adapter_t *a=(pa_runtime_adapter_t *)userdata;
    pa_result_t z;
    memset(&z,0,sizeof(z));
    z.status=PA_INTERNAL;
    if (!a || !a->send || !m) {
        return z;
    }
    z=a->send(a->runtime,m);
    z.call_id=m->call_id;
    return z;
}

pa_status_t pa_adapter_understands(pa_runtime_adapter_t *a, pa_handle_t h,
                                   const char *selector, int *answer) {
    if (!a || !a->understands || !selector || !answer) {
        return PA_BAD_MESSAGE;
    }
    return a->understands(a->runtime,h,selector,answer);
}
