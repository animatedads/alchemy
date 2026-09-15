obj = .FailureWidget~new
s1 = .LogService~new("failure-A")
t1 = .LogMemoryTarget~new("memory-A", .Log~INTERNAL)
s1~addTarget(t1)
s1~registerMethod(obj, "explode", .Log~INTERNAL)
s1~addRule(.LogRule~new("failure-rule-A", "failure", "FailureWidget", "explode", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory-A"), -
  .array~of(.Log~ENTRY, .Log~ERROR_POINT)))

s2 = .LogService~new("failure-B")
t2 = .LogMemoryTarget~new("memory-B", .Log~INTERNAL)
s2~addTarget(t2)
s2~registerMethod(obj, "explode", .Log~INTERNAL)
s2~addRule(.LogRule~new("failure-rule-B", "failure", "FailureWidget", "explode", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory-B"), -
  .array~of(.Log~ENTRY, .Log~ERROR_POINT)))

signal on syntax name expectedFailure
dummy = obj~explode("boom")
raise syntax 88.900 array("instrumented failure did not propagate")
expectedFailure:
signal off syntax

call assertEq 2, t1~count, "service A receives entry/error"
call assertEq 2, t2~count, "service B receives entry/error"
call assertEq .Log~ENTRY, t1~events[1]~point, "A entry point"
call assertEq .Log~ERROR_POINT, t1~events[2]~point, "A error point"
call assertEq .Log~ENTRY, t2~events[1]~point, "B entry point"
call assertEq .Log~ERROR_POINT, t2~events[2]~point, "B error point"
call assertTrue t1~events[2]~payload~isA(.Directory), "condition directory retained as structured payload"

s1~disableRule("failure-rule-A")
s2~disableRule("failure-rule-B")
call assertEq 0, obj~methodInterpositionStatus("explode")["physical_wrappers"], "failure method restored after final release"

say "INTERPOSITION_FAILURE propagated=PASS providers=2 structured_condition=PASS"
say "PASS test_interposition_failure"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class FailureWidget inherit LogInstrumentationParticipant
::method explode unguarded
  use strict arg value
  raise syntax 88.900 array(value)

::requires "../src/LoggingCore.cls"
