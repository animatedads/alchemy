#ifndef WIRE_FILTER_WINDOW_H
#define WIRE_FILTER_WINDOW_H
#include <stddef.h>
#include <stdint.h>
#include "wire_renderer.h"

typedef int (*WireRowPredicateFn)(void *ctx, const WireListRow *row);

typedef struct {
    WireListSource *source;
    WireRowPredicateFn predicate;
    void *predicate_ctx;
    size_t pull_size;
    uint64_t upstream_next;
    uint64_t upstream_count;
    int count_known;
    int exhausted;
    uint64_t candidates_seen;
    uint64_t rows_emitted;
    uint64_t pulls;
} WireFilterWindow;

/* Sequential filtered-window controller. The predicate sees rows only; it has
   no source handle and therefore no authority to pull. Pull policy lives here. */
void wire_filter_window_init(WireFilterWindow *w, WireListSource *source,
                             size_t pull_size, WireRowPredicateFn predicate,
                             void *predicate_ctx);
void wire_filter_window_reset(WireFilterWindow *w);
size_t wire_filter_window_next(WireFilterWindow *w, size_t wanted,
                               WireListRow *out);
/* next() owns copies of row strings so output survives additional upstream pulls. */
void wire_filter_window_release_rows(WireListRow *rows, size_t count);
#endif
