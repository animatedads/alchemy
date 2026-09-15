customer = .ScopeCustomer~new("Customer Alpha")
scopeA = .Log~customerScope("CUSTOMER-ALPHA", customer)
scopeB = .Log~customerScope("CUSTOMER-BETA")

call assertEq .Log~CUSTOMER, scopeA~disclosure, "customer disclosure"
call assertEq "CUSTOMER-ALPHA", scopeA~domainId, "customer domain id"
call assertEq "CUSTOMER:CUSTOMER-ALPHA", scopeA~scopeId, "canonical scope id"
call assertTrue scopeA~subject == customer, "live scope retains customer object"
call assertFalse scopeA~equivalent(scopeB), "same disclosure different domain is distinct scope"

service = .LogService~new("scope-object-test")
service~enableMetrics
mem = .LogMemoryTarget~new("memory", scopeA)
service~addTarget(mem)
rule = .LogRule~new("customer-a-work", "web", "ScopedWorker", "work", -
  scopeA, scopeA, .Log~INFO, .LogConditionAlways~new, .array~of("memory"), .array~of(.Log~BODY))
service~addRule(rule)

worker = .ScopedWorker~new
service~resetMetrics
log = service~loggerFor(worker, "work", .array~of("alpha"), scopeA)
call assertTrue log~active, "exact customer scope activates logger"
call assertTrue log~log(.Log~WARN, .array~of("structured", customer)), "domain event delivered"
call assertEq 1, mem~count, "one event captured"
event = mem~events[1]
call assertTrue event~sourceScopeObject == scopeA, "source scope object identity retained live"
call assertTrue event~deliveryScopeObject == scopeA, "delivery scope object identity retained live"
call assertTrue event~sourceScopeObject~subject == customer, "customer object retained through live event"
call assertEq "CUSTOMER-ALPHA", event~sourceDomainId, "source domain projected"
call assertEq "CUSTOMER-ALPHA", event~deliveryDomainId, "delivery domain projected"
call assertTrue event~payload~isA(.Array), "payload remains structured object"
call assertTrue event~payload[2] == customer, "nested customer payload identity retained"

service~resetMetrics
otherLog = service~loggerFor(worker, "work", .array~of("beta"), scopeB)
call assertFalse otherLog~active, "different customer domain has no matching plan"
m = service~metrics
call assertEq 0, m["plan_evaluations"], "different domain does not enter customer A plan"
call assertEq 0, m["rule_evaluations"], "different domain scans no customer A rule"

say "SCOPE_OBJECT live_subject=PASS exact_domain_plan=PASS structured_payload=PASS"
say "PASS test_scope_objects"
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

::class ScopeCustomer
::attribute customerName get
::method init
  expose customerName
  use strict arg customerName
  customerName = customerName

::class ScopedWorker
::method work
  use strict arg value
  return value

::requires "../src/LoggingCore.cls"
