manager = .ObjectQueueManager~new
created = manager~createQueue("log.direct", .QueueLifecycle~TEMPORARY, "INTERNAL", 0, manager~adminPrincipal)
call assertTrue created~ok, "queue created"

target = .LogQueueDirectTarget~new("direct", .Log~INTERNAL, manager, "log.direct", manager~adminPrincipal)
service = .LogService~new("test-queue")
service~addTarget(target)
rule = .LogRule~new("queue-event", "demo", "QueueSubject", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~INFO, .nil, .array~of("direct"), .array~of(.Log~BODY))
service~addRule(rule)

subject = .QueueSubject~new
payload = .QueueRichPayload~new("customer-8")
log = service~loggerFor(subject, "work", .array~new, .Log~INTERNAL)
call assertTrue log~log(.Log~WARN, payload), "event delivered to queue target"

browse = manager~browse("log.direct", manager~adminPrincipal)
call assertTrue browse~ok, "queued event browsable"
package = browse~value
call assertTrue package~payload~isA(.LogEvent), "queue payload remains LogEvent object"
call assertTrue package~payload~payload == payload, "nested logging payload object identity retained"
call assertEq "queue-event", package~payload~ruleId, "rule identity retained through queue"

say "PASS test_queue_target"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class QueueSubject
::method work
  return .true
::class QueueRichPayload
::attribute customerId get
::method init
  expose customerId
  use strict arg customerId
  customerId = customerId

::requires "LoggingCore.cls"
::requires "ObjectQueueFabric.cls"
