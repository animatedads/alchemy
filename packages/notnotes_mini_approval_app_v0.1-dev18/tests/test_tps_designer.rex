app = .MiniNotesApp~new
app~seedFive
ui = .MiniNotesCliUi~new(app)

ui~executeCommand("create a new document format called TPS Report")
call assertEqual "DESIGN", ui~mode, "designer starts"
ui~executeCommand("I need a field for the 'TPS Number'")
ui~executeCommand("I need a user")
ui~executeCommand("SAVE")

definition = app~node~documentDefinition("TPS Report/1")
call assertTrue definition \== .nil, "TPS definition installed"
call assertTrue definition~fieldDefinition("TPSNumber") \== .nil, "TPS Number field installed"
call assertEqual "IDENTIFIER", definition~fieldDefinition("TPSNumber")~semanticType, "TPS Number semantic type"
call assertTrue definition~fieldDefinition("User") \== .nil, "User field installed"
call assertEqual "USER_REFERENCE", definition~fieldDefinition("User")~semanticType, "User semantic type"
call assertTrue app~node~viewDefinition("TPS Reports/1") \== .nil, "TPS view installed"

ui~executeCommand("complete a tps report")
call assertEqual "COMPOSE", ui~mode, "compose starts case-insensitively"
ui~executeCommand("TPS-2026-001")
ui~executeCommand("codex")
call assertEqual "DETAIL", ui~mode, "completed document opens"
doc = app~selected
call assertEqual "TPS Report", doc~formName, "correct form"
call assertEqual "TPS-2026-001", doc~TPSNumber, "TPS number saved"
call assertEqual "codex", doc~User, "user saved"
call assertEqual "DRAFT", doc~ApprovalStatus, "new TPS is draft"

matches = app~query("TPS-2026-001")
call assertEqual 1, matches~items, "custom field searchable"
call assertEqual doc~documentId, matches[1]~documentId, "query returns TPS document"

say "PASS TPS designer and completion"
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

::requires 'src/MiniNotesCliUi.cls'
