service = .LogService~new("test-points")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
rule = .LogRule~new("point-window", "demo", "PointSubject", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, .nil, .array~of("memory"), .array~new, "AFTER_AUTH", "AFTER_REPLY")
service~addRule(rule)
subject = .PointSubject~new
log = service~loggerFor(subject, "work", .array~new, .Log~INTERNAL)
call assertTrue log~active, "rule active for method"

before = .PointPayload~new("before")
inside = .PointPayload~new("inside")
after = .PointPayload~new("after")
startMarker = .PointPayload~new("start")
stopMarker = .PointPayload~new("stop")

call assertFalse log~log(.Log~WARN, before), "before start point is suppressed"
call assertTrue log~point("AFTER_AUTH", startMarker, .Log~DEBUG), "start point opens rule window"
call assertTrue log~log(.Log~WARN, inside), "body event inside window emitted"
call assertTrue log~point("AFTER_REPLY", stopMarker, .Log~DEBUG), "stop marker itself emitted"
call assertFalse log~log(.Log~ERROR, after), "after stop point is suppressed"
call assertEq 3, mem~count, "only start/body/stop events stored"
call assertTrue mem~events[1]~payload == startMarker, "start marker object retained"
call assertTrue mem~events[2]~payload == inside, "inside payload object retained"
call assertTrue mem~events[3]~payload == stopMarker, "stop marker object retained"

say "PASS test_points"
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

::class PointSubject
::method work
  return .true
::class PointPayload
::attribute label get
::method init
  expose label
  use strict arg label
  label = label

::requires "../src/LoggingCore.cls"
