#include "../src/pharo_alchemy_native.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

typedef struct { pa_registry_t *r; int nested_ok; } ctx_t;

static pa_result_t reverse_send(const pa_message_t *m, void *u) {
  ctx_t *c=(ctx_t*)u;
  pa_result_t r; memset(&r,0,sizeof(r)); r.status=PA_OK;
  /* If the registry lock were held across dispatch, this nested pin would deadlock. */
  if (pa_registry_pin(c->r,m->receiver)==PA_OK) {
    c->nested_ok=1;
    assert(pa_registry_unpin(c->r,m->receiver)==PA_OK);
  }
  assert(pa_argument_present(m,0)==1);
  assert(pa_argument_present(m,1)==0);
  assert(pa_argument_present(m,2)==1);
  return r;
}

int main(void) {
  pa_registry_t *r=pa_registry_create();
  pa_handle_t h1,h2;
  uint64_t bits[1]={0};
  pa_handle_t argv[3]={{11,1},{0,0},{12,1}};
  pa_message_t m;
  ctx_t c={r,0};
  pa_result_t rr;

  assert(r);
  h1=pa_registry_publish(r,77);
  assert(h1.identity==77 && h1.generation==1);

  bits[0]=(1ULL<<0)|(1ULL<<2);
  memset(&m,0,sizeof(m));
  m.receiver=h1; m.selector_utf8="alpha:beta:gamma:";
  m.arguments=argv; m.presence_bitmap=bits; m.positional_count=3; m.call_id=99;

  rr=pa_dispatch_pinned(r,&m,reverse_send,&c);
  assert(rr.status==PA_OK && rr.call_id==99 && c.nested_ok);

  assert(pa_registry_revoke(r,h1)==PA_OK);
  rr=pa_dispatch_pinned(r,&m,reverse_send,&c);
  assert(rr.status==PA_REVOKED);

  h2=pa_registry_publish(r,77);
  assert(h2.identity==77 && h2.generation==2);
  assert(pa_registry_pin(r,h1)==PA_REVOKED);
  assert(pa_registry_pin(r,h2)==PA_OK);
  assert(pa_registry_unpin(r,h2)==PA_OK);

  puts("PHARO ALCHEMY native lifecycle/shape core PASS");
  pa_registry_destroy(r);
  return 0;
}
