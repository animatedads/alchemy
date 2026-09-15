ring = .CryptoMacKeyRing~new
ring~addKey("logging-policy-atomic-test", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(ring)
service = .LogService~new("logging-policy-atomic-service", authority)
service~enableMetrics

scopeA = .Log~customerScope("CUSTOMER-A")
scopeB = .Log~customerScope("CUSTOMER-B")
memA = .LogMemoryTarget~new("memory-a", scopeA)
memB = .LogMemoryTarget~new("memory-b", scopeB)
service~addTarget(memA)
service~addTarget(memB)

now = .DateTime~new
cut = now + .TimeSpan~new(0,0,10,0,0)
start = now - .TimeSpan~new(0,0,10,0,0)

spec1 = .LogRuleSpec~new("atomic-rule", "web", "WebsiteUI", "render", -
  scopeA, scopeA, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory-a"), -
  .array~of(.Log~ENTRY, .Log~EXIT))
spec2 = .LogRuleSpec~new("atomic-rule", "web", "WebsiteUI", "render", -
  scopeA, scopeB, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory-b"), -
  .array~of(.Log~ENTRY, .Log~EXIT))

p1 = .LogRuleSetPolicy~new("ATOMIC-LOGGING", "1.0", .array~of(spec1), start, cut, "OPS", "SECURITY")~seal
p2 = .LogRuleSetPolicy~new("ATOMIC-LOGGING", "2.0", .array~of(spec2), cut, .nil, "OPS", "SECURITY", "1.0")~seal
catalog = .LogPolicyCatalog~new
call assertTrue catalog~publish(p1)~ok, "publish v1"
call assertTrue catalog~publish(p2)~ok, "publish v2"

ui = .WebsiteUI~new
ignore = service~registerMethod(ui, "render", scopeA)
binding = .LogPolicyBinding~new(service, catalog, "ATOMIC-LOGGING")
call assertTrue binding~activate(now)~ok, "activate v1"
call assertEq "1.0", binding~activeVersion, "v1 active"
ignore = ui~render("before")
call assertEq 2, memA~count, "v1 delivers before failed handover"
call assertEq 0, memB~count, "v2 target untouched before handover"

signal on syntax name rejected
ignore = binding~activate(cut)
raise syntax 88.900 array("cross-domain v2 activated without capability")
rejected:
signal off syntax

call assertEq "1.0", binding~activeVersion, "failed v2 handover retains v1 binding identity"
call assertEq p1~semanticIdentity, binding~activePolicyIdentity, "failed v2 handover retains exact v1 policy"
call assertEq 1, service~metrics["instrumented_methods"], "failed v2 handover leaves existing wrapper live"
ignore = ui~render("after-failed-handover")
call assertEq 4, memA~count, "v1 remains executable after failed replacement"
call assertEq 0, memB~count, "failed replacement emits nothing to v2 target"

claims = .directory~new
claims["rule_id"] = "atomic-rule"
claims["source_scope"] = .Log~CUSTOMER
claims["delivery_scope"] = .Log~CUSTOMER
claims["source_scope_id"] = scopeA~scopeId
claims["delivery_scope_id"] = scopeB~scopeId
cap = authority~issueForSeconds("tester", service~serviceId, "LOG_SCOPE_ESCALATE", "LOGGING", 60, "", claims)
caps = .table~new
caps["ATOMIC-RULE"] = cap
call assertTrue binding~activate(cut, caps)~ok, "authorized v2 handover"
call assertEq "2.0", binding~activeVersion, "v2 active after authorization"
ignore = ui~render("after-authorized-handover")
call assertEq 4, memA~count, "v1 target no longer receives after successful handover"
call assertEq 2, memB~count, "v2 target receives after successful handover"

say "LOG_POLICY_ATOMIC failed_handover=RETAINED_PRIOR_POLICY authorized_handover=PASS"
say "PASS test_policy_activation_atomic"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class WebsiteUI inherit LogInstrumentationParticipant
::method render unguarded
  use strict arg text
  return "rendered:" || text

::requires "LoggingPolicy.cls"
::requires "AlchemySecurity.cls"
