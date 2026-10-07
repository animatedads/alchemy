#include "pharo_alchemy_native.h"
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

typedef struct pa_entry {
  pa_identity_t identity;
  pa_generation_t generation;
  uint32_t pins;
  int revoked;
  struct pa_entry *next;
} pa_entry_t;

struct pa_registry {
  pthread_mutex_t lock;
  pa_entry_t *head;
};

static pa_entry_t *find_exact(pa_registry_t *r, pa_handle_t h) {
  pa_entry_t *e;
  for (e=r->head; e; e=e->next)
    if (e->identity == h.identity && e->generation == h.generation) return e;
  return NULL;
}

static pa_generation_t next_generation(pa_registry_t *r, pa_identity_t id) {
  pa_generation_t g=0;
  pa_entry_t *e;
  for (e=r->head; e; e=e->next)
    if (e->identity == id && e->generation > g) g=e->generation;
  return g+1;
}

pa_registry_t *pa_registry_create(void) {
  pa_registry_t *r=(pa_registry_t*)calloc(1,sizeof(*r));
  if (!r) return NULL;
  if (pthread_mutex_init(&r->lock,NULL) != 0) { free(r); return NULL; }
  return r;
}

void pa_registry_destroy(pa_registry_t *r) {
  pa_entry_t *e,*n;
  if (!r) return;
  pthread_mutex_lock(&r->lock);
  e=r->head; r->head=NULL;
  pthread_mutex_unlock(&r->lock);
  while (e) { n=e->next; free(e); e=n; }
  pthread_mutex_destroy(&r->lock);
  free(r);
}

pa_handle_t pa_registry_publish(pa_registry_t *r, pa_identity_t id) {
  pa_handle_t h={0,0};
  pa_entry_t *e;
  if (!r || !id) return h;
  pthread_mutex_lock(&r->lock);
  h.identity=id; h.generation=next_generation(r,id);
  e=(pa_entry_t*)calloc(1,sizeof(*e));
  if (e) { e->identity=id; e->generation=h.generation; e->next=r->head; r->head=e; }
  else { h.identity=0; h.generation=0; }
  pthread_mutex_unlock(&r->lock);
  return h;
}

pa_status_t pa_registry_pin(pa_registry_t *r, pa_handle_t h) {
  pa_entry_t *e;
  if (!r) return PA_INTERNAL;
  pthread_mutex_lock(&r->lock);
  e=find_exact(r,h);
  if (!e) { pthread_mutex_unlock(&r->lock); return PA_STALE_HANDLE; }
  if (e->revoked) { pthread_mutex_unlock(&r->lock); return PA_REVOKED; }
  e->pins++;
  pthread_mutex_unlock(&r->lock);
  return PA_OK;
}

pa_status_t pa_registry_unpin(pa_registry_t *r, pa_handle_t h) {
  pa_entry_t *e;
  if (!r) return PA_INTERNAL;
  pthread_mutex_lock(&r->lock);
  e=find_exact(r,h);
  if (!e || e->pins==0) { pthread_mutex_unlock(&r->lock); return PA_STALE_HANDLE; }
  e->pins--;
  pthread_mutex_unlock(&r->lock);
  return PA_OK;
}

pa_status_t pa_registry_revoke(pa_registry_t *r, pa_handle_t h) {
  pa_entry_t *e;
  if (!r) return PA_INTERNAL;
  pthread_mutex_lock(&r->lock);
  e=find_exact(r,h);
  if (!e) { pthread_mutex_unlock(&r->lock); return PA_STALE_HANDLE; }
  e->revoked=1;
  pthread_mutex_unlock(&r->lock);
  return PA_OK;
}

int pa_argument_present(const pa_message_t *m, uint32_t p) {
  if (!m || p>=m->positional_count || !m->presence_bitmap) return 0;
  return (int)((m->presence_bitmap[p/64] >> (p%64)) & 1ULL);
}

pa_result_t pa_dispatch_pinned(pa_registry_t *r, const pa_message_t *m,
                               pa_dispatch_fn dispatch, void *userdata) {
  pa_result_t z;
  pa_status_t s;
  memset(&z,0,sizeof(z));
  z.status=PA_BAD_MESSAGE;
  if (!r || !m || !dispatch || !m->selector_utf8) return z;
  z.call_id=m->call_id;
  s=pa_registry_pin(r,m->receiver);
  if (s != PA_OK) { z.status=s; return z; }

  /* Important: pa_registry_pin has released the registry mutex here.
   * Foreign execution and nested reverse dispatch therefore occur outside it.
   */
  z=dispatch(m,userdata);
  z.call_id=m->call_id;
  (void)pa_registry_unpin(r,m->receiver);
  return z;
}
