failures = 0
cp = .CodePage037~new
model = .PresentationSpace5250~new
session = .TerminalSession~new("PENDING-AID", model)
agent = .Terminal5250AgentPort~new(session, model)
machine = .DataStream5250Machine~new(model, cp)

call assertTrue model~defineField("CMD", 12, 10, 10, "", .true, .false)~ok, "define command field"
model~setCursor(12, 10)
model~setKeyboardState("UNLOCKED")
model~setSessionState(.TerminalStatus~OPERATOR_WAIT)
model~hostCommit
session~commit
call assertEq model~pendingReadKind, "", "no synthetic READ at startup"

/* IBM Chapter 16: an AID can become pending before a READ command exists. */
call assertTrue agent~setField(1, "CMD", "WRKACTJOB")~ok, "enter command"
pressed = agent~press(1, "ENTER")
call assertTrue pressed~ok, "Enter accepted without pending READ"
call assertEq model~pendingAidName, "ENTER", "AID retained"
call assertEq model~keyboardState, "LOCKED", "AID locks keyboard"
call assertTrue model~takePendingReadModified == .nil, "no wire response before READ"

/* Host READ MDT arrives later.  It services the already-pending AID. */
read = machine~consume("04520000"x)
call assertTrue read~ok, "later READ MDT accepted"
call assertEq model~pendingAidName, "", "pending AID serviced"
wireRead = model~takePendingReadModified
call assertTrue wireRead \== .nil, "READ creates pending wire response"
call assertEq wireRead~aidByte~c2x, "F1", "retained Enter AID used"
call assertEq wireRead~readKind, "READ_MDT", "later READ kind bound"
call assertEq wireRead~fields~items, 1, "modified field retained for delayed READ"
call assertEq wireRead~fields[1]~value, "WRKACTJOB", "field value survives pending interval"
call assertEq model~pendingReadKind, "", "READ cleared when response taken"

if failures > 0 then do
  say "FAIL test_5250_pending_aid" failures
  exit 1
end
say "PASS test_5250_pending_aid"
exit 0

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

::requires "DataStream5250.cls"
