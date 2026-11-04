feed = .MvsSourceResult~new("REFERENCE_X3270")
feed~addFact(.MvsSourceFact~new("REFERENCE_X3270", "SESSION", "STATE", "CONNECTED", 100, "x3270:test"))
feed~addFact(.MvsSourceFact~new("REFERENCE_X3270", "SESSION", "MODEL", "3278-2", 100, "x3270:test"))
feed~addFact(.MvsSourceFact~new("REFERENCE_X3270", "SCREEN", "CLASS", "TSO_LOGON", 100, "x3270:test"))
feed~addFact(.MvsSourceFact~new("REFERENCE_X3270", "SCREEN", "ROWS", "24", 100, "x3270:test"))
feed~addFact(.MvsSourceFact~new("REFERENCE_X3270", "SCREEN", "COLUMNS", "80", 100, "x3270:test"))
feed~addFact(.MvsSourceFact~new("REFERENCE_X3270", "CURSOR", "ROW", "22", 100, "x3270:test"))
feed~addFact(.MvsSourceFact~new("REFERENCE_X3270", "CURSOR", "COLUMN", "11", 100, "x3270:test"))
backend = .TestSourceBackend~new(feed)
composer = .MvsDiscoveryComposer~new
composer~addSource(.MvsDiscoverySource~new("REFERENCE_X3270", backend))
s = composer~discover("ED209Z")
call assertEqual "TSO_LOGON", s~terminalState, "reference screen scope"
call assertEqual "3278-2", s~capability("REFERENCE_X3270_MODEL"), "model"
call assertEqual "24", s~capability("REFERENCE_X3270_ROWS"), "rows"
call assertEqual "80", s~capability("REFERENCE_X3270_COLUMNS"), "columns"
call assertEqual "22", s~capability("REFERENCE_X3270_CURSOR_ROW"), "cursor row"
call assertEqual "11", s~capability("REFERENCE_X3270_CURSOR_COLUMN"), "cursor column"
if s~factsBySource("TERMINAL_MACHINE")~items <> 0 then do
  say "FAIL reference evidence leaked Terminal Machine authority"
  exit 1
end
say "PASS x3270 structural reference evidence"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

::class TestSourceBackend
::method init
  expose result
  use arg result
::method discover
  expose result
  use arg target
  return result

::requires "MvsIntention.cls"
