service = .LogService~new("controls")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
rule = .LogRule~new("control-rule", "demo", "ControlSubject", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~WARN, .nil, .array~of("memory"), .array~of(.Log~BODY))
service~addRule(rule)
subject = .ControlSubject~new
log = service~loggerFor(subject, "work", .array~new, .Log~INTERNAL)

call assertFalse log~log(.Log~INFO, "below threshold"), "INFO suppressed by WARN rule"
call assertEq 0, mem~count, "below-threshold event not created/delivered"
call assertTrue log~log(.Log~WARN, "warning"), "WARN admitted"
call assertEq 1, mem~count, "WARN delivered"

service~resetMetrics
service~disableTarget("memory")
call assertFalse log~log(.Log~ERROR, "target off"), "held logger cannot emit through disabled target"
call assertEq 0, service~metrics["events_created"], "disabled target prevents event construction even for held active logger"
call assertEq 1, mem~count, "disabled target receives nothing"

service~enableTarget("memory")
service~disableRule("control-rule")
service~resetMetrics
call assertFalse log~log(.Log~ERROR, "rule off"), "held logger observes rule disable immediately"
call assertEq 0, service~metrics["events_created"], "disabled rule prevents event construction"

service~enableRule("control-rule")
log2 = service~loggerFor(subject, "work", .array~new, .Log~INTERNAL)
service~disable
service~resetMetrics
call assertFalse log2~log(.Log~ERROR, "service off"), "service switch stops held active logger"
call assertEq 0, service~metrics["events_created"], "service off prevents event construction"

say "PASS test_controls"
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

::class ControlSubject
::method work
  return .true

::requires "LoggingCore.cls"
