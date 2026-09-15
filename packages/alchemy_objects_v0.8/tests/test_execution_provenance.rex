ring = .CryptoMacKeyRing~new
ring~addKey("execution-test", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
obj = .ExecutionSubject~new(sealer, authority)

r = obj~instrumentMethod("CALCULATE", .true)
call assertTrue r~ok, "CALCULATE instrumented"
call assertEq "EXECUTIONSUBJECT", r~evidence["implementation_origin"]["class"], "implementation origin class"
call assertEq "EFFECTIVE_METHOD_IDENTITY_MATCH", r~evidence["implementation_origin"]["resolution"], "implementation origin uses effective method identity"
call assertEq 8, obj~calculate(4), "first execution result"

/* Mutate the descriptive contract after the first invocation.  The second
 * execution must bind to the new contract revision rather than rewriting
 * history for the first call. */
obj~describeMethodPolicy("CALCULATE", "TRUE", "PUBLIC", "NORMAL", "READ", "NONE")
call assertEq 10, obj~calculate(5), "second execution result"

bad = obj~instrumentMethod("BADRESULT", .true)
call assertTrue bad~ok, "BADRESULT instrumented"
signal on syntax name contractFailure
ignore = obj~badResult
raise syntax 88.900 array("bad result contract unexpectedly passed")
contractFailure:
signal off syntax

boom = obj~instrumentMethod("EXPLODE", .false)
call assertTrue boom~ok, "EXPLODE instrumented"
signal on syntax name exploded
ignore = obj~explode
raise syntax 88.900 array("EXPLODE unexpectedly returned")
exploded:
signal off syntax

public = obj~sealPublicIntrospection
call assertTrue sealer~verify(public), "public execution evidence seal verifies"
exec = public~payload["execution_provenance"]
call assertEq "alchemy.objects.execution-provenance/0.1", exec["schema"], "execution evidence schema"
call assertEq 4, exec["sequence"], "execution sequence"
call assertEq 4, exec["visible_total"], "public methods produce four visible records"
call assertEq 0, exec["dropped_total"], "no records dropped"

records = exec["records"]
first = records[1]
second = records[2]
third = records[3]
fourth = records[4]
call assertEq "CALCULATE", first["method"], "first method"
call assertEq "SUCCESS", first["outcome"], "first outcome"
call assertTrue first["completed"], "first completed"
call assertEq 2, first["contract_revision"], "first contract revision"
call assertEq "RESULT_OK", first["result_contract_code"], "first result contract"
call assertEq "EXECUTIONSUBJECT", first["implementation_origin"]["class"], "first origin"
call assertEq "EFFECTIVE_METHOD_IDENTITY_MATCH", first["implementation_origin"]["resolution"], "first origin resolution"
call assertEq "ALCHEMY-CANONICAL-REDACTED-0.1", first["contract_fingerprint_algorithm"], "redacted contract fingerprint algorithm"
call assertEq 0, first["contract_fingerprint"]~pos("TOP-SECRET-DESCRIPTION"), "secret contract description is absent from public execution token"
call assertEq 1, first["argument_count"], "argument count only"
call assertFalse first~hasIndex("arguments"), "argument values are not copied"
call assertFalse first~hasIndex("started_timer"), "internal timer is not disclosed"
call assertTrue first["integrity_ok_at_entry"], "integrity clean at entry"
call assertTrue first["security_runtime_observed"], "runtime semantics observed"

call assertEq "CALCULATE", second["method"], "second method"
call assertEq 3, second["contract_revision"], "second contract revision"
call assertTrue first["contract_fingerprint"] \= second["contract_fingerprint"], "contract fingerprint changes with revision"

call assertEq "BADRESULT", third["method"], "third method"
call assertEq "CONTRACT_FAIL", third["outcome"], "contract failure outcome"
call assertFalse third["result_contract_ok"], "contract failure recorded"
call assertEq "RESULT_MISMATCH", third["result_contract_code"], "contract mismatch code"

call assertEq "EXPLODE", fourth["method"], "fourth method"
call assertEq "FAILURE", fourth["outcome"], "exception outcome"
call assertTrue fourth~hasIndex("failure_condition"), "failure condition recorded"

/* Bounded history must fail by dropping evidence, never by growing without
 * limit.  The setter is protected but directly callable from this trusted
 * package because no package Security Manager is attached here. */
obj~setExecutionEvidencePolicy(1)
call assertEq 12, obj~calculate(6), "fifth execution after limit change"
public2 = obj~sealPublicIntrospection
exec2 = public2~payload["execution_provenance"]
call assertEq 5, exec2["sequence"], "sequence remains monotonic"
call assertEq 1, exec2["retained_total"], "bounded history retains one newest completed record"
call assertEq 4, exec2["dropped_total"], "four older records were explicitly evicted and counted"
call assertEq 5, exec2["records"][1]["sequence"], "newest execution remains after bounded eviction"

say "PASS test_execution_provenance"
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

::class ExecutionSubject subclass AlchemyObject
::method init
  use strict arg sealer, authority
  forward class (super) array (.nil, sealer, authority) continue
  self~registerMethodContract("CALCULATE", "double a number", .array~of("N"), "NUMERIC", .false, "TRUE", "PUBLIC", "NORMAL", "READ", "NONE")
  self~describeMethodData("CALCULATE", "INPUT", "hidden-internal-name", "NUMERIC", .true, "TOP-SECRET-DESCRIPTION", "SECRET")
  self~registerMethodContract("BADRESULT", "deliberate contract violation", .array~new, "NUMERIC", .false, "TRUE", "PUBLIC", "NORMAL", "NONE", "NONE")
  self~registerMethodContract("EXPLODE", "deliberate syntax failure", .array~new, "ANY", .false, "TRUE", "PUBLIC", "NORMAL", "NONE", "NONE")

::method calculate
  use strict arg n
  return n * 2

::method badResult
  return "not numeric"

::method explode
  raise syntax 88.900 array("deliberate execution failure")

::requires "AlchemyObjects.cls"
