#ifndef WIRE_TEST_RENDERER_H
#define WIRE_TEST_RENDERER_H
#include "wire_renderer.h"
WireRenderer *wire_test_renderer_new(void);
unsigned wire_test_renderer_create_count(WireRenderer *r);
WireResult wire_test_renderer_fire(WireRenderer *r,const char *id,const char *trigger);
WireResult wire_test_renderer_select_visible(WireRenderer *r,WireHandle h,size_t visible_index);
size_t wire_test_renderer_visible_count(WireRenderer *r);
uint64_t wire_test_renderer_visible_identity(WireRenderer *r,size_t i);
const char *wire_test_renderer_visible_stable_id(WireRenderer *r,size_t i);
const char *wire_test_renderer_row_property(WireRenderer *r,WireHandle h,const char *stable_id,const char *key);
const char *wire_test_renderer_property(WireRenderer *r,WireHandle h,const char *key);
#endif
