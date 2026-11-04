#include "wire_filter_window.h"
#include <stdlib.h>
#include <string.h>

static char *copy_s(const char *s) {
    if (!s) return NULL;
    size_t n=strlen(s)+1;
    char *p=(char*)malloc(n);
    if (p) memcpy(p,s,n);
    return p;
}
static int copy_row(WireListRow *dst,const WireListRow *src) {
    *dst=*src;
    dst->stable_id=copy_s(src->stable_id);
    dst->from=copy_s(src->from);
    dst->subject=copy_s(src->subject);
    dst->date=copy_s(src->date);
    if ((src->stable_id&&!dst->stable_id)||(src->from&&!dst->from)||
        (src->subject&&!dst->subject)||(src->date&&!dst->date)) return 0;
    return 1;
}
void wire_filter_window_release_rows(WireListRow *rows,size_t count) {
    if(!rows) return;
    for(size_t i=0;i<count;i++) {
        free((void*)rows[i].stable_id); free((void*)rows[i].from);
        free((void*)rows[i].subject); free((void*)rows[i].date);
        memset(&rows[i],0,sizeof rows[i]);
    }
}

void wire_filter_window_init(WireFilterWindow *w, WireListSource *source,
                             size_t pull_size, WireRowPredicateFn predicate,
                             void *predicate_ctx) {
    if (!w) return;
    w->source=source; w->predicate=predicate; w->predicate_ctx=predicate_ctx;
    w->pull_size=pull_size ? pull_size : 1; w->upstream_next=0;
    w->upstream_count=0; w->count_known=0; w->exhausted=0;
    w->candidates_seen=0; w->rows_emitted=0; w->pulls=0;
}
void wire_filter_window_reset(WireFilterWindow *w) {
    if (!w) return;
    w->upstream_next=0; w->exhausted=0; w->candidates_seen=0;
    w->rows_emitted=0; w->pulls=0;
}
size_t wire_filter_window_next(WireFilterWindow *w, size_t wanted,
                               WireListRow *out) {
    if (!w || !w->source || !w->source->range || !out || wanted==0 || w->exhausted)
        return 0;
    if (!w->count_known) {
        w->upstream_count=w->source->count ? w->source->count(w->source->ctx) : UINT64_MAX;
        w->count_known=1;
    }
    WireListRow *buf=(WireListRow*)calloc(w->pull_size,sizeof(*buf));
    if (!buf) return 0;
    size_t produced=0;
    while (produced < wanted && !w->exhausted) {
        if (w->upstream_next >= w->upstream_count) { w->exhausted=1; break; }
        size_t ask=w->pull_size;
        uint64_t remain=w->upstream_count-w->upstream_next;
        if (remain < ask) ask=(size_t)remain;
        size_t got=w->source->range(w->source->ctx,w->upstream_next,ask,buf);
        w->pulls++;
        if (got==0) { w->exhausted=1; break; }
        size_t consumed=0;
        for (size_t i=0;i<got;i++) {
            consumed++; w->upstream_next++; w->candidates_seen++;
            if (!w->predicate || w->predicate(w->predicate_ctx,&buf[i])) {
                if (!copy_row(&out[produced],&buf[i])) { free(buf); return produced; }
                produced++; w->rows_emitted++;
                if (produced==wanted) break;
            }
        }
        /* A source range is random-access by ordinal. Unconsumed candidates from
           this pull remain upstream: continuation points at the first unconsumed row. */
        (void)consumed;
        if (got < ask) w->exhausted=1;
    }
    free(buf); return produced;
}
