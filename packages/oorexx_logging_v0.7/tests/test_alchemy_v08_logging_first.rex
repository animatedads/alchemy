obj = .InteropWidget~new
service = .LogService~new("logging-first-alchemy-v08")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
service~registerMethod(obj, "work", .Log~INTERNAL)
rule = .LogRule~new("logging-first", "interop", "InteropWidget", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT))
service~addRule(rule)

status = obj~methodInterpositionStatus("work")
call assertEq 1, status["physical_wrappers"], "Logging installs physical wrapper first"
r = obj~instrumentMethod("WORK")
call assertTrue r~ok, "Alchemy joins Logging coordinator"
call assertEq "TELEMETRY_COORDINATED", r~code, "Alchemy v0.8 recognizes active coordinator"
status = obj~methodInterpositionStatus("work")
call assertEq 1, status["physical_wrappers"], "one physical wrapper after Alchemy joins"
call assertEq 2, status["methods"][1]["provider_count"], "Logging plus Alchemy provider"

call assertEq "worked:one", obj~work("one"), "business result preserved"
call assertEq 1, obj~methodTelemetry["WORK"]["calls"], "Alchemy telemetry observed call"
call assertEq 2, mem~count, "Logging entry/exit observed call"

r = obj~uninstrumentMethod("WORK")
call assertTrue r~ok, "Alchemy withdraws independently"
call assertEq "TELEMETRY_COORDINATED_REMOVED", r~code, "coordinated removal code"
status = obj~methodInterpositionStatus("work")
call assertEq 1, status["physical_wrappers"], "Logging wrapper remains"
call assertEq 1, status["methods"][1]["provider_count"], "only Logging provider remains"
call assertEq "worked:two", obj~work("two"), "business remains under Logging"
call assertEq 1, obj~methodTelemetry["WORK"]["calls"], "Alchemy no longer observes call"
call assertEq 4, mem~count, "Logging remains active"

service~disableRule("logging-first")
status = obj~methodInterpositionStatus("work")
call assertEq 0, status["physical_wrappers"], "Logging final release restores original"
call assertEq "worked:plain", obj~work("plain"), "plain business method restored"

say "ALCHEMY_V08 logging_first=PASS shared_wrapper=1 independent_release=PASS"
say "PASS test_alchemy_v08_logging_first"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class InteropWidget subclass AlchemyObject inherit LogInstrumentationParticipant
::method init
  self~init:super(.nil, .nil, .nil)
  self~registerMethodContract("WORK", "logging first integration", .array~of("VALUE"), "STRING", .false)
::method work unguarded
  use strict arg value
  return "worked:" || value

::requires "AlchemyObject.cls"
::requires "LoggingCore.cls"
