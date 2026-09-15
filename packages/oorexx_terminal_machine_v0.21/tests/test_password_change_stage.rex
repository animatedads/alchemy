failures = 0

runtime = .TestPasswordRuntime~new("PWCHANGE-STAGE")
model = runtime~model
call buildPanel model, 128, 128
snap = runtime~commit

known = .KnownState5250Factory~ibmIChangePassword(snap, "IBM_I_CHANGE_PASSWORD", "TEST_HUMAN")
call assertTrue known~ok, "learn change password state"
catalog = .KnownStateCatalog~new
call assertTrue catalog~register(known~value)~ok, "register change password state"

mapped = .KnownState5250Factory~findChangePasswordFields(runtime~snapshot)
call assertTrue mapped~ok, "structured field mapping"
call assertEq mapped~value["current"]~fieldId, "CURRENT", "current mapping"
call assertEq mapped~value["new"]~fieldId, "NEW", "new mapping"
call assertEq mapped~value["verify"]~fieldId, "VERIFY", "verify mapping"

lease = .TN5250PasswordChangeLease~new("LOCAL-PWCHANGE", "OLDCURRENT", "NEWSECRET")
staged = .TN5250PasswordChange~stage(runtime, catalog, lease)
call assertTrue staged~ok, "stage three secrets"
call assertTrue lease~retired, "lease retired after use"
call assertTrue \staged~value~hasMethod("SECRET"), "safe result has no secret getter"
call assertEq staged~value~snapshot~field("CURRENT")~value, "<SECRET>", "current redacted"
call assertEq staged~value~snapshot~field("NEW")~value, "<SECRET>", "new redacted"
call assertEq staged~value~snapshot~field("VERIFY")~value, "<SECRET>", "verify redacted"
call assertTrue pos("OLDCURRENT", staged~value~snapshot~visibleText) = 0, "old password absent from visible text"
call assertTrue pos("NEWSECRET", staged~value~snapshot~visibleText) = 0, "new password absent from visible text"

secretInTrace = .false
do event over runtime~trace~events
  if event~eventType == "ACTION" then do
    if pos("OLDCURRENT", event~payload~value) > 0 then secretInTrace = .true
    if pos("NEWSECRET", event~payload~value) > 0 then secretInTrace = .true
  end
end
call assertTrue \secretInTrace, "passwords absent from action trace"

/* Trusted wire-facing field snapshots contain real values, including the
 * repeated new password, while the observer snapshot remains redacted. */
wireFields = runtime~modifiedFieldsForWire
call assertEq wireFields~items, 3, "three modified secret fields"
call assertEq wireFields[1]~value, "OLDCURRENT", "trusted current value"
call assertEq wireFields[2]~value, "NEWSECRET", "trusted new value"
call assertEq wireFields[3]~value, "NEWSECRET", "trusted verify value"

/* Wrong semantic state refuses before consuming a lease. */
wrongRuntime = .TestPasswordRuntime~new("PWCHANGE-WRONG")
wrongLease = .TN5250PasswordChangeLease~new("WRONG", "OLD2", "NEW2")
refused = .TN5250PasswordChange~stage(wrongRuntime, catalog, wrongLease)
call assertTrue \refused~ok, "wrong state refused"
call assertEq refused~code, "PASSWORD_CHANGE_STATE_NOT_CONFIRMED", "wrong state reason"
call assertTrue \wrongLease~retired, "wrong-state lease not consumed"

/* Overflow is transactional: no field is left modified. */
runtime2 = .TestPasswordRuntime~new("PWCHANGE-OVERFLOW")
model2 = runtime2~model
call buildPanel model2, 8, 8
snap2 = runtime2~commit
known2 = .KnownState5250Factory~ibmIChangePassword(snap2, "PW_SHORT", "TEST_HUMAN")
call assertTrue known2~ok, "learn short topology"
cat2 = .KnownStateCatalog~new
call assertTrue cat2~register(known2~value)~ok, "register short topology"
longLease = .TN5250PasswordChangeLease~new("LONG", "OLD", "TOO-LONG-NEW")
failed = .TN5250PasswordChange~stage(runtime2, cat2, longLease, "PW_SHORT")
call assertTrue \failed~ok, "overflow refused"
call assertEq failed~code, "SECRET_FIELD_OVERFLOW", "overflow reason"
call assertEq runtime2~modifiedFieldsForWire~items, 0, "overflow leaves no MDT secret fields"

if failures > 0 then do
  say "FAIL test_password_change_stage" failures
  exit 1
end
say "PASS test_password_change_stage"
exit 0

buildPanel: procedure
  use arg model, newLength, verifyLength
  model~writeText(1, 34, "Change Password")
  model~writeText(3, 3, "User profile . . . . . . . . . . . . : DASHADYER")
  model~writeText(5, 3, "Password last changed . . . . . . . . : 26-08-21")
  model~writeText(7, 3, "Type choices, press Enter.")
  model~writeText(9, 5, "Current password  . . . . . . . . . .")
  model~writeText(12, 5, "New password  . . . . . . . . . . . .")
  model~writeText(15, 5, "New password (to verify)  . . . . . .")
  model~writeText(23, 3, "F3=Exit            F9=Display password rules            F12=Cancel")
  ignore = model~defineField("CURRENT", 9, 47, 128, "", .true, .false, .true)
  ignore = model~defineField("NEW", 12, 47, newLength, "", .true, .false, .true)
  ignore = model~defineField("VERIFY", 15, 47, verifyLength, "", .true, .false, .true)
  model~setCursor(16, 80)
  model~setKeyboardState("UNLOCKED")
  model~setSessionState("OPERATOR_WAIT")
  model~hostCommit
  return

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return
assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::class TestPasswordRuntime
::attribute model get
::attribute trace get

::method init
  expose model session agent trace
  use arg sessionIdArg
  model = .PresentationSpace5250~new
  session = .TerminalSession~new(sessionIdArg, model)
  trace = session~trace
  agent = .Terminal5250AgentPort~new(session, model)

::method commit
  expose session
  return session~commit

::method snapshot
  expose agent
  return agent~snapshot

::method stageNondisplaySecretTriple
  expose agent
  use arg generationArg, firstFieldIdArg, firstValueArg, secondFieldIdArg, secondValueArg, thirdFieldIdArg, thirdValueArg, actorArg
  return agent~stageNondisplaySecretTriple(generationArg, firstFieldIdArg, firstValueArg, secondFieldIdArg, secondValueArg, thirdFieldIdArg, thirdValueArg, actorArg)

::method modifiedFieldsForWire
  expose model
  return model~modifiedFieldsForWire

::requires "TN5250PasswordChange.cls"
