service = .LogService~new("target-switch")
target = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(target)

subject = .TargetSwitchSubject~new
service~registerMethod(subject, "work", .Log~INTERNAL)
rule = .LogRule~new("target-rule", "demo", "TargetSwitchSubject", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, .nil, .array~of("memory"), .array~of(.Log~ENTRY, .Log~EXIT))
service~addRule(rule)
call assertEq 1, service~metrics["instrumented_methods"], "rule plus enabled target instruments method"

service~resetMetrics
service~disableTarget("memory")
call assertEq 0, service~metrics["instrumented_methods"], "disabling only target restores original method"
do i = 1 to 1000
  ignore = subject~work(i)
end
m = service~metrics
call assertEq 0, m["plan_evaluations"], "target-off calls never enter logging plan"
call assertEq 0, m["events_created"], "target-off calls create no events"
call assertEq 0, target~count, "disabled target receives no events"
say "TARGET_DISABLED calls=1000 plan_evaluations="m["plan_evaluations"] "events="m["events_created"] "instrumented_methods="service~metrics["instrumented_methods"]

service~enableTarget("memory")
call assertEq 1, service~metrics["instrumented_methods"], "re-enabling target reinstalls method logging"
ignore = subject~work(1)
call assertEq 2, target~count, "entry and exit delivered after target re-enabled"

say "PASS test_target_switch"
exit 0

assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class TargetSwitchSubject inherit LogInstrumentationParticipant
::method work
  use strict arg value
  return value + 1

::requires "LoggingCore.cls"
