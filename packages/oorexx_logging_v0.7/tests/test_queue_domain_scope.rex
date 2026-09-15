scope = .Log~customerScope("CUSTOMER-ALPHA")
manager = .ObjectQueueManager~new
created = manager~createQueue("log.customer", .QueueLifecycle~TEMPORARY, "CUSTOMER-ALPHA", 0, manager~adminPrincipal)
call assertTrue created~ok, "domain queue created"

target = .LogQueueDirectTarget~new("customer-direct", scope, manager, "log.customer", manager~adminPrincipal)
service = .LogService~new("queue-domain-test")
service~addTarget(target)
rule = .LogRule~new("customer-domain-event", "web", "DomainQueueSubject", "work", -
  scope, scope, .Log~INFO, .nil, .array~of("customer-direct"), .array~of(.Log~BODY))
service~addRule(rule)

subject = .DomainQueueSubject~new
log = service~loggerFor(subject, "work", .array~new, scope)
call assertTrue log~log(.Log~WARN, .array~of("domain", 42)), "domain event accepted"
browse = manager~browse("log.customer", manager~adminPrincipal)
call assertTrue browse~ok, "domain event browsable"
package = browse~value
call assertEq "CUSTOMER-ALPHA", package~securityDomain, "queue package carries queue security domain"
call assertEq "CUSTOMER-ALPHA", package~payload~deliveryDomainId, "event carries same domain"
call assertTrue package~payload~deliveryScopeObject~equivalent(scope), "structured delivery scope retained"

/* A target that claims CUSTOMER-ALPHA but points at CUSTOMER-BETA must fail
 * closed at delivery; Queue Fabric independently enforces the same boundary. */
manager2 = .ObjectQueueManager~new
created2 = manager2~createQueue("log.wrong", .QueueLifecycle~TEMPORARY, "CUSTOMER-BETA", 0, manager2~adminPrincipal)
call assertTrue created2~ok, "wrong-domain queue created"
wrongTarget = .LogQueueDirectTarget~new("wrong", scope, manager2, "log.wrong", manager2~adminPrincipal)
service2 = .LogService~new("queue-domain-wrong")
service2~addTarget(wrongTarget)
service2~addRule(.LogRule~new("wrong-domain", "web", "DomainQueueSubject", "work", -
  scope, scope, .Log~INFO, .nil, .array~of("wrong"), .array~of(.Log~BODY)))
log2 = service2~loggerFor(subject, "work", .array~new, scope)
call assertFalse log2~log(.Log~WARN, "must-not-cross"), "mismatched queue security domain rejects delivery"
call assertEq 0, manager2~depth("log.wrong", manager2~adminPrincipal)~value["ready"], "wrong domain queue remains empty"

say "QUEUE_DOMAIN_SCOPE aligned=PASS mismatched=DENIED"
say "PASS test_queue_domain_scope"
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

::class DomainQueueSubject
::method work
  return .true

::requires "LoggingCore.cls"
::requires "ObjectQueueFabric.cls"
