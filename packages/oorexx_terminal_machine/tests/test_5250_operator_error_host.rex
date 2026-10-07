failures = 0
cp = .CodePage037~new
model = .PresentationSpace5250~new
machine = .DataStream5250Machine~new(model, cp)
model~setKeyboardState("UNLOCKED")
model~setSessionState("OPERATOR_WAIT")
model~setCursor(5,10)
call assertTrue model~queueReadModified("ENTER")~ok, "pre-existing AID can be pending"
model~setKeyboardState("UNLOCKED")

/* IBM WRITE ERROR CODE x'21': optional IC plus error data.  v0.6 models the
 * pre-help state and safe visible message; exact error-line image semantics
 * remain a documented later surface. */
wec = "0421"x || "13"x || d2c(20) || d2c(3) || "28"x || cp~encode("HOST ERROR") || "27"x
parsed = machine~consume(wec)
call assertTrue parsed~ok, "WRITE ERROR CODE parsed"
call assertEq parsed~value~commandName, "WRITE_ERROR_CODE", "WEC outcome"
snap = model~snapshot
condition = snap~operatorCondition
call assertTrue condition \== .nil, "host WEC creates operator condition"
call assertEq condition~state, "PRE_HELP_ERROR", "host WEC pre-help state"
call assertEq condition~kind, "HOST_WRITE_ERROR_CODE", "host WEC kind"
call assertEq condition~origin, "HOST_WRITE_ERROR_CODE", "host WEC origin"
call assertTrue pos("HOST ERROR", condition~message) > 0, "host WEC visible message retained"
call assertEq snap~keyboardState, "LOCKED", "host WEC locks keyboard"
call assertEq snap~cursorRow, 20, "host WEC IC row"
call assertEq snap~cursorColumn, 3, "host WEC IC col"
call assertEq snap~metadata["pendingAid"], "", "host WEC clears outstanding AID"
call assertTrue snap~metadata["cursorBlink"] == 1 | snap~metadata["cursorBlink"] == .true, "host WEC blinks cursor"

reset = model~clearOperatorError
call assertTrue reset~ok, "host WEC Error Reset"
call assertEq model~keyboardState, "UNLOCKED", "host WEC reset restores keyboard"

/* SOH ERR row is preserved for later exact error-line rendering. */
sohModel = .PresentationSpace5250~new
sohMachine = .DataStream5250Machine~new(sohModel, cp)
/* SOH length=4: header bytes 1..3 arbitrary here, byte4 ERR row=22. */
soh = "0411"x || "0000"x || "01"x || d2c(4) || "000000"x || d2c(22)
parsed = sohMachine~consume(soh)
call assertTrue parsed~ok, "SOH parsed"
call assertEq sohModel~metadata["errorRow"], 22, "SOH error row retained"

if failures > 0 then do
  say "FAIL test_5250_operator_error_host" failures
  exit 1
end
say "PASS test_5250_operator_error_host"
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
