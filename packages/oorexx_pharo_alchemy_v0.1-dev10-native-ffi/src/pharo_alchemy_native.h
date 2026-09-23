#ifndef PHARO_ALCHEMY_NATIVE_H
#define PHARO_ALCHEMY_NATIVE_H
#include <stddef.h>
#include <stdint.h>

typedef uint64_t pa_identity_t;
typedef uint64_t pa_generation_t;
typedef uint64_t pa_call_id_t;

typedef struct {
  pa_identity_t identity;
  pa_generation_t generation;
} pa_handle_t;

typedef enum {
  PA_OK=0,
  PA_NO_SELECTOR=1,
  PA_FOREIGN_EXCEPTION=2,
  PA_STALE_HANDLE=3,
  PA_REENTRY_DENIED=4,
  PA_REVOKED=5,
  PA_BAD_MESSAGE=6,
  PA_INTERNAL=255
} pa_status_t;

/* A positional slot exists independently of whether a value was supplied.
 * presence_bitmap bit N == 1 means arguments[N] is supplied.  A supplied
 * language nil is therefore different from an omitted slot.
 */
typedef struct {
  pa_handle_t receiver;
  const char *selector_utf8;
  const pa_handle_t *arguments;       /* positional_count entries */
  const uint64_t *presence_bitmap;    /* ceil(positional_count/64) words */
  uint32_t positional_count;
  pa_call_id_t call_id;
} pa_message_t;

typedef struct {
  pa_status_t status;
  pa_handle_t result;
  pa_handle_t exception;
  pa_call_id_t call_id;
} pa_result_t;

typedef pa_result_t (*pa_dispatch_fn)(const pa_message_t *message, void *userdata);

typedef struct pa_registry pa_registry_t;

pa_registry_t *pa_registry_create(void);
void pa_registry_destroy(pa_registry_t *registry);

/* Register a resident identity and return its current generation. */
pa_handle_t pa_registry_publish(pa_registry_t *registry, pa_identity_t identity);

/* Revoke the exact generation.  A pinned invocation may finish, but no new
 * invocation can pin the revoked generation.
 */
pa_status_t pa_registry_revoke(pa_registry_t *registry, pa_handle_t handle);

/* Pin/unpin are public for runtime adapters. */
pa_status_t pa_registry_pin(pa_registry_t *registry, pa_handle_t handle);
pa_status_t pa_registry_unpin(pa_registry_t *registry, pa_handle_t handle);

/* Resolve+pin under the registry lock, release the lock before entering the
 * foreign runtime, then reconcile/unpin after dispatch returns.
 */
pa_result_t pa_dispatch_pinned(pa_registry_t *registry,
                               const pa_message_t *message,
                               pa_dispatch_fn dispatch,
                               void *userdata);

int pa_argument_present(const pa_message_t *message, uint32_t position);

#endif
