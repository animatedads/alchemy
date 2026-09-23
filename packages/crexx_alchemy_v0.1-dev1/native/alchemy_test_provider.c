/* cREXX Alchemy v0.1-dev1 -- RXPA mechanics qualification provider. */
#include <stdint.h>
#include <stdlib.h>
#define PLUGIN_ID alchemytest
#include "crexxpa.h"

#define MAGIC UINT64_C(0x414c4348454d5931)
typedef struct Projection {
    uint64_t magic, identity, generation;
    unsigned retain_count, closed;
    int64_t value;
} Projection;
static uint64_t next_identity = 1;
static const rxpa_host_services_v1 *active_host = NULL;

static Projection *retain(Projection *p) {
    if (p && p->magic == MAGIC) ++p->retain_count;
    return p;
}
static void release(Projection *p) {
    if (!p || p->magic != MAGIC) return;
    if (p->retain_count && --p->retain_count == 0) {
        p->magic = 0;
        free(p);
    }
}
static Projection *projection(rxpa_attribute_value v) {
    size_t n = 0;
    Projection **s = (Projection **)GETNATIVEPAYLOAD(v, &n, NULL, NULL);
    return s && n == sizeof(*s) && *s && (*s)->magic == MAGIC ? *s : NULL;
}
static void payload_finalize(void *v) {
    Projection **s = (Projection **)GETNATIVEPAYLOAD(
        (rxpa_attribute_value)v, NULL, NULL, NULL);
    if (s && *s) { release(*s); *s = NULL; }
}
static const rxpa_native_payload_ops payload_ops;
static void payload_copy(void *d, void *s) {
    Projection **src = (Projection **)GETNATIVEPAYLOAD(
        (rxpa_attribute_value)s, NULL, NULL, NULL);
    Projection *p = src && *src ? retain(*src) : NULL;
    (void)SETNATIVEPAYLOAD((rxpa_attribute_value)d, &p, sizeof(p),
                           &payload_ops, 0u);
}
static const rxpa_native_payload_ops payload_ops = {
    "alchemytest.Projection", payload_copy, payload_finalize
};
static Projection *require_projection(rxpa_attribute_value v,
                                      rxpa_attribute_value sig) {
    Projection *p;
    if (!v || !ISINITIALIZED(v)) {
        SETINT(sig, SIGNAL_OBJECT_NOT_INITIALIZED);
        SETSTRING(sig, "box not initialized");
        return NULL;
    }
    p = projection(v);
    if (!p) {
        SETINT(sig, SIGNAL_FAILURE);
        SETSTRING(sig, "native projection missing");
    }
    return p;
}

PROCEDURE(box_factory) {
    Projection *p, *slot;
    if (NUM_ARGS != 1)
        RETURNSIGNAL(SIGNAL_INVALID_ARGUMENTS, "box(value) expects one .int")
    if (!active_host || !rxpa_host_has_object_set_type(active_host))
        RETURNSIGNAL(SIGNAL_FAILURE, "RXPA object-type host service unavailable")
    p = (Projection *)calloc(1, sizeof(*p));
    if (!p) RETURNSIGNAL(SIGNAL_FAILURE, "projection allocation failed")
    p->magic = MAGIC;
    p->identity = next_identity++;
    p->generation = 1;
    p->retain_count = 1;
    p->value = GETINT(ARG0);
    slot = p;
    if (SETNATIVEPAYLOAD(RETURN, &slot, sizeof(slot), &payload_ops, 0u) != 0) {
        release(p);
        RETURNSIGNAL(SIGNAL_FAILURE, "payload installation failed")
    }
    if (rxpa_set_object_type(active_host, RETURN, "alchemytest.box") != 0)
        RETURNSIGNAL(SIGNAL_FAILURE, "could not publish concrete box type")
    RESETSIGNAL
}
METHODPROCEDURE(box_value) {
    Projection *p = require_projection(ARG0, SIGNAL); if (!p) return;
    if (p->closed) RETURNSIGNAL(SIGNAL_FAILURE, "projection is closed")
    SETINT(RETURN, (rxinteger)p->value); RESETSIGNAL
}
METHODPROCEDURE(box_identity) {
    Projection *p = require_projection(ARG0, SIGNAL); if (!p) return;
    SETINT(RETURN, (rxinteger)p->identity); RESETSIGNAL
}
METHODPROCEDURE(box_increment) {
    Projection *p = require_projection(ARG0, SIGNAL); if (!p) return;
    if (p->closed) RETURNSIGNAL(SIGNAL_FAILURE, "projection is closed")
    SETINT(RETURN, (rxinteger)++p->value); RESETSIGNAL
}
METHODPROCEDURE(box_close) {
    Projection *p = require_projection(ARG0, SIGNAL); if (!p) return;
    p->closed = 1;
    SETINT(RETURN, 0); RESETSIGNAL
}
PROCEDURE(invoke_callback) {
    rxpa_attribute_value a[1];
    if (NUM_ARGS != 2)
        RETURNSIGNAL(SIGNAL_INVALID_ARGUMENTS, "invoke_callback expects receiver,value")
    a[0] = ARG1;
    if (CALLMETHOD(ARG0, "rxsig1|on_value|.int|value=.int",
                   1, a, RETURN) != 0) return;
    RESETSIGNAL
}
PROCEDURE(nested_add_one) {
    if (NUM_ARGS != 1)
        RETURNSIGNAL(SIGNAL_INVALID_ARGUMENTS, "nested_add_one expects .int")
    SETINT(RETURN, GETINT(ARG0) + 1); RESETSIGNAL
}

LOADFUNCS
ADDCLASS("alchemytest.box");
ADDFACTORYPROC(box_factory, "alchemytest.box", ".alchemytest..box", "value=.int");
ADDMETHODPROC(box_value, "alchemytest.box", "value", ".int", "");
ADDMETHODPROC(box_identity, "alchemytest.box", "identity", ".int", "");
ADDMETHODPROC(box_increment, "alchemytest.box", "increment", ".int", "");
ADDMETHODPROC(box_close, "alchemytest.box", "close", ".int", "");
ADDPROC(invoke_callback, "alchemytest.invoke_callback", "b", ".int",
        "receiver=.object,value=.int");
ADDPROC(nested_add_one, "alchemytest.nested_add_one", "b", ".int", "value=.int");
ENDLOADFUNCS
