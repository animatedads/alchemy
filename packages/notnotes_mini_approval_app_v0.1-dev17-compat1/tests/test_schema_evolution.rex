root = value("MININOTES_TEST_ROOT",, "ENVIRONMENT")
app = .MiniNotesApp~new(root)
ui = .MiniNotesCliUi~new(app)

ui~executeCommand("create a new document format called TPS Report")
ui~executeCommand("I need a field for the TPS Number")
ui~executeCommand("I need a user")
ui~executeCommand("I need a field for the Cost")
ui~executeCommand("SAVE")

fields = app~userFormatFields("TPS Report")
values = .Directory~new
values["TPSNumber"] = "TPS-2026-201"
values["User"] = "alice"
values["Cost"] = "125.50"
tps1 = app~createUserDocument("TPS Report", fields, values)
values = .Directory~new
values["TPSNumber"] = "TPS-2026-202"
values["User"] = "bob"
values["Cost"] = "275"
tps2 = app~createUserDocument("TPS Report", fields, values)
call assertTrue tps1 \== .nil, "first pre-evolution document"
call assertTrue tps2 \== .nil, "second pre-evolution document"

ui~executeCommand("ALTER TPS Report")
call assertEqual "DESIGN", ui~mode, "ALTER enters design mode"
call assertContains ui~status, "Improving TPS Report", "ALTER identifies installed format"
ui~executeCommand("I need a field for the Department")
ui~executeCommand("SAVE")
call assertContains ui~status, "Saved document format TPS Report", "evolved format saved"

spec = app~userFormatFieldSpec("TPS Report", "Department")
call assertTrue spec \== .nil, "new field installed"
call assertEqual "TEXT", spec["TYPE"], "new field semantic type"
call assertTrue tps1~hasField("Department"), "existing first document migrated"
call assertTrue tps2~hasField("Department"), "existing second document migrated"
call assertEqual "", tps1~field("Department"), "existing field starts blank"
call assertEqual "TPS-2026-201", tps1~field("TPSNumber"), "existing data preserved"
call assertEqual "125.50", tps1~field("Cost"), "existing money preserved"

app~select(tps1~DocKey)
ui~executeCommand("SET Department = Operations")
call assertEqual "Operations", tps1~field("Department"), "new field editable on existing document"

ui~executeCommand("complete a TPS Report")
ui~executeCommand("TPS-2026-203")
ui~executeCommand("carol")
ui~executeCommand("325")
ui~executeCommand("Finance")
call assertContains ui~status, "Completed", "new document composed from evolved schema"
tps3 = app~selected
call assertEqual "Finance", tps3~field("Department"), "new document captures evolved field"

columns = .Array~new
column = .Directory~new; column["LABEL"] = "TPS Number"; column["BINDING"] = "TPSNumber"; columns~append(column)
column = .Directory~new; column["LABEL"] = "Department"; column["BINDING"] = "Department"; columns~append(column)
app~installReportDefinition("TPS By Department", "TPS Report", columns, .Array~new)
call assertEqual "Operations", app~reportValue(tps1, "Department"), "report binds evolved field"
call assertEqual "Finance", app~reportValue(tps3, "Department"), "report sees evolved new document"

badFields = app~userFormatFields("TPS Report")
badFields[1]["TYPE"] = "MONEY"
refused = app~evolveUserFormat("TPS Report", badFields)
call assertEqual "NON_ADDITIVE_CHANGE", refused["STATUS"], "existing field contract change refused"
call assertEqual "IDENTIFIER", app~userFormatFields("TPS Report")[1]["TYPE"], "refused change leaves schema intact"

ignore = app~persistNow
app2 = .MiniNotesApp~new(root)
call assertTrue app2~userFormatFieldSpec("TPS Report", "Department") \== .nil, "evolved schema survives reload"
call assertEqual "Operations", app2~byKey(tps1~DocKey)~field("Department"), "edited migrated field survives reload"
call assertEqual "Finance", app2~byKey(tps3~DocKey)~field("Department"), "new document evolved field survives reload"
report = app2~reportDefinition("TPS By Department")
call assertTrue report \== .nil, "report over evolved schema survives reload"
call assertEqual "Operations", app2~reportValue(app2~byKey(tps1~DocKey), "Department"), "report binding survives reload"

say "PASS Mini NotNotes additive schema evolution / existing-document migration / editing / report binding / reload"
exit 0

assertEqual: procedure
  parse arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertTrue: procedure
  parse arg condition, label
  if condition then return
  say "FAIL" label
  exit 1

assertContains: procedure
  parse arg haystack, needle, label
  if pos(needle, haystack) > 0 then return
  say "FAIL" label "missing=" needle "in=" haystack
  exit 1

::requires "src/MiniNotesCliUi.cls"
