keyRing = .CryptoMacKeyRing~new
keyRing~addKey("telemetry-test", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(keyRing)
authority = .AlchemyCapabilityAuthority~new(keyRing)
obj = .TelemetrySubject~new(sealer, authority)

r = obj~instrumentMethod("ADD", .true)
call assertTrue r~ok, "ADD instrumented"
call assertEq "TELEMETRY_INSTALLED", r~code, "install code"
call assertEq 7, obj~add(3, 4), "wrapped ADD result"
call assertEq 11, obj~add(5, 6), "wrapped ADD result second"

m = obj~methodTelemetry
call assertTrue m~hasIndex("ADD"), "ADD telemetry present"
row = m["ADD"]
call assertEq 2, row["calls"], "ADD calls"
call assertEq 2, row["successes"], "ADD successes"
call assertEq 0, row["failures"], "ADD failures"
call assertEq "RESULT_OK", row["last_result_contract"], "ADD result contract"
call assertTrue row["total_seconds"] >= 0, "ADD elapsed time"

alias = r~evidence["alias"]
signal on syntax name aliasBlocked
dummy = obj~send(alias, 1, 2)
raise syntax 88.900 array("private telemetry alias was externally callable")
aliasBlocked:
signal off syntax

r = obj~instrumentMethod("BUMP")
call assertTrue r~ok, "stateful BUMP instrumented"
call assertEq 13, obj~bump(3), "wrapped method preserves subclass object-variable scope"
call assertEq 13, obj~currentState, "subclass EXPOSE state updated through telemetry alias"

r = obj~instrumentMethod("LOCKED")
call assertFalse r~ok, "protected method not wrapped"
call assertEq "TELEMETRY_PROTECTED_SKIPPED", r~code, "protected skip code"

r = obj~instrumentMethod("PACKAGEONLY")
call assertFalse r~ok, "package method not wrapped"
call assertEq "TELEMETRY_PACKAGE_SKIPPED", r~code, "package skip code"

r = obj~instrumentMethod("BADRESULT", .true)
call assertTrue r~ok, "BADRESULT instrumented"
signal on syntax name badContract
v = obj~badResult
raise syntax 88.900 array("bad result contract was not enforced")
badContract:
signal off syntax
m = obj~methodTelemetry
row = m["BADRESULT"]
call assertEq 1, row["calls"], "BADRESULT call count"
call assertEq 0, row["successes"], "BADRESULT success count"
call assertEq 1, row["failures"], "BADRESULT failure count"
call assertEq 1, row["contract_failures"], "BADRESULT contract failure count"
call assertEq "RESULT_MISMATCH", row["last_result_contract"], "BADRESULT mismatch recorded"

r = obj~uninstrumentMethod("ADD")
call assertTrue r~ok, "ADD uninstrumented"
call assertEq 15, obj~add(7, 8), "original ADD restored"

say "PASS test_method_telemetry"
exit 0

assertTrue: procedure
  use strict arg actual, message
  if actual \= .true then raise syntax 88.900 array("assertTrue failed: " || message)
  return
assertFalse: procedure
  use strict arg actual, message
  if actual \= .false then raise syntax 88.900 array("assertFalse failed: " || message)
  return
assertEq: procedure
  use strict arg expected, actual, message
  if expected \== actual then raise syntax 88.900 array("assertEq failed: " || message || " expected=" || expected || " actual=" || actual)
  return

::class TelemetrySubject subclass AlchemyObject
::method init
  expose stateValue
  use strict arg sealer, authority
  stateValue = 10
  forward class (super) array (.nil, sealer, authority) continue
  self~registerMethodContract("ADD", "add two values", .array~of("A", "B"), "NUMERIC", .false)
  self~registerMethodContract("BUMP", "mutate subclass object-variable state", .array~of("N"), "NUMERIC", .false)
  self~registerMethodContract("BADRESULT", "deliberate contract violation", .array~new, "NUMERIC", .false)

::method add unguarded
  use strict arg a, b
  return a + b

::method bump
  expose stateValue
  use strict arg n
  stateValue = stateValue + n
  return stateValue

::method currentState
  expose stateValue
  return stateValue

::method badResult
  return "not numeric"

::method locked protected
  return 1

::method packageOnly package
  return 1

::requires "AlchemyObjects.cls"
