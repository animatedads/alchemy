#ifndef WIRE_UI_LOADER_H
#define WIRE_UI_LOADER_H
#include "wire_renderer.h"
typedef struct { const char *name; const WireListSource *source; } WireNamedListSource;
typedef void (*WireUIElementLoaded)(void *ctx,const char *semantic_id,WireHandle handle,WireElementKind kind);
/* Declarative virtual-list policy belongs to the UI definition.  This callback
 * lets application/source-window authority learn the declared resident range
 * without reparsing XML/.wire or duplicating count constants in host code. */
typedef void (*WireUIVirtualListLoaded)(void *ctx,const char *semantic_id,WireHandle handle,const char *source_name,uint64_t start,size_t count);
typedef struct {
 WireRenderer *renderer;
 const WireNamedListSource *lists;
 size_t list_count;
 WireUIElementLoaded element_loaded;
 void *element_loaded_ctx;
 WireUIVirtualListLoaded virtual_list_loaded;
 void *virtual_list_loaded_ctx;
} WireUILoadContext;
WireResult wire_ui_load_file(const char *path,const WireUILoadContext *ctx,WireHandle *root_out);
#endif
