ring = .CryptoMacKeyRing~new
ring~addKey("logging-scope-test", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(ring)
service = .LogService~new("logging-scope-service", authority)

rule = .LogRule~new("customer-to-internal", "web", "WebsiteUI", "generateCustomerPanel", -
  .Log~CUSTOMER, .Log~INTERNAL, .Log~WARN, .nil, .array~new)
call assertTrue rule~requiresEscalation, "customer to internal is an escalation"

signal on syntax name noCapRejected
ignore = service~addRule(rule)
raise syntax 88.900 array("scope escalation without capability was accepted")
noCapRejected:
signal off syntax

badClaims = .directory~new
badClaims["rule_id"] = rule~ruleId
badClaims["source_scope"] = .Log~CUSTOMER
badClaims["delivery_scope"] = .Log~SECRET
bad = authority~issueForSeconds("tester", service~serviceId, "LOG_SCOPE_ESCALATE", "LOGGING", 60, "", badClaims)
signal on syntax name badCapRejected
ignore = service~addRule(rule, bad)
raise syntax 88.900 array("mismatched scope claim was accepted")
badCapRejected:
signal off syntax

claims = .directory~new
claims["rule_id"] = rule~ruleId
claims["source_scope"] = .Log~CUSTOMER
claims["delivery_scope"] = .Log~INTERNAL
cap = authority~issueForSeconds("tester", service~serviceId, "LOG_SCOPE_ESCALATE", "LOGGING", 60, "", claims)
added = service~addRule(rule, cap)
call assertTrue added == rule, "authorised rule accepted"
call assertEq cap~capabilityId, rule~authorisationId, "rule records signed authorisation identity"

/* Same-scope logging does not require an escalation capability. */
normal = .LogRule~new("internal-normal", "web", "WebsiteUI", "normal", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~new)
ignore = service~addRule(normal)
call assertFalse normal~requiresEscalation, "same scope is not escalation"

say "PASS test_scope_authority"
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
