failures = 0

model = .PresentationSpace5250~new
session = .TerminalSession~new("NAVERR", model)
watch = .TerminalWatchAlong~new(8)
session~addWatcher(watch)
agent = .Terminal5250AgentPort~new(session, model)

/* Mirror the live IBM_I_CHANGE_PASSWORD topology supplied by IBM i. */
attrs = .directory~new
attrs["autoEnter"] = 0
attrs["fieldExitRequired"] = 0
call assertTrue model~defineField("F0687", 9, 47, 128, "", .true, .false, .true, .false, attrs)~ok, "define current password"
call assertTrue model~defineField("F0927", 12, 47, 128, "", .true, .false, .true, .false, attrs)~ok, "define new password"
call assertTrue model~defineField("F1167", 15, 47, 128, "", .true, .false, .true, .false, attrs)~ok, "define verify password"
model~setKeyboardState("UNLOCKED")
model~setSessionState("OPERATOR_WAIT")
call assertTrue model~setHome(9,47)~ok, "system IC/home"
model~setCursor(9,47)
model~hostCommit
snap = session~commit
call assertEq snap~generation, 1, "initial generation"

/* Structured navigation targets host-declared input fields, never visual guesses. */
r = agent~focusField(1, "F0927")
call assertTrue r~ok, "focus named field"
call assertEq model~cursorRow, 12, "focus row"
call assertEq model~cursorColumn, 47, "focus col"
r = agent~nextInputField(1)
call assertTrue r~ok, "next field"
call assertEq model~cursorRow, 15, "next row"
r = agent~nextInputField(1)
call assertTrue r~ok, "next wraps"
call assertEq model~cursorRow, 9, "next wrap row"
r = agent~previousInputField(1)
call assertTrue r~ok, "previous wraps"
call assertEq model~cursorRow, 15, "previous wrap row"

/* Home uses the last IC address.  A second Home at home is Record Backspace,
 * which v0.6 deliberately refuses rather than silently inventing semantics. */
r = agent~home(1)
call assertTrue r~ok, "home returns to IC"
call assertEq model~cursorRow, 9, "home row"
call assertEq model~cursorColumn, 47, "home col"
r = agent~home(1)
call assertTrue \r~ok, "home-at-home does not fake record backspace"
call assertEq r~code, "5250_HOME_RECORD_BACKSPACE_NOT_IMPLEMENTED", "record backspace boundary"

/* Reproduce the real human mistake: put the cursor in protected space and type. */
call assertTrue agent~moveCursor(1, 23, 70)~ok, "move into protected space"
navFromProtected = agent~nextInputField(1)
call assertTrue navFromProtected~ok, "structured next from protected space"
call assertEq model~cursorRow, 9, "protected-space next wraps to first input"
call assertEq model~cursorColumn, 47, "protected-space next col"
call assertTrue agent~moveCursor(1, 23, 70)~ok, "move back into protected space"
r = agent~typeAtCursor(1, "X")
call assertTrue \r~ok, "typing in protected area rejected"
call assertEq r~code, "5250_OPERATOR_ERROR_0005", "operator error code result"
errSnap = agent~snapshot
condition = errSnap~operatorCondition
call assertTrue condition \== .nil, "operator condition exposed"
call assertEq condition~state, "PRE_HELP_ERROR", "pre-help error state"
call assertEq condition~code, "0005", "5250 operator error 0005"
call assertEq condition~kind, "PROTECTED_AREA", "protected-area classification"
call assertEq condition~origin, "LOCAL_KEYING", "local keying origin"
call assertEq condition~cursorRow, 23, "offending cursor row"
call assertEq condition~cursorColumn, 70, "offending cursor col"
call assertTrue condition~recoverable, "error is recoverable"
call assertEq condition~recoveryActions[1], "ERROR_RESET", "reset advertised"
call assertEq errSnap~keyboardState, "LOCKED", "keyboard locked in pre-help error"
call assertTrue errSnap~metadata["cursorBlink"] == 1 | errSnap~metadata["cursorBlink"] == .true, "cursor blinking in error"

/* Known-state criteria can reason about the operator condition independently
 * from the semantic host screen identity. */
errState = .KnownTerminalState~new("LOCAL_0005", "Protected-area operator error")
errState~addCriterion(.KnownStateCriterion~new("state", "OPERATOR_STATE_EQ", "PRE_HELP_ERROR"))
errState~addCriterion(.KnownStateCriterion~new("kind", "OPERATOR_ERROR_KIND_EQ", "PROTECTED_AREA"))
errState~addCriterion(.KnownStateCriterion~new("code", "OPERATOR_ERROR_CODE_EQ", "0005"))
call assertTrue errState~match(errSnap)~matched, "operator criteria match"

/* While in pre-help error, normal navigation/input remains inhibited. */
blocked = agent~focusField(1, "F0687")
call assertTrue \blocked~ok, "field focus inhibited during error"
call assertEq blocked~code, "5250_OPERATOR_ERROR_ACTIVE", "focus inhibition code"
blocked = agent~moveCursor(1, 9, 47)
call assertTrue \blocked~ok, "cursor movement inhibited during error"

/* Error Reset restores the previous unlocked state without changing screen identity. */
reset = agent~errorReset(1)
call assertTrue reset~ok, "error reset"
postReset = agent~snapshot
call assertTrue postReset~operatorCondition == .nil, "operator condition cleared"
call assertEq postReset~keyboardState, "UNLOCKED", "keyboard restored"
call assertTrue \(postReset~metadata["cursorBlink"] == 1 | postReset~metadata["cursorBlink"] == .true), "blink restored"
call assertEq postReset~cursorRow, 23, "reset does not invent cursor relocation"
call assertEq postReset~cursorColumn, 70, "reset retains cursor position"

/* Cursor-relative typing into a real NONDISPLAY field updates the trusted
 * backing field but cannot appear in snapshot, WatchAlong or action trace. */
call assertTrue agent~focusField(1, "F0927")~ok, "focus secret field after reset"
secret = "S3CR3T!"
typed = agent~typeAtCursor(1, secret)
call assertTrue typed~ok, "type at cursor into nondisplay field"
call assertTrue model~field("F0927")~value~startsWith(secret), "trusted field contains typed secret"
safe = agent~snapshot
call assertEq safe~field("F0927")~value, "<SECRET>", "snapshot remains redacted"
call assertTrue pos(secret, safe~visibleText) = 0, "visible text has no secret"
call assertTrue pos(secret, watch~current~visibleText) = 0, "WatchAlong has no secret"
traceLeak = .false
do event over session~trace~events
  if event~eventType == "ACTION" then do
    a = event~payload
    if pos(secret, a~value) > 0 then traceLeak = .true
  end
end
call assertTrue \traceLeak, "action trace contains no secret"

/* A host screen change advances generation and invalidates old action tokens. */
model~hostCommit
session~commit
stale = agent~nextInputField(1)
call assertTrue \stale~ok, "old generation rejected after host change"
call assertEq stale~code, "STALE_SCREEN", "stale navigation code"

if failures > 0 then do
  say "FAIL test_field_navigation_operator_error" failures
  exit 1
end
say "PASS test_field_navigation_operator_error"
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

::requires "Terminal5250.cls"
