#include <stdint.h>
typedef int32_t (*pa_pharo_callback_t)(int32_t argument);
/* Qualification seam for native -> resident Pharo re-entry. The callback is
 * owned by Pharo; native code invokes it synchronously and returns its value. */
int32_t pa_pharo12_callback_roundtrip(pa_pharo_callback_t callback,
                                      int32_t argument) {
    if (!callback) return -1000;
    return callback(argument);
}
