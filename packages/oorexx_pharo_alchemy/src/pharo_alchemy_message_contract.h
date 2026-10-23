#ifndef PHARO_ALCHEMY_MESSAGE_CONTRACT_H
#define PHARO_ALCHEMY_MESSAGE_CONTRACT_H
#include <stdint.h>
#include <stddef.h>
/* Values are tagged: arbitrary foreign objects are handles, never snapshots. */
typedef enum { PA_V_OMITTED=0, PA_V_NIL=1, PA_V_INT64=2, PA_V_STRING=3, PA_V_HANDLE=4 } pa_value_kind;
typedef struct { uint64_t identity, generation; } pa_live_handle;
typedef struct { pa_value_kind kind; union { int64_t integer; struct {const char *bytes; size_t length;} string; pa_live_handle handle;} as; } pa_value;
typedef struct { pa_live_handle receiver; const char *selector; size_t selector_length; const pa_value *argv; const uint8_t *present; size_t argc; uint64_t call_id; } pa_live_message;
typedef enum { PA_M_VALID=0, PA_M_BAD_RECEIVER=1, PA_M_BAD_SELECTOR=2, PA_M_BAD_ARGUMENT=3, PA_M_BAD_SHAPE=4 } pa_message_validation;
pa_message_validation pa_validate_live_message(const pa_live_message *message);
#endif
