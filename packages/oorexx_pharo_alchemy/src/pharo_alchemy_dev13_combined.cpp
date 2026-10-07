#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include "oorexxapi.h"

typedef int32_t (*pa_binary_i32_cb)(int32_t,int32_t);
typedef int32_t (*pa_pharo_i32_cb)(int32_t);
static pa_pharo_i32_cb g_pharo_cb = 0;
static pa_binary_i32_cb g_rexx_cb = 0;
static int32_t g_a=0, g_b=0;
static int32_t g_last = -9000;

/* Called by Pharo.  The Pharo callback remains live for the complete nested
 * activation while an embedded ooRexx interpreter executes the qualification
 * program on this same native thread. */
extern "C" int32_t pa_dev13_run(pa_pharo_i32_cb pharo_cb) {
    if (!pharo_cb) return -1000;
    g_pharo_cb=pharo_cb; g_rexx_cb=0; g_last=-9001;
    RexxInstance *instance=0;
    RexxThreadContext *context=0;
    if (RexxCreateInterpreter(&instance,&context,0) == 0 || !instance || !context) {
        g_pharo_cb=0; return -1001;
    }
    const char *program=getenv("PHARO_ALCHEMY_DEV13_REXX");
    if (!program) { instance->Terminate(); g_pharo_cb=0; return -1002; }
    RexxArrayObject args=context->NewArray(0);
    (void)context->CallProgram(program,args);
    if (context->CheckCondition()) {
        context->ClearCondition();
        instance->Terminate(); g_pharo_cb=0; g_rexx_cb=0; return -1003;
    }
    instance->Terminate();
    g_pharo_cb=0; g_rexx_cb=0;
    return g_last;
}

/* Called by ooRexx through Foreign Runtime.  Keep the exact call-thread
 * callback closure supplied by Foreign Runtime, then enter resident Pharo. */
extern "C" int32_t pa_dev13_cross(pa_binary_i32_cb rexx_cb,int32_t a,int32_t b) {
    if (!rexx_cb || !g_pharo_cb) return -1100;
    g_rexx_cb=rexx_cb;
    g_a=a; g_b=b;
    fprintf(stderr,"DEV13 C cross a=%d b=%d pharo=%p rexx=%p\n",a,b,(void*)g_pharo_cb,(void*)g_rexx_cb); fflush(stderr);
    g_last=g_pharo_cb(b);
    fprintf(stderr,"DEV13 C pharo returned=%d\n",g_last); fflush(stderr);
    g_rexx_cb=0;
    return g_last;
}

/* Called by the resident Pharo callback while pa_dev13_cross is active.  This
 * is the actual Pharo -> native -> Foreign Runtime closure -> retained ooRexx
 * re-entry.  Foreign Runtime owns the RexxCallContext and SendMessage step. */
extern "C" int32_t pa_dev13_invoke_rexx(void) {
    if (!g_rexx_cb) return -1200;
    fprintf(stderr,"DEV13 C invoke rexx a=%d b=%d\n",g_a,g_b); fflush(stderr);
    int32_t v=g_rexx_cb(g_a,g_b); fprintf(stderr,"DEV13 C rexx returned=%d\n",v); fflush(stderr); return v;
}
