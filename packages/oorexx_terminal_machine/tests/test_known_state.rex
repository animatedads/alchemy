failures = 0
caps = .TerminalCapabilities~new
caps~add("CHARACTER_GRID")~add("INPUT_FIELDS")
rows = .array~new(4)
rows[1] = "TEST SYSTEM                             "
rows[2] = "                                        "
rows[3] = "CPF9999 - Odd condition; F14=Continue  "
rows[4] = "F3=Exit F12=Cancel F14=Continue        "
fields = .array~new
fields~append(.TerminalFieldSnapshot~new("OPTION", 2, 2, 4, "", .true, .false))
snap = .TerminalSnapshot~new(42, "IBM5250", 4, 40, 2, 2, "UNLOCKED", "OPERATOR_WAIT", rows, fields, caps, .nil, "content42", "layoutA")

known = .KnownTerminalState~new("STATE_42", "IBM_I_ODD_WAIT", "An odd operator wait", "HUMAN")
known~addCriterion(.KnownStateCriterion~new("c1", "TERMINAL_TYPE_EQ", "IBM5250"))
known~addCriterion(.KnownStateCriterion~new("c2", "LAYOUT_FINGERPRINT_EQ", "layoutA"))
known~addCriterion(.KnownStateCriterion~new("c3", "ROW_CONTAINS", 3, "CPF9999"))
known~addCriterion(.KnownStateCriterion~new("c4", "CURSOR_IN_FIELD", "OPTION"))
known~addCriterion(.KnownStateCriterion~new("c5", "SESSION_STATE_EQ", "OPERATOR_WAIT"))
known~addAnnotation(.KnownStateAnnotation~new("a1", "HUMAN", "F14 was required in the observed recovery"))
known~addTransition(.KnownStateTransition~new("STATE_42", "AID", "F14", "STATE_CONTINUED", 1, "observed, not authorised"))

catalog = .KnownStateCatalog~new
call assertTrue catalog~register(known)~ok, "register known state"
match = catalog~match(snap)
call assertEq match~status, "MATCH", "known state match"
call assertEq match~matchedStateId, "STATE_42", "known state id"

/* Add a second overlapping state and verify we refuse to guess. */
known2 = .KnownTerminalState~new("STATE_OVERLAP", "OVERLAP")
known2~addCriterion(.KnownStateCriterion~new("x1", "TERMINAL_TYPE_EQ", "IBM5250"))
call assertTrue catalog~register(known2)~ok, "register overlap"
match2 = catalog~match(snap)
call assertEq match2~status, "AMBIGUOUS", "ambiguous not guessed"

if failures > 0 then do
  say "FAIL test_known_state" failures
  exit 1
end
say "PASS test_known_state"
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

::requires "TerminalCore.cls"
