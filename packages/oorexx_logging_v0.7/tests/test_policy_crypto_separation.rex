ring = .CryptoMacKeyRing~new
ring~addKey("logging-policy-domain-test", "00112233445566778899aabbccddeeff")
authority = .AlchemyCapabilityAuthority~new(ring)
service = .LogService~new("logging-policy-domain-service", authority)

scopeA = .Log~customerScope("CUSTOMER-A")
scopeB = .Log~customerScope("CUSTOMER-B")
mem = .LogMemoryTarget~new("memory-b", scopeB)
service~addTarget(mem)

spec = .LogRuleSpec~new("policy-a-to-b", "web", "WebsiteUI", "render", -
  scopeA, scopeB, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory-b"), -
  .array~of(.Log~ENTRY, .Log~EXIT))
now = .DateTime~new
policy = .LogRuleSetPolicy~new("CROSS-DOMAIN-LOGGING", "1.0", .array~of(spec), -
  now - .TimeSpan~new(0,0,1,0,0), .nil, "OPS", "SECURITY")~seal
catalog = .LogPolicyCatalog~new
call assertTrue catalog~publish(policy)~ok, "publish cross-domain policy"
binding = .LogPolicyBinding~new(service, catalog, "CROSS-DOMAIN-LOGGING")
ui = .WebsiteUI~new
ignore = service~registerMethod(ui, "render", scopeA)

signal on syntax name noCapRejected
ignore = binding~activate(now)
raise syntax 88.900 array("published policy improperly granted cross-domain authority")
noCapRejected:
signal off syntax
call assertEq "", binding~activeVersion, "failed activation does not publish binding state"
call assertEq 0, service~metrics["instrumented_methods"], "failed activation leaves method unwrapped"

weakClaims = .directory~new
weakClaims["rule_id"] = "policy-a-to-b"
weakClaims["source_scope"] = .Log~CUSTOMER
weakClaims["delivery_scope"] = .Log~CUSTOMER
weak = authority~issueForSeconds("tester", service~serviceId, "LOG_SCOPE_ESCALATE", "LOGGING", 60, "", weakClaims)
weakCaps = .table~new
weakCaps["POLICY-A-TO-B"] = weak
signal on syntax name weakRejected
ignore = binding~activate(now, weakCaps)
raise syntax 88.900 array("published policy accepted disclosure-only capability")
weakRejected:
signal off syntax
call assertEq "", binding~activeVersion, "weak capability does not activate policy"

claims = .directory~new
claims["rule_id"] = "policy-a-to-b"
claims["source_scope"] = .Log~CUSTOMER
claims["delivery_scope"] = .Log~CUSTOMER
claims["source_scope_id"] = scopeA~scopeId
claims["delivery_scope_id"] = scopeB~scopeId
cap = authority~issueForSeconds("tester", service~serviceId, "LOG_SCOPE_ESCALATE", "LOGGING", 60, "", claims)
caps = .table~new
caps["POLICY-A-TO-B"] = cap
resolved = binding~activate(now, caps)
call assertTrue resolved~ok, "exact crypto capability activates published policy"
call assertEq "1.0", binding~activeVersion, "policy activated after crypto verification"
call assertEq 1, service~metrics["instrumented_methods"], "verified rule instruments method"

ignore = ui~render("hello")
call assertEq 2, mem~count, "entry and exit delivered"
e = mem~events[1]
call assertEq cap~capabilityId, e~authorisationId, "event retains cryptographic authorisation identity"
call assertEq policy~semanticIdentity, e~policyIdentity, "event also retains institutional policy identity"
call assertEq "CUSTOMER:CUSTOMER-A", e~sourceScopeId, "source domain retained"
call assertEq "CUSTOMER:CUSTOMER-B", e~deliveryScopeId, "delivery domain retained"

say "POLICY_CRYPTO_SEPARATION publication=GOVERNANCE scope_transition=CRYPTO_BEARER exact_claims=PASS"
say "PASS test_policy_crypto_separation"
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
