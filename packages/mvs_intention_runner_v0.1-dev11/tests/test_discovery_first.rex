runner = .MvsIntentionRunner~new("ED209Z", .MvsFixtureDiscoveryBackend~new(1))
d = runner~input("find the last failed compile for Fred")
call assertEq "READY", d~status, "generation1 status"
call assertEq "FIND_LAST_FAILED_COMPILE", d~registration~id, "generation1 intention"
call assertEq "JOB00140", d~proposal~slot("JOB_ID")~value, "generation1 discovered job"
call assertEq 17, runner~snapshot~probeCount, "safe probe count"
call assertSafe runner~snapshot~probeTrace
fact = runner~service~bestEvidence("JOB.JOB00140", "COMPLETION", "CC 0012")
if fact == .nil then call fail "missing published live job evidence"
call assertEq "OBSERVED", fact~authority, "job evidence authority"
call assertEq "JES_DISCOVERY", fact~source, "job evidence source"

/* Same English. Changed live discovery. The intention must follow reality. */
runner~backend~generation = 2
d2 = runner~input("find the last failed compile for Fred")
call assertEq "READY", d2~status, "generation2 status"
call assertEq "JOB00144", d2~proposal~slot("JOB_ID")~value, "generation2 discovered job"
call assertEq 17, runner~snapshot~probeCount, "generation2 safe probe count"

say "PASS discovery-first MVS intention follows live scope"
exit 0
assertSafe: procedure
  use arg trace
  do r over trace
    if \r~safe then call fail "unsafe probe in discovery trace: " || r~name
  end
return
assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  call fail label || " expected=" || expected || " actual=" || actual
return
fail: procedure
  use arg message
  say "FAIL" message
  exit 1
::requires "MvsIntention.cls"
