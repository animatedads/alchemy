#include "pharo_alchemy_native.h"
#include <stdint.h>
#include <string.h>

/* Qualification entry point exported to Pharo 12 FFI.  It deliberately runs
 * through the real dev7/dev8 lifecycle dispatcher rather than merely adding
 * in a standalone C function.
 */
typedef struct { int32_t input; } probe_context_t;

static pa_result_t probe_dispatch(const pa_message_t *message, void *userdata) {
    probe_context_t *ctx=(probe_context_t *)userdata;
    pa_result_t r;
    (void)message;
    memset(&r,0,sizeof(r));
    r.status=PA_OK;
    r.result.identity=(pa_identity_t)(ctx->input + 1);
    r.result.generation=1;
    return r;
}

int32_t pa_pharo12_ffi_roundtrip(int32_t value) {
    pa_registry_t *registry=pa_registry_create();
    pa_handle_t receiver;
    pa_message_t message;
    pa_result_t result;
    probe_context_t ctx;
    if (!registry) return -1000;
    receiver=pa_registry_publish(registry,0x504841524fULL);
    memset(&message,0,sizeof(message));
    message.receiver=receiver;
    message.selector_utf8="dev10NativeRoundtrip:";
    message.call_id=10;
    ctx.input=value;
    result=pa_dispatch_pinned(registry,&message,probe_dispatch,&ctx);
    pa_registry_destroy(registry);
    if (result.status != PA_OK || result.call_id != 10) return -1001;
    return (int32_t)result.result.identity;
}
