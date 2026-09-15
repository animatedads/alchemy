failures = 0
path = "known_state_test.json"

caps = .TerminalCapabilities~new
caps~add("CHARACTER_GRID")~add("INPUT_FIELDS")
rows = .array~new(2)
rows[1] = "STATE SCREEN"
rows[2] = "Password: ********"
fields = .array~new
fields~append(.TerminalFieldSnapshot~new("PASSWORD", 2, 11, 8, "SUPERSEC", .true, .false, .true))
snap = .TerminalSnapshot~new(9, "IBM5250", 2, 20, 2, 11, "UNLOCKED", "OPERATOR_WAIT", rows, fields, caps, .nil, "d9", "layout9")
trace = .TerminalTrace~new
trace~appendSnapshot(snap)
replay = .TerminalReplay~new(trace)
frozen = replay~freeze

state = .KnownTerminalState~new("S9", "PASSWORD_WAIT", "Known password wait", "HUMAN")
state~addCriterion(.KnownStateCriterion~new("c1", "LAYOUT_FINGERPRINT_EQ", "layout9"))
state~addAnnotation(.KnownStateAnnotation~new("a1", "HUMAN", "Seen before"))
state~addExemplar(frozen)
catalog = .KnownStateCatalog~new
catalog~register(state)

saved = .KnownStateJsonStore~save(catalog, path)
call assertTrue saved~ok, "save catalog"
loaded = .KnownStateJsonStore~load(path)
call assertTrue loaded~ok, "load catalog"
loadedCatalog = loaded~value
match = loadedCatalog~match(snap)
call assertEq match~status, "MATCH", "roundtrip match"
loadedState = loadedCatalog~state("S9")
call assertEq loadedState~exemplarCount, 1, "exemplar retained"
loadedPassword = loadedState~exemplars[1]~snapshot~field("PASSWORD")
call assertEq loadedPassword~value, "", "secret not persisted"

text = charin(path, 1, chars(path))
call assertTrue pos("SUPERSEC", text) == 0, "secret absent from JSON"
call assertTrue pos("<SECRET>", text) > 0, "redaction marker persisted"
call stream path, "c", "close"
call sysFileDelete path

if failures > 0 then do
  say "FAIL test_known_state_json" failures
  exit 1
end
say "PASS test_known_state_json"
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

::requires "KnownStateJsonStore.cls"
