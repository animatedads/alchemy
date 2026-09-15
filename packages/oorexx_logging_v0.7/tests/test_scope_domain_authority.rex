ring = .CryptoMacKeyRing~new
ring~addKey("logging-domain-test", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(ring)
service = .LogService~new("logging-domain-service", authority)

scopeA = .Log~customerScope("CUSTOMER-A")
scopeB = .Log~customerScope("CUSTOMER-B")
rule = .LogRule~new("customer-a-to-b", "web", "WebsiteUI", "generateCustomerPanel", -
  scopeA, scopeB, .Log~WARN, .nil, .array~new)
call assertTrue rule~requiresAuthority, "cross-customer domain requires authority"
call assertTrue rule~requiresEscalation, "compatibility escalation method covers domain transitions"

signal on syntax name noCapRejected
ignore = service~addRule(rule)
raise syntax 88.900 array("cross-domain rule without capability was accepted")
noCapRejected:
signal off syntax

/* Disclosure-only claims are insufficient when an exact domain is present. */
weakClaims = .directory~new
weakClaims["rule_id"] = rule~ruleId
weakClaims["source_scope"] = .Log~CUSTOMER
weakClaims["delivery_scope"] = .Log~CUSTOMER
weak = authority~issueForSeconds("tester", service~serviceId, "LOG_SCOPE_ESCALATE", "LOGGING", 60, "", weakClaims)
signal on syntax name weakRejected
ignore = service~addRule(rule, weak)
raise syntax 88.900 array("domain transition accepted without exact scope ids")
weakRejected:
signal off syntax

claims = .directory~new
claims["rule_id"] = rule~ruleId
claims["source_scope"] = .Log~CUSTOMER
claims["delivery_scope"] = .Log~CUSTOMER
claims["source_scope_id"] = scopeA~scopeId
claims["delivery_scope_id"] = scopeB~scopeId
cap = authority~issueForSeconds("tester", service~serviceId, "LOG_SCOPE_ESCALATE", "LOGGING", 60, "", claims)
ignore = service~addRule(rule, cap)
call assertEq cap~capabilityId, rule~authorisationId, "exact cross-domain capability accepted"

same = .LogRule~new("customer-a-same", "web", "WebsiteUI", "same", -
  scopeA, scopeA, .Log~INFO, .nil, .array~new)
call assertFalse same~requiresAuthority, "same exact customer domain requires no transition authority"
ignore = service~addRule(same)

say "SCOPE_DOMAIN_AUTH same_rank_cross_domain=AUTHORIZED exact_scope_claims=PASS"
say "PASS test_scope_domain_authority"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::requires "LoggingCore.cls"
::requires "AlchemySecurity.cls"
