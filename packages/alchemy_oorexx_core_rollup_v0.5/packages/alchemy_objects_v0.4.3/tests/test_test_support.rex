ring = .CryptoMacKeyRing~new
ring~addKey("test-run", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
run = .AlchemyTestRun~new("foundation-test-support", sealer, authority)
target = .TestTarget~new(sealer, authority)

call assertTrue run~assertTrue(.true, "true assertion"), "assertTrue return"
call assertTrue run~assertFalse(.false, "false assertion"), "assertFalse return"
call assertTrue run~assertEquals("x", "x", "equality assertion"), "assertEquals return"
call assertTrue run~assertSurface(target), "surface assertion"
call assertTrue run~assertResultContract(target, "PING", "pong"), "result contract assertion"
call assertFalse run~assertEquals(1, 2, "deliberate recorded failure"), "failed assertion returns false"
summary = run~complete
call assertEq 6, summary["assertions"], "assertion count"
call assertEq 1, summary["failures"], "failure count"
call assertFalse summary["passed"], "summary failed"

cap = authority~issue("test-auditor", run~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER")
ev = run~sealedIntrospection("CUSTOMER", cap)
call assertTrue sealer~verify(ev), "test run evidence verifies"
state = ev~payload["state"]
call assertEq "foundation-test-support", state["TESTNAME"], "test name in sealed state"
call assertEq 1, state["TESTFAILURES"], "failure count in sealed state"
call assertEq 6, state["TESTASSERTIONS"]~items, "assertions in sealed state"

say "PASS test_test_support"
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

::class TestTarget subclass AlchemyObject
::method init
  use strict arg sealer, authority
  self~initAlchemy(.nil, sealer, authority)
  self~registerMethodContract("PING", "test target ping", .array~new, "STRING", .false)
::method ping
  return "pong"

::requires "AlchemyObjects.cls"
