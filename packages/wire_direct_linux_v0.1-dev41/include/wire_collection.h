#ifndef WIRE_COLLECTION_H
#define WIRE_COLLECTION_H
#include "wire_renderer.h"
typedef WireListRow WireRow;
typedef struct WireCollection WireCollection;
typedef uint64_t (*WireCountFn)(WireCollection*);
typedef size_t (*WireRangeFn)(WireCollection*,uint64_t start,size_t count,WireRow *out);
struct WireCollection { void *impl; WireCountFn count; WireRangeFn range; };
#endif
