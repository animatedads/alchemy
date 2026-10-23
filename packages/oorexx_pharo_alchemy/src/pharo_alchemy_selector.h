#ifndef PHARO_ALCHEMY_SELECTOR_H
#define PHARO_ALCHEMY_SELECTOR_H
#include "pharo_alchemy_message_contract.h"
typedef enum { PA_S_VALID=0, PA_S_BAD_BYTES=1, PA_S_BAD_ARITY=2 } pa_selector_validation;
pa_selector_validation pa_validate_selector_shape(const pa_live_message *message);
#endif
