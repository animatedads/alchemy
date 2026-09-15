now = .DateTime~new
finish = now + .TimeSpan~new(0,1,0,0,0)

cA = .LogConditionAny~new(.array~of(.LogConditionArgNil~new(1), .LogConditionArgOmitted~new(2)))
cB = .LogConditionAny~new(.array~of(.LogConditionArgOmitted~new(2), .LogConditionArgNil~new(1)))

s1a = .LogRuleSpec~new("r1", "web", "WebsiteUI", "a", .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, cA, .array~of("t2", "t1"), .array~of(.Log~EXIT, .Log~ENTRY))
s1b = .LogRuleSpec~new("r1", "web", "WebsiteUI", "a", .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, cB, .array~of("t1", "t2"), .array~of(.Log~ENTRY, .Log~EXIT))
s2 = .LogRuleSpec~new("r2", "web", "WebsiteUI", "b", .Log~INTERNAL, .Log~INTERNAL, .Log~WARN, .LogConditionAlways~new, .array~of("t1"))

pA = .LogRuleSetPolicy~new("IDENTITY-LOGGING", "1.0", .array~of(s1a, s2), now, finish, "OPS", "SECURITY")~seal
pB = .LogRuleSetPolicy~new("IDENTITY-LOGGING", "1.0", .array~of(s2, s1b), now, finish, "OPS", "SECURITY")~seal
call assertEq s1a~semanticIdentity, s1b~semanticIdentity, "condition/target/point ordering does not alter rule semantics"
call assertEq pA~semanticIdentity, pB~semanticIdentity, "rule insertion order does not alter policy identity"

bad = .LogRuleSpec~new("custom", "web", "WebsiteUI", "c", .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .OpaqueCondition~new, .array~of("t1"))
badPolicy = .LogRuleSetPolicy~new("IDENTITY-LOGGING-CUSTOM", "1.0", .array~of(bad), now, .nil, "OPS", "SECURITY")
signal on syntax name customRejected
ignore = badPolicy~seal
raise syntax 88.900 array("opaque custom condition was accepted without a stable semantic identity")
customRejected:
signal off syntax

identified = .LogRuleSpec~new("custom", "web", "WebsiteUI", "c", .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .OpaqueCondition~new, .array~of("t1"), .array~new, "", "", "CLASS", "opaque-condition-v1")
identifiedPolicy = .LogRuleSetPolicy~new("IDENTITY-LOGGING-CUSTOM", "1.0", .array~of(identified), now, .nil, "OPS", "SECURITY")~seal
call assertTrue identifiedPolicy~publicationEligible, "custom condition accepted with explicit stable identity"

mutableCondition = .LogConditionAny~new(.array~of(.LogConditionArgNil~new(1)))
mutableSpec = .LogRuleSpec~new("mutable", "web", "WebsiteUI", "d", .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, mutableCondition, .array~of("t1"))
mutablePolicy = .LogRuleSetPolicy~new("IDENTITY-LOGGING-MUTABLE", "1.0", .array~of(mutableSpec), now, .nil, "OPS", "SECURITY")~seal
ignore = mutableCondition~conditions~append(.LogConditionArgOmitted~new(2))
signal on syntax name mutationRejected
ignore = mutablePolicy~materializeRules
raise syntax 88.900 array("post-seal condition mutation was not detected")
mutationRejected:
signal off syntax

say "LOG_POLICY_IDENTITY insertion_order=CANONICAL custom_condition_identity=REQUIRED seal_integrity=PASS"
say "PASS test_policy_identity"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class OpaqueCondition public
::method matches public unguarded
  use strict arg receiver, arguments
  return .true

::requires "LoggingPolicy.cls"
