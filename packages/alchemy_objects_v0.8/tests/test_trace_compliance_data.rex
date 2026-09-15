ring = .CryptoMacKeyRing~new
ring~addKey("trace-house", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
o = .TraceSubject~new(sealer, authority)

contractCap = authority~issueForSeconds("auditor", o~alchemyObjectId, "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER", 60)
contracts = o~sealedIntrospection("CUSTOMER", contractCap)~payload["method_contracts"]
found = .false
do c over contracts
  if c["name"] = "ECHO" then do
    found = .true
    call assertEq 2, c["data_description"]~items, "method data descriptors"
  end
end
call assertTrue found, "ECHO contract found"

cap = authority~issue("auditor", o~alchemyObjectId, "SEALEDEXECUTIONTRACE", "TRACE:STACK")
trace = o~sealedExecutionTrace("STACK", cap, 12)
call assertTrue sealer~verify(trace), "stack trace seal verifies"
call assertEq "STACK", trace~payload["profile"], "stack trace profile"
call assertTrue trace~payload["frames"]~items > 0, "stack trace contains frames"
call assertFalse trace~payload["frames"][1]~hasIndex("arguments"), "STACK trace omits arguments"

cap = authority~issue("auditor", o~alchemyObjectId, "SEALEDEXECUTIONTRACE", "TRACE:FULL")
fullTrace = o~sealedExecutionTrace("FULL", cap, 12)
call assertTrue sealer~verify(fullTrace), "full trace seal verifies"
call assertTrue fullTrace~payload["frames"]~items > 1, "full trace contains caller frames"
call assertTrue fullTrace~payload["frames"][2]~hasIndex("arguments"), "FULL trace includes argument descriptors"

ccap = authority~issue("auditor", o~alchemyObjectId, "COMPLIANCEREPORT", "COMPLIANCE")
report = o~complianceReport(ccap)
call assertTrue sealer~verify(report), "house compliance seal verifies"
rows = report~payload["checks"]
found = .false
do r over rows
  if r["standard_id"] = "ALCHEMY-HOUSE-OBJECT-0.8" then do
    found = .true
    call assertEq 95, r["claimed_score"], "author claimed score"
    call assertEq 100, r["max_score"], "house max score"
    call assertTrue r["calculated_score"] >= 90, "calculated structural score"
    call assertEq r["calculated_score"] - 95, r["delta"], "house delta"
  end
end
call assertTrue found, "house compliance row found"

say "PASS test_trace_compliance_data"
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

::class TraceSubject subclass AlchemyObject
::method init
  use strict arg sealer, authority
  meta = .directory~new
  meta["purpose"] = "trace/compliance test object"
  meta["package_version"] = "0.2-test"
  self~initAlchemy(meta, sealer, authority)
  self~registerMethodContract("ECHO", "return supplied text", .array~of("VALUE"), "STRING", .false)
  self~describeMethodData("ECHO", "INPUT", "VALUE", "STRING", .true, "text to return", "CUSTOMER")
  self~describeMethodData("ECHO", "RESULT", "RETURN", "STRING", .true, "same text", "CUSTOMER")
  self~declareHouseCompliance(95)

::method echo
  use strict arg value
  return value

::requires "AlchemyObjects.cls"
