/* Runtime diagnostic counters must not themselves become mandatory hot-path
 * instrumentation.  They are off by default and compiled into plans only when
 * explicitly enabled. */
service = .LogService~new("metrics-opt-in")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
condition = .MetricsFalseCondition~new
rule = .LogRule~new("false-rule", "metrics", "MetricsSubject", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, condition, .array~of("memory"))
service~addRule(rule)
subject = .MetricsSubject~new

call assertFalse service~metrics["metrics_enabled"], "metrics off by default"
do i = 1 to 1000
  log = service~loggerFor(subject, "work", .array~of(i), .Log~INTERNAL)
  call assertFalse log~active, "false condition returns null logger"
end
m = service~metrics
call assertEq 1000, condition~count, "rule predicate still evaluated because rule is armed"
call assertEq 0, m["plan_evaluations"], "disabled diagnostics add no plan counter traffic"
call assertEq 0, m["rule_evaluations"], "disabled diagnostics add no rule counter traffic"

service~enableMetrics
service~resetMetrics
do i = 1 to 10
  log = service~loggerFor(subject, "work", .array~of(i), .Log~INTERNAL)
end
m = service~metrics
call assertTrue m["metrics_enabled"], "metrics explicitly enabled"
call assertEq 10, m["plan_evaluations"], "enabled diagnostics count plans"
call assertEq 10, m["rule_evaluations"], "enabled diagnostics count exact predicates"

service~disableMetrics
service~resetMetrics
do i = 1 to 10
  log = service~loggerFor(subject, "work", .array~of(i), .Log~INTERNAL)
end
m = service~metrics
call assertFalse m["metrics_enabled"], "metrics disabled again"
call assertEq 0, m["plan_evaluations"], "disable recompiles away plan counters"
call assertEq 0, m["rule_evaluations"], "disable recompiles away rule counters"

say "METRICS_OPT_IN default=OFF compiled_out_when_off=PASS"
say "PASS test_metrics_opt_in"
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

::class MetricsFalseCondition
::attribute count get
::method init
  expose count
  count = 0
::method matches public unguarded
  expose count
  use strict arg receiver, arguments
  count = count + 1
  return .false

::class MetricsSubject
::method work unguarded
  use strict arg value
  return value

::requires "../src/LoggingCore.cls"
