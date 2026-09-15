now = .DateTime~new
cut1 = now + .TimeSpan~new(0,0,10,0,0)
cut2 = cut1 + .TimeSpan~new(0,0,10,0,0)
start = now - .TimeSpan~new(0,0,10,0,0)

needle = "%';DROP"
condition1 = .LogConditionArgPathContains~new(1, .array~of("CUSTOMER", "CUSTOMERNAME"), needle, .false)
condition2 = .LogConditionArgNil~new(1)

spec1 = .LogRuleSpec~new("website-panel-policy", "website", "WebsiteUI", "generateCustomerPanel", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition1, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT, .Log~ERROR_POINT))
spec2 = .LogRuleSpec~new("website-panel-policy", "website", "WebsiteUI", "generateCustomerPanel", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition2, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT, .Log~ERROR_POINT))

p1 = .LogRuleSetPolicy~new("WEBSITE-LOGGING", "1.0", .array~of(spec1), start, cut1, "OPS", "SECURITY", "")~seal
p2 = .LogRuleSetPolicy~new("WEBSITE-LOGGING", "2.0", .array~of(spec2), cut1, cut2, "OPS", "SECURITY", "1.0")~seal
/* Empty policy is a legitimate reviewed decision to turn this policy family off. */
p3 = .LogRuleSetPolicy~new("WEBSITE-LOGGING", "3.0", .array~new, cut2, .nil, "OPS", "SECURITY", "2.0")~seal

catalog = .LogPolicyCatalog~new
call assertTrue catalog~publish(p1)~ok, "publish policy v1"
call assertTrue catalog~publish(p2)~ok, "publish policy v2"
call assertTrue catalog~publish(p3)~ok, "publish empty/off policy v3"
call assertEq p1~semanticIdentity, catalog~publicationRecord("WEBSITE-LOGGING", "1.0")~value~policyIdentity, "publication record binds exact v1 identity"

service = .LogService~new("policy-service")
service~enableMetrics
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
ui = .WebsiteUI~new
ignore = service~registerMethod(ui, "generateCustomerPanel", .Log~INTERNAL)
binding = .LogPolicyBinding~new(service, catalog, "WEBSITE-LOGGING")

resolved1 = binding~activate(now)
call assertTrue resolved1~ok, "activate v1"
call assertEq "1.0", binding~activeVersion, "v1 active"
call assertEq 1, service~metrics["instrumented_methods"], "v1 instruments selected method"
call assertFalse binding~needsRefresh(now), "v1 binding current at now"
call assertTrue binding~needsRefresh(cut1), "binding reports effective-dated refresh at v2 boundary"
call assertEq cut1, binding~nextTransition, "binding exposes next policy boundary without hot-path checks"

ordinary = .Session~new(.Customer~new("ordinary"))
attack = .Session~new(.Customer~new("Acme %';DROP TABLE customer;--"))
ignore = ui~generateCustomerPanel(ordinary)
call assertEq 0, mem~count, "v1 benign call not logged"
ignore = ui~generateCustomerPanel(attack)
call assertEq 2, mem~count, "v1 suspicious path logged"
e = mem~events[1]
call assertEq "WEBSITE-LOGGING", e~policyId, "event carries policy id"
call assertEq "1.0", e~policyVersion, "event carries policy version"
call assertEq p1~semanticIdentity, e~policyIdentity, "event carries exact policy identity"
call assertEq p1~semanticIdentity, e~metadata["policy_identity"], "policy identity query projection"

mem~clear
service~resetMetrics
resolved2 = binding~activate(cut1)
call assertTrue resolved2~ok, "activate v2 at exact handover"
call assertEq "2.0", binding~activeVersion, "v2 owns exact boundary"
ignore = ui~generateCustomerPanel(attack)
call assertEq 0, mem~count, "v2 no longer logs old suspicious-name criterion"
ignore = ui~generateCustomerPanel(.nil)
call assertEq 2, mem~count, "v2 logs nil criterion"
e2 = mem~events[1]
call assertEq "2.0", e2~policyVersion, "new events carry v2"
call assertEq p2~semanticIdentity, e2~policyIdentity, "new events carry exact v2 identity"

mem~clear
service~resetMetrics
resolved3 = binding~activate(cut2)
call assertTrue resolved3~ok, "activate empty v3"
call assertEq "3.0", binding~activeVersion, "empty policy version active"
call assertEq 0, service~metrics["instrumented_methods"], "empty policy physically removes instrumentation"
ignore = ui~generateCustomerPanel(.nil)
m = service~metrics
call assertEq 0, m["plan_evaluations"], "empty policy pays no logging plan cost"
call assertEq 0, mem~count, "empty policy emits nothing"

say "LOG_POLICY_HANDOVER v1=NAME_MATCH v2=NIL_ONLY v3=OFF provenance=PASS"
say "LOG_POLICY_OFF plan_evaluations="m["plan_evaluations"] "instrumented_methods="service~metrics["instrumented_methods"]
say "PASS test_policy_catalog"
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

::class Customer
::attribute customerName get
::method init
  expose customerName
  use strict arg customerName
  customerName = customerName

::class Session
::attribute customer get
::method init
  expose customer
  use strict arg customer
  customer = customer

::class WebsiteUI inherit LogInstrumentationParticipant
::method generateCustomerPanel unguarded
  use arg session
  if session == .nil then return "anonymous"
  return "panel:" || session~customer~customerName

::requires "LoggingPolicy.cls"
