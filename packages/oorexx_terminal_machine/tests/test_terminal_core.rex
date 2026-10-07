parse source . . thisFile

failures = 0
call assertEq .TerminalBuild~RELEASE, "0.2", "core release"

caps = .TerminalCapabilities~new
caps~add("CHARACTER_GRID")~add("INPUT_FIELDS")
fields = .array~new
fields~append(.TerminalFieldSnapshot~new("F1", 2, 5, 6, "ABC", .true, .false))
rows = .array~new(3)
rows[1] = "HEADER    "
rows[2] = "    ABC   "
rows[3] = "FOOTER    "
snap = .TerminalSnapshot~new(7, "TESTTERM", 3, 10, 2, 6, "UNLOCKED", "READY", rows, fields, caps)

/* Returned collections are copies. */
r = snap~textRows
r[1] = "MUTATED"
call assertEq snap~rowText(1), "HEADER    ", "snapshot rows detached"
f = snap~fields
f~append(.TerminalFieldSnapshot~new("X", 1, 1, 1))
call assertEq snap~fields~items, 1, "snapshot field list detached"

watch = .TerminalWatchAlong~new(2)
watch~observe(snap)
call assertEq watch~current~generation, 7, "watch current"
call assertTrue pos("generation: 7", watch~look) > 0, "watch look text"

trace = .TerminalTrace~new
trace~appendSnapshot(snap)
snap2 = .TerminalSnapshot~new(8, "TESTTERM", 3, 10, 3, 1, "UNLOCKED", "READY", rows, fields, caps)
trace~appendSnapshot(snap2)
replay = .TerminalReplay~new(trace)
call assertEq replay~count, 2, "replay count"
call assertTrue replay~seek(8)~ok, "seek generation"
frozen = replay~freeze
call assertEq frozen~snapshot~generation, 8, "freeze generation"
call assertEq frozen~previousSnapshot~generation, 7, "freeze previous"

if failures > 0 then do
  say "FAIL test_terminal_core" failures
  exit 1
end
say "PASS test_terminal_core"
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
