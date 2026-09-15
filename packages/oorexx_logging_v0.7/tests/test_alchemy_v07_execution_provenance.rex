ring = .CryptoMacKeyRing~new
ring~addKey("logging-alchemy-v07", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
obj = .AlchemyV07LoggedWidget~new(sealer, authority)

ar = obj~instrumentMethod("WORK", .true)
call assertTrue ar~ok, "Alchemy v0.7 execution instrumentation installed first"

service = .LogService~new("logging-over-alchemy-v07")
mem = .LogMemoryTarget~new("memory", .Log~PUBLIC)
service~addTarget(mem)
service~registerMethod(obj, "work", .Log~PUBLIC)
rule = .LogRule~new("log-over-alchemy-v07", "interop", "AlchemyV07LoggedWidget", "work", -
  .Log~PUBLIC, .Log~PUBLIC, .Log~DEBUG, .LogConditionAlways~new, .array~of("memory"), -
  .array~of(.Log~ENTRY, .Log~EXIT))
service~addRule(rule)

call assertEq "worked:during", obj~work("during"), "logging over Alchemy v0.7 preserves result"
call assertEq 2, mem~count, "logging emits entry and exit"
sealed = obj~sealPublicIntrospection
call assertTrue sealer~verify(sealed), "Alchemy public introspection seal verifies"
exec = sealed~payload["execution_provenance"]
call assertEq "alchemy.objects.execution-provenance/0.1", exec["schema"], "new Alchemy execution provenance present"
call assertEq 1, exec["visible_total"], "logged call remains one Alchemy execution record"
record = exec["records"][1]
call assertEq "WORK", record["method"], "Alchemy execution method identity preserved"
call assertEq "SUCCESS", record["outcome"], "Alchemy execution outcome preserved"
call assertEq 1, record["argument_count"], "Alchemy bounded argument evidence preserved"
call assertFalse record~hasIndex("arguments"), "logging does not cause Alchemy to copy argument values"

service~disableRule("log-over-alchemy-v07")
call assertEq "worked:after", obj~work("after"), "Alchemy wrapper remains after logging release"
sealed2 = obj~sealPublicIntrospection
exec2 = sealed2~payload["execution_provenance"]
call assertEq 2, exec2["visible_total"], "Alchemy execution provenance continues after logging release"

say "ALCHEMY_V07 coexistence=PASS execution_provenance=PASS bounded_values=PASS"
say "PASS test_alchemy_v07_execution_provenance"
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

::class AlchemyV07LoggedWidget subclass AlchemyObject inherit LogInstrumentationParticipant
::method init
  use strict arg sealer, authority
  forward class (super) array (.nil, sealer, authority) continue
  self~registerMethodContract("WORK", "work value", .array~of("VALUE"), "STRING", .false, "TRUE", "PUBLIC", "NORMAL", "READ", "NONE")

::method work unguarded
  use strict arg value
  return "worked:" || value

::requires "AlchemyObject.cls"
::requires "../src/LoggingCore.cls"
