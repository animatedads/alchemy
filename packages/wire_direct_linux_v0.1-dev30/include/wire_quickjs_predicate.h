#ifndef WIRE_QUICKJS_PREDICATE_H
#define WIRE_QUICKJS_PREDICATE_H
#include "wire_renderer.h"
typedef struct WireQuickJSPredicate WireQuickJSPredicate;
/* Concrete qualification adapter only. WireFilterWindow remains language-neutral.
   SOURCE is a JS function expression receiving one bounded row projection. */
WireQuickJSPredicate *wire_quickjs_predicate_new(const char *source);
int wire_quickjs_predicate_test(void *ctx, const WireListRow *row);
int wire_quickjs_predicate_failed(const WireQuickJSPredicate *p);
unsigned long long wire_quickjs_predicate_calls(const WireQuickJSPredicate *p);
void wire_quickjs_predicate_free(WireQuickJSPredicate *p);
#endif
