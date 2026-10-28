app = .MiniNotesApp~new
app~seedFive

table = app~tableFor(app~allDocuments)
call assertEqual 5, table~count, "table row count"
call assertEqual "PR-1001", table~row(1)[2][2], "first stable key"

app~select("PR-1002")
doc = app~documentModel(app~selected)
call assertTrue doc~isA(.CliUiDocument), "detail uses CliUiDocument"
call assertTrue doc~text~pos("STATUS: PENDING APPROVAL") > 0, "detail status"
call assertTrue app~trace~entries~items >= 2, "semantic trace records projection/selection"

say "PASS test_cli_projection"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected="expected "actual="actual
  exit 1

assertTrue: procedure
  use arg actual, label
  if actual then return
  say "FAIL" label
  exit 1

::requires 'src/MiniNotesApp.cls'
