failures = 0

loaded = .KnownStateJsonStore~load("ibmi_known_states_live.json")
call assertTrue loaded~ok, "load live IBM i catalog"
if \loaded~ok then do
  say "FAIL test_live_known_state_fixture" failures
  exit 1
end
catalog = loaded~value
states = catalog~states
call assertEq states~items, 4, "four confirmed live states"

signon = catalog~state("IBM_I_SIGNON")
notice = catalog~state("IBM_I_PASSWORD_EXPIRED_NOTICE")
change = catalog~state("IBM_I_CHANGE_PASSWORD")
main = catalog~state("IBM_I_MAIN_MENU")
call assertTrue signon \== .nil, "live signon present"
call assertTrue notice \== .nil, "live expiry notice present"
call assertTrue change \== .nil, "live change password present"
call assertTrue main \== .nil, "live main menu present"

/* Every persisted live exemplar must still match its own interpretation after
 * JSON loading.  Nondisplay bytes are deliberately not reconstructed. */
do state over states
  call assertTrue state~exemplarCount > 0, "state has exemplar " || state~stateId
  frozen = state~exemplars[1]
  snap = frozen~snapshot
  match = catalog~match(snap)
  call assertEq match~status, "MATCH", "exemplar unambiguous " || state~stateId
  call assertEq match~matchedStateId, state~stateId, "exemplar matches own state " || state~stateId
  do f over snap~fields
    if f~nonDisplay then call assertEq f~value, "", "persisted secret bytes absent " || state~stateId || "/" || f~fieldId
  end
end

/* Assert the exact live field topology learned from PUB400, not the older
 * synthetic positions used during development. */
changeSnap = change~exemplars[1]~snapshot
call assertEq changeSnap~fields~items, 3, "live change-password field count"
f1 = changeSnap~field("F0687")
f2 = changeSnap~field("F0927")
f3 = changeSnap~field("F1167")
call assertField f1, 9, 47, 128, "current"
call assertField f2, 12, 47, 128, "new"
call assertField f3, 15, 47, 128, "verify"
call assertTrue f1~nonDisplay & f2~nonDisplay & f3~nonDisplay, "all three live fields nondisplay"
call assertTrue f1~inputCapable & f2~inputCapable & f3~inputCapable, "all three live fields input"


mainSnap = main~exemplars[1]~snapshot
call assertEq mainSnap~fields~items, 1, "live main menu field count"
mainField = mainSnap~field("F1527")
call assertField mainField, 20, 7, 153, "main command"
call assertTrue mainField~inputCapable & \mainField~protected & \mainField~nonDisplay, "main command field ordinary input"
call assertTrue pos("90. Sign off", mainSnap~rowText(17)) > 0, "live main menu signoff option"

changeTransitions = change~transitions
call assertEq changeTransitions~items, 1, "one observed change-password transition"
call assertEq changeTransitions[1]~actionKind, "AID", "change transition kind"
call assertEq changeTransitions[1]~actionName, "ENTER", "change transition action"
call assertEq changeTransitions[1]~toStateId, "IBM_I_MAIN_MENU", "change transition target"
call assertEq changeTransitions[1]~observationCount, 1, "change live observation count"

transitions = notice~transitions
call assertEq transitions~items, 1, "one observed notice transition"
call assertEq transitions[1]~actionKind, "AID", "transition kind"
call assertEq transitions[1]~actionName, "ENTER", "transition action"
call assertEq transitions[1]~toStateId, "IBM_I_CHANGE_PASSWORD", "transition target"
call assertEq transitions[1]~observationCount, 1, "live observation count"

if failures > 0 then do
  say "FAIL test_live_known_state_fixture" failures
  exit 1
end
say "PASS test_live_known_state_fixture"
exit 0

assertField: procedure expose failures
  use arg f, row, col, len, label
  if f == .nil then do
    failures += 1
    say "ASSERT_FIELD FAIL:" label "missing"
    return
  end
  call assertEq f~row, row, label || " row"
  call assertEq f~column, col, label || " col"
  call assertEq f~length, len, label || " len"
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

::requires "KnownStateJsonStore.cls"
