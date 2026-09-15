/* AlchemyTestSupport.cls - Alchemy Objects v0.4.3
 * Unit-test/run evidence support built on the same AlchemyObject base.
 */

::class AlchemyTestRun subclass AlchemyObject public
::attribute testName get

::method init
  expose testName testStartedAt testFinishedAt testAssertions testFailures testCompleted
  use strict arg testName, sealer = .nil, authority = .nil
  testName = testName~string
  testStartedAt = date("S") || "T" || time("L")
  testFinishedAt = ""
  testAssertions = .array~new
  testFailures = 0
  testCompleted = .false
  meta = .directory~new
  meta["purpose"] = "Alchemy executable unit-test evidence run"
  meta["package_version"] = "0.4.3"
  self~initAlchemy(meta, sealer, authority)
  self~registerStateVariable("testName", "CUSTOMER", "test/run name")
  self~registerStateVariable("testStartedAt", "CUSTOMER", "test start time")
  self~registerStateVariable("testFinishedAt", "CUSTOMER", "test finish time")
  self~registerStateVariable("testAssertions", "CUSTOMER", "ordered assertion evidence")
  self~registerStateVariable("testFailures", "CUSTOMER", "failed assertion count")
  self~registerStateVariable("testCompleted", "CUSTOMER", "whether complete() was called")
  self~registerMethodContract("ASSERTTRUE", "record boolean-true assertion", .array~of("ACTUAL", "MESSAGE"), "BOOLEAN", .false)
  self~registerMethodContract("ASSERTFALSE", "record boolean-false assertion", .array~of("ACTUAL", "MESSAGE"), "BOOLEAN", .false)
  self~registerMethodContract("ASSERTEQUALS", "record strict equality assertion", .array~of("EXPECTED", "ACTUAL", "MESSAGE"), "BOOLEAN", .false)
  self~registerMethodContract("ASSERTSURFACE", "record target surface-contract assertion", .array~of("TARGET", "MESSAGE"), "BOOLEAN", .false)
  self~registerMethodContract("ASSERTRESULTCONTRACT", "record target method result-contract assertion", .array~of("TARGET", "METHOD", "RESULT", "MESSAGE"), "BOOLEAN", .false)
  self~registerMethodContract("COMPLETE", "close the test run and return summary", .array~new, "DIRECTORY", .false)
  self~registerMethodContract("TESTSUMMARY", "return current test summary", .array~new, "DIRECTORY", .false)
  self~registerInstrumentationPoint("ALCHEMY.TEST.ASSERT", "test assertion recorded")
  self~registerInstrumentationPoint("ALCHEMY.TEST.COMPLETE", "test run completed")
  self~declareHouseCompliance(100)

::method assertTrue public
  use strict arg actual, message = ""
  ok = actual == .true
  self~recordAssertion("TRUE", ok, .true, actual, message)
  return ok

::method assertFalse public
  use strict arg actual, message = ""
  ok = actual == .false
  self~recordAssertion("FALSE", ok, .false, actual, message)
  return ok

::method assertEquals public
  use strict arg expected, actual, message = ""
  ok = expected == actual
  self~recordAssertion("EQUALS", ok, expected, actual, message)
  return ok

::method assertSurface public
  use strict arg target, message = "surface contract"
  if target == .nil | \target~hasMethod("CHECKSURFACECONTRACT") then do
    self~recordAssertion("SURFACE", .false, "AlchemyObject-compatible target", target, message)
    return .false
  end
  surfaceCheck = target~checkSurfaceContract
  self~recordAssertion("SURFACE", surfaceCheck~ok, "SURFACE_OK", surfaceCheck~code, message)
  return surfaceCheck~ok

::method assertResultContract public
  use strict arg target, methodName, result, message = "result contract"
  if target == .nil | \target~hasMethod("CHECKRESULTCONTRACT") then do
    self~recordAssertion("RESULT_CONTRACT", .false, "AlchemyObject-compatible target", target, message)
    return .false
  end
  check = target~checkResultContract(methodName, result)
  self~recordAssertion("RESULT_CONTRACT", check~ok, "RESULT_OK", check~code, message)
  return check~ok

::method complete public
  expose testFinishedAt testCompleted
  testFinishedAt = date("S") || "T" || time("L")
  testCompleted = .true
  self~alchemyInstrument("ALCHEMY.TEST.COMPLETE", self~testSummary)
  return self~testSummary

::method testSummary public
  expose testName testStartedAt testFinishedAt testAssertions testFailures testCompleted
  d = .directory~new
  d["schema"] = "alchemy.objects.test-run/0.1"
  d["test_name"] = testName
  d["started_at"] = testStartedAt
  d["finished_at"] = testFinishedAt
  d["completed"] = testCompleted
  d["assertions"] = testAssertions~items
  d["failures"] = testFailures
  d["passed"] = testCompleted & testFailures = 0
  return d

::method requirePass public
  expose testFailures testCompleted
  if \testCompleted then raise syntax 88.900 array("Alchemy test run is not complete")
  if testFailures > 0 then raise syntax 88.900 array("Alchemy test run has " || testFailures || " failed assertions")
  return .true

::method recordAssertion private
  expose testAssertions testFailures
  use strict arg kind, ok, expected, actual, message
  rec = .directory~new
  rec["sequence"] = testAssertions~items + 1
  rec["time"] = date("S") || "T" || time("L")
  rec["kind"] = kind~string~translate
  rec["ok"] = ok
  rec["message"] = message~string
  rec["expected"] = self~safeTestValue(expected)
  rec["actual"] = self~safeTestValue(actual)
  testAssertions~append(rec)
  if \ok then testFailures = testFailures + 1
  self~alchemyInstrument("ALCHEMY.TEST.ASSERT", rec)
  return rec

::method safeTestValue private
  use strict arg value
  if value == .nil then return .nil
  if value == .true | value == .false then return value
  if value~isA(.String) then return value
  d = .directory~new
  d["class"] = value~class~id
  d["identity_hash"] = value~identityHash~string
  if value~hasMethod("ALCHEMYOBJECTID") then d["object_id"] = value~alchemyObjectId
  return d

::requires "AlchemyObject.cls"
