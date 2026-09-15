/* Logging may be layered over a pre-existing Alchemy telemetry wrapper.
 * When logging releases its final provider, that exact object-specific layer
 * is restored rather than falling through to the class method. */
obj = .AlchemyLoggedWidget~new

ar = obj~instrumentMethod("WORK")
call assertTrue ar~ok, "Alchemy telemetry installed first"
call assertEq "TELEMETRY_INSTALLED", ar~code, "Alchemy telemetry install code"
call assertEq "worked:before", obj~work("before"), "Alchemy wrapper works before logging"
call assertEq 1, obj~methodTelemetry["WORK"]["calls"], "Alchemy saw pre-logging call"

service = .LogService~new("logging-over-alchemy")
mem = .LogMemoryTarget~new("memory", .Log~INTERNAL)
service~addTarget(mem)
service~registerMethod(obj, "work", .Log~INTERNAL)
rule = .LogRule~new("log-over-alchemy", "interop", "AlchemyLoggedWidget", "work", -
  .Log~INTERNAL, .Log~INTERNAL, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT))
service~addRule(rule)

status = obj~methodInterpositionStatus("work")
call assertEq 1, status["physical_wrappers"], "logging coordinator installed one wrapper"
call assertTrue status["methods"][1]["had_object_method"], "pre-existing Alchemy object method captured"
call assertEq "worked:during", obj~work("during"), "logging over Alchemy preserves result"
call assertEq 2, obj~methodTelemetry["WORK"]["calls"], "Alchemy telemetry still runs under logging"
call assertEq 2, mem~count, "logging emits entry/exit"

service~disableRule("log-over-alchemy")
status = obj~methodInterpositionStatus("work")
call assertEq 0, status["physical_wrappers"], "logging releases its wrapper"
before = mem~count
call assertEq "worked:after", obj~work("after"), "restored Alchemy wrapper still works"
call assertEq 3, obj~methodTelemetry["WORK"]["calls"], "Alchemy telemetry survives logging removal"
call assertEq before, mem~count, "logging is inactive after release"

ar = obj~uninstrumentMethod("WORK")
call assertTrue ar~ok, "Alchemy can subsequently remove its own wrapper"
call assertEq "worked:plain", obj~work("plain"), "class method remains after both layers removed"
call assertEq 3, obj~methodTelemetry["WORK"]["calls"], "plain call no longer reaches Alchemy telemetry"

say "ALCHEMY_PREEXISTING telemetry_preserved=PASS logging_release_restores_object_method=PASS"
say "PASS test_alchemy_preexisting_telemetry"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed:" message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed:" message "expected="expected "actual="actual)
  return

::class AlchemyLoggedWidget subclass AlchemyObject inherit LogInstrumentationParticipant
::method init
  forward class (super) array (.nil, .nil, .nil) continue
  self~registerMethodContract("WORK", "work value", .array~of("VALUE"), "STRING", .false)

::method work unguarded
  use strict arg value
  return "worked:" || value

::requires "AlchemyObject.cls"
::requires "../src/LoggingCore.cls"
