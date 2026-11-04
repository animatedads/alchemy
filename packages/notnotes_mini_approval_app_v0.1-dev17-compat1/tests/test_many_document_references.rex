root = value("MININOTES_TEST_ROOT",, "ENVIRONMENT")
app = .MiniNotesApp~new(root)
ui = .MiniNotesCliUi~new(app)

ui~executeCommand("create a new document format called TPS Report")
ui~executeCommand("I need a field for the TPS Number")
ui~executeCommand("I need a field for the Cost")
ui~executeCommand("SAVE")

ui~executeCommand("create a new document format called Management Review Selection")
ui~executeCommand("I need a field for the Name")
ui~executeCommand("I need many TPS Reports")
ui~executeCommand("SAVE")

call assertEqual "TPS Report", app~relationshipTarget("Management Review Selection", "TPSReports"), "multi-reference target"
call assertEqual "MANY", app~relationshipCardinality("Management Review Selection", "TPSReports"), "multi-reference cardinality"

fields = app~userFormatFields("TPS Report")
values = .Directory~new; values["TPSNumber"] = "TPS-2026-101"; values["Cost"] = "1250.50"
tps1 = app~createUserDocument("TPS Report", fields, values)
values = .Directory~new; values["TPSNumber"] = "TPS-2026-102"; values["Cost"] = "800"
tps2 = app~createUserDocument("TPS Report", fields, values)
values = .Directory~new; values["TPSNumber"] = "TPS-2026-103"; values["Cost"] = "449.50"
tps3 = app~createUserDocument("TPS Report", fields, values)

selectionValues = .Directory~new
selectionValues["Name"] = "Quarterly Management Review"
selectionValues["TPSReports"] = tps1~DocKey || ", " || tps2~DocKey || ", " || tps3~DocKey
selection = app~createUserDocument("Management Review Selection", app~userFormatFields("Management Review Selection"), selectionValues)
call assertTrue selection \== .nil, "multi-linked selection created"
refs = app~referencedDocuments(selection, "TPSReports")
call assertEqual 3, refs~items, "three references resolve"
call assertEqual tps1~DocKey, refs[1]~DocKey, "first stable reference"
call assertEqual tps2~DocKey, refs[2]~DocKey, "second stable reference"
call assertEqual tps3~DocKey, refs[3]~DocKey, "third stable reference"

refText = app~renderReferencesFor(selection)
call assertContains refText, "TPS-2026-101", "first referenced TPS projects"
call assertContains refText, "TPS-2026-102", "second referenced TPS projects"
call assertContains refText, "TPS-2026-103", "third referenced TPS projects"

columns = .Array~new
column = .Directory~new; column["LABEL"] = "Name"; column["BINDING"] = "Name"; columns~append(column)
column = .Directory~new; column["LABEL"] = "TPS Numbers"; column["BINDING"] = "TPSReports.TPSNumber"; columns~append(column)
column = .Directory~new; column["LABEL"] = "TPS Costs"; column["BINDING"] = "TPSReports.Cost"; columns~append(column)
app~installReportDefinition("Management Selection Summary", "Management Review Selection", columns, .Array~new)
report = app~reportDefinition("Management Selection Summary")
reportDocs = app~reportDocuments(report)
call assertEqual 1, reportDocs~items, "selection report row count"
call assertEqual "TPS-2026-101, TPS-2026-102, TPS-2026-103", app~reportValue(reportDocs[1], "TPSReports.TPSNumber"), "report traverses many reference"
call assertEqual "1250.50, 800, 449.50", app~reportValue(reportDocs[1], "TPSReports.Cost"), "report traverses many costs"

values = .Directory~new; values["TPSNumber"] = "TPS-2026-104"; values["Cost"] = "50"
tps4 = app~createUserDocument("TPS Report", fields, values)
app~select(selection~DocKey)
ui~executeCommand("LINK TPS Reports TO TPS-2026-104")
call assertEqual 4, app~referencedDocuments(selection, "TPSReports")~items, "LINK appends a many reference"
ui~executeCommand("UNLINK TPS Reports FROM TPS-2026-102")
call assertEqual 3, app~referencedDocuments(selection, "TPSReports")~items, "UNLINK removes one many reference"
call assertEqual "TPS-2026-101, TPS-2026-103, TPS-2026-104", app~reportValue(selection, "TPSReports.TPSNumber"), "report sees link mutation"

subColumns = .Array~new
subColumn = .Directory~new; subColumn["NAME"] = "SelectionName"; subColumn["LABEL"] = "Selection"; subColumn["BINDING"] = "Name"; subColumns~append(subColumn)
app~installSubviewDefinition("TPS Report", "Management Selections", "Management Review Selection", "TPSReports", subColumns)
subview = app~subviewDefinitionByIdentity("TPS Report:Management Selections")
subRows = app~subviewRows(tps3, subview)
call assertEqual 1, subRows~items, "reverse subview matches membership in many reference"
call assertEqual "Quarterly Management Review", subRows[1]["SelectionName"], "reverse subview projects parent selection"

ignore = app~persistNow
app2 = .MiniNotesApp~new(root)
selection2 = app2~byKey(selection~DocKey)
call assertEqual "MANY", app2~relationshipCardinality("Management Review Selection", "TPSReports"), "cardinality survives reload"
refs2 = app2~referencedDocuments(selection2, "TPSReports")
call assertEqual 3, refs2~items, "references survive reload"
call assertEqual "TPS-2026-101, TPS-2026-103, TPS-2026-104", app2~reportValue(selection2, "TPSReports.TPSNumber"), "many traversal survives reload"
subview2 = app2~subviewDefinitionByIdentity("TPS Report:Management Selections")
call assertEqual 1, app2~subviewRows(app2~byKey(tps3~DocKey), subview2)~items, "reverse subview survives reload"

say "PASS Mini NotNotes first-class MANY document references / report traversal / reverse subview / reload"
exit 0

assertTrue: procedure
  use arg condition, label
  if \condition then call fail label
  return

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then call fail label || " expected=" || expected || " actual=" || actual
  return

assertContains: procedure
  use arg haystack, needle, label
  if haystack~pos(needle) = 0 then call fail label || " missing=" || needle
  return

fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::requires 'src/MiniNotesCliUi.cls'
