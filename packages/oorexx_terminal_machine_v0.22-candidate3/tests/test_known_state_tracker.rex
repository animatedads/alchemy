failures = 0

loaded = .KnownStateJsonStore~load("ibmi_known_states_live.json")
call assertTrue loaded~ok, "load live known-state catalog"
if \loaded~ok then exit 1
catalog = loaded~value
tracker = .TerminalKnownStateTracker~new(catalog, 8)
call assertTrue tracker~isA(.AlchemyObject), "semantic tracker inherits AlchemyObject"
call assertEq tracker~currentStatus, "NO_MATCH", "initial semantic status"
call assertEq tracker~currentGeneration, 0, "initial semantic generation"

signon = renumber(catalog~state("IBM_I_SIGNON")~exemplars[1]~snapshot, 1)
notice = renumber(catalog~state("IBM_I_PASSWORD_EXPIRED_NOTICE")~exemplars[1]~snapshot, 2)
change = renumber(catalog~state("IBM_I_CHANGE_PASSWORD")~exemplars[1]~snapshot, 3)
main = renumber(catalog~state("IBM_I_MAIN_MENU")~exemplars[1]~snapshot, 4)

tracker~observe(signon)
call assertEq tracker~currentStatus, "MATCH", "signon matched"
call assertEq tracker~currentStateId, "IBM_I_SIGNON", "signon state id"
call assertEq tracker~currentGeneration, 1, "signon generation"
call assertEq tracker~transitionCount, 0, "first known state is not transition"

tracker~observe(notice)
call assertEq tracker~currentStateId, "IBM_I_PASSWORD_EXPIRED_NOTICE", "notice state id"
call assertEq tracker~previousKnownStateId, "IBM_I_SIGNON", "previous signon"
call assertEq tracker~transitionCount, 1, "signon to notice transition"

tracker~observe(change)
call assertEq tracker~currentStateId, "IBM_I_CHANGE_PASSWORD", "change state id"
call assertEq tracker~previousKnownStateId, "IBM_I_PASSWORD_EXPIRED_NOTICE", "previous notice"
call assertEq tracker~transitionCount, 2, "notice to change transition"

tracker~observe(main)
call assertEq tracker~currentStateId, "IBM_I_MAIN_MENU", "main state id"
call assertEq tracker~previousKnownStateId, "IBM_I_CHANGE_PASSWORD", "previous change"
call assertEq tracker~transitionCount, 3, "change to main transition"
call assertEq tracker~history~items, 4, "four semantic observations"

/* Duplicate and older observations must not rewind or fabricate transitions. */
tracker~observe(main)
tracker~observe(signon)
call assertEq tracker~currentGeneration, 4, "stale observation cannot rewind generation"
call assertEq tracker~currentStateId, "IBM_I_MAIN_MENU", "stale observation cannot rewind state"
call assertEq tracker~transitionCount, 3, "duplicates/stale do not add transitions"
call assertEq tracker~history~items, 4, "duplicates/stale do not add history"

current = tracker~current
call assertEq current~generation, 4, "detached current generation"
call assertEq current~stateId, "IBM_I_MAIN_MENU", "detached current state"
call assertEq current~candidateStateIds~items, 1, "one matched candidate"
call assertEq current~candidateStateIds[1], "IBM_I_MAIN_MENU", "candidate id retained"

/* Runtime attachment gives the read-only observer semantic methods without
 * adding any mutation method to the observation surface. */
runtime = .TN5250RuntimeSession~new("SEMANTIC-RUNTIME")
attached = runtime~attachKnownStateCatalog(catalog, 8)
call assertTrue attached~ok, "runtime accepts semantic tracker"
observer = runtime~observationPort
call assertEq observer~knownStateStatus, "NO_MATCH", "observer semantic status available"
call assertEq observer~knownStateGeneration, 0, "observer semantic generation available"
call assertTrue \observer~hasMethod("PRESS"), "semantic observer remains read-only"
second = runtime~attachKnownStateCatalog(catalog, 8)
call assertTrue \second~ok, "runtime rejects second tracker"
call assertEq second~code, "KNOWN_STATE_TRACKER_EXISTS", "runtime second tracker code"

if failures > 0 then do
  say "FAIL test_known_state_tracker" failures
  exit 1
end
say "PASS test_known_state_tracker"
exit 0

renumber: procedure
  use arg snap, generation
  return .TerminalSnapshot~new(generation, snap~terminalType, snap~rows, snap~columns, snap~cursorRow, snap~cursorColumn, snap~keyboardState, snap~sessionState, snap~textRows, snap~fields, snap~capabilities, snap~metadata, snap~contentDigest, snap~layoutFingerprint, snap~timestamp)

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

::requires "TN5250Automation.cls"
::requires "KnownStateJsonStore.cls"
