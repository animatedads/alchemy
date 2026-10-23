#include "pharo_alchemy_selector.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static void check(const char *s, size_t argc, pa_selector_validation expected) {
 pa_value args[4] = {{0}};
 uint8_t present[4] = {0};
 pa_live_message m = {{1,1},s,strlen(s),args,present,argc,1};
 assert(pa_validate_selector_shape(&m) == expected);
}
int main(void) {
 check("size",0,PA_S_VALID);
 check("at:put:",2,PA_S_VALID);
 check("at:put:",1,PA_S_BAD_ARITY);
 check("at:put",1,PA_S_BAD_ARITY);
 check("at:bad name:",2,PA_S_BAD_BYTES);
 check("foo:bar",1,PA_S_BAD_ARITY);
 check("foo:bar:",2,PA_S_VALID);
 check("foo:2bar:",2,PA_S_BAD_BYTES);
 check("foo:bar-baz:",2,PA_S_BAD_BYTES);
 check("+",1,PA_S_VALID);
 check("<=",1,PA_S_VALID);
 check("+++",1,PA_S_BAD_BYTES);
 check("+",0,PA_S_BAD_ARITY);
 check("foo:bar:",0,PA_S_BAD_ARITY);
 puts("DEV16 selector hardening PASS");
 return 0;
}
