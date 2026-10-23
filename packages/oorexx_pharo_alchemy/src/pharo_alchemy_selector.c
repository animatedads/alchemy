#include "pharo_alchemy_selector.h"
#include <stddef.h>
/* ASCII grammar only; method availability remains authoritative in Pharo. */
static int alpha(unsigned char c) { return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'); }
static int digit(unsigned char c) { return c >= '0' && c <= '9'; }
static int initial(unsigned char c) { return alpha(c) || c == '_'; }
static int continuation(unsigned char c) { return initial(c) || digit(c); }
static int binary_char(unsigned char c) {
 const char *ops = "+-*/=<>~&|@%?,\\";
 for (const char *p = ops; *p; ++p) if ((unsigned char)*p == c) return 1;
 return 0;
}
pa_selector_validation pa_validate_selector_shape(const pa_live_message *m) {
 if (pa_validate_live_message(m) != PA_M_VALID) return PA_S_BAD_BYTES;
 const unsigned char *s = (const unsigned char *)m->selector;
 size_t n = m->selector_length;
 for (size_t i = 0; i < n; ++i) if (s[i] == 0 || s[i] > 127) return PA_S_BAD_BYTES;
 size_t i = 0, parts = 0;
 if (initial(s[0])) {
  while (i < n) {
   if (!initial(s[i])) return PA_S_BAD_BYTES;
   ++i;
   while (i < n && continuation(s[i])) ++i;
   if (i == n) return parts == 0 && m->argc == 0 ? PA_S_VALID : PA_S_BAD_ARITY;
   if (s[i] != ':') return PA_S_BAD_BYTES;
   ++parts; ++i;
   if (i == n) return m->argc == parts ? PA_S_VALID : PA_S_BAD_ARITY;
  }
 } else {
  if (n > 2) return PA_S_BAD_BYTES;
  for (i = 0; i < n; ++i) if (!binary_char(s[i])) return PA_S_BAD_BYTES;
  return m->argc == 1 ? PA_S_VALID : PA_S_BAD_ARITY;
 }
 return PA_S_BAD_BYTES;
}
