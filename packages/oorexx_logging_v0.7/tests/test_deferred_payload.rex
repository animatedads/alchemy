probe = .PayloadProbe~new
null = .LogNullLogger~instance

do i = 1 to 1000
  ignore = null~logFrom(.Log~WARN, probe, "BUILD", .array~of(i))
end
call assertEq 0, probe~count, "null logger never invokes deferred producer"

service = .LogService~new("deferred")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
subject = .DeferredSubject~new
rule = .LogRule~new("deferred-error", "deferred", "DeferredSubject", "op", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~ERROR, .LogConditionAlways~new, .array~of("memory"), -
  .array~of(.Log~BODY))
service~addRule(rule)
logger = service~loggerFor(subject, "op", .array~new, .Log~INTERNAL)
call assertTrue logger~active, "matching method gets active logger"

ignore = logger~logFrom(.Log~WARN, probe, "BUILD", .array~of("warn"))
call assertEq 0, probe~count, "below-threshold event does not build payload"
call assertEq 0, mem~count, "below-threshold event emits nothing"

ignore = logger~logFrom(.Log~ERROR, probe, "BUILD", .array~of("error"))
call assertEq 1, probe~count, "enabled event builds payload once"
call assertEq 1, mem~count, "enabled event emits once"
call assertTrue mem~events[1]~payload~isA(.Directory), "deferred payload remains structured object"
call assertEq "error", mem~events[1]~payload["value"], "deferred payload content retained"

/* A logger already handed to application code must stop producing expensive
 * data immediately when its only delivery target is disabled. */
service~disableTarget("memory")
ignore = logger~logFrom(.Log~ERROR, probe, "BUILD", .array~of("disabled-target"))
call assertEq 1, probe~count, "disabled target suppresses producer invocation"
call assertEq 1, mem~count, "disabled target receives nothing"

say "DEFERRED_PAYLOAD null_calls=1000 producer_calls=0 threshold_suppressed=PASS target_suppressed=PASS"
say "PASS test_deferred_payload"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class PayloadProbe
::attribute count get
::method init
  expose count
  count = 0
::method build
  expose count
  use strict arg value
  count = count + 1
  d = .directory~new
  d["value"] = value
  d["build_sequence"] = count
  return d

::class DeferredSubject
::method op
  return .true

::requires "../src/LoggingCore.cls"
