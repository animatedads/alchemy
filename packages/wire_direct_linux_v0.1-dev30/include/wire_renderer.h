#ifndef WIRE_RENDERER_H
#define WIRE_RENDERER_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#define WIRE_RENDERER_ABI 4u
typedef uint64_t WireHandle;
typedef enum { WIRE_OK=0, WIRE_EINVAL=1, WIRE_ENOTSUP=2, WIRE_ESTATE=3 } WireResult;
typedef enum { WIRE_WINDOW=1, WIRE_STACK, WIRE_SPLIT, WIRE_LABEL, WIRE_BUTTON, WIRE_TEXT_INPUT, WIRE_SCROLL, WIRE_VIRTUAL_LIST, WIRE_DOCUMENT } WireElementKind;
typedef struct { const char *key; const char *value; } WireProperty;
typedef struct { const char *source_id; const char *trigger; const char *detail_key; const char *detail_value; } WireNativeEvent;
/* stable_id is application identity, not renderer row position. It must remain valid for the duration of range() result consumption. */
typedef struct { uint64_t identity; const char *stable_id; const char *from; const char *subject; const char *date; } WireListRow;
typedef void (*WireDispatch)(void *ctx,const WireNativeEvent *event);
typedef size_t (*WireListRange)(void *ctx,uint64_t start,size_t count,WireListRow *out);
typedef uint64_t (*WireListCount)(void *ctx);
typedef struct { void *ctx; WireListCount count; WireListRange range; } WireListSource;
/* Semantic property for one already-visible row. stable_id is application identity. */
typedef struct { const char *stable_id; const char *key; const char *value; } WireListRowProperty;
typedef struct WireRenderer WireRenderer;
typedef struct {
 uint32_t abi;
 void (*destroy)(WireRenderer *r);
 WireResult (*create)(WireRenderer *r,WireHandle h,WireElementKind kind,WireHandle parent);
 WireResult (*set_property)(WireRenderer *r,WireHandle h,const WireProperty *p);
 WireResult (*remove)(WireRenderer *r,WireHandle h);
 WireResult (*set_dispatch)(WireRenderer *r,WireDispatch fn,void *ctx);
 WireResult (*bind_list)(WireRenderer *r,WireHandle h,const WireListSource *source);
 WireResult (*show_list_range)(WireRenderer *r,WireHandle h,uint64_t start,size_t count);
 WireResult (*set_list_row_property)(WireRenderer *r,WireHandle h,const WireListRowProperty *p);
 WireResult (*run)(WireRenderer *r);
} WireRendererVTable;
struct WireRenderer { const WireRendererVTable *v; void *impl; };
#ifdef __cplusplus
}
#endif
#endif
