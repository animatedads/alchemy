/* Management-review acceptance over the real delivered linked dataset. */
root = value("MININOTES_DB_ROOT",, "ENVIRONMENT")
if root = "" then raise syntax 93.900 array("MININOTES_DB_ROOT required")

app = .MiniNotesApp~new(root)
selection = app~byKey("MRS-0001")
consultant = app~byKey("MCR-0001")
call assertTrue selection \== .nil, "management selection loads"
call assertTrue consultant \== .nil, "consultant report loads"
call assertEqual "PENDING APPROVAL", selection~ApprovalStatus, "selection durable status"
call assertEqual "PENDING APPROVAL", consultant~ApprovalStatus, "consultant durable status"

selectionSubview = app~subviewDefinitionByIdentity("Management Review Selection:Selected TPS Reports")
call assertTrue selectionSubview \== .nil, "selection subview loads"
selectionRows = app~subviewRows(selection, selectionSubview)
call assertEqual 12, selectionRows~items, "selection contains twelve TPS links"
selectedCost = app~subviewColumnValue(selectionRows, selectionSubview, "TotalSelectedCost")
call assertEqual 4547.75, selectedCost, "selection cost aggregate"
call assertEqual "TPS-2026-101", selectionRows[1]["TPSNumber"], "linked TPS number traversal"

findingsSubview = app~subviewDefinitionByIdentity("Management Consultant Report:TPS Findings")
call assertTrue findingsSubview \== .nil, "consultant findings subview loads"
findingRows = app~subviewRows(consultant, findingsSubview)
call assertEqual 12, findingRows~items, "consultant has twelve linked findings"
call assertEqual "TPS-2026-101", findingRows[1]["TPSNumber"], "consultant finding traverses TPS reference"

review = app~byKey("TRR-0001")
call assertTrue review \== .nil, "TPS review loads"
reviewTarget = app~referencedDocument(review, "TheTPSReport")
call assertTrue reviewTarget \== .nil, "TPS review dereferences"
call assertEqual "TR-0001", reviewTarget~DocKey, "review points to stable TPS key"

binding = app~resolveReportColumn("Management Review Selection Item", "TPS Report.TPS Number")
call assertEqual "TPSReport.TPSNumber", binding, "saved report dotted binding canonicalises relationship path"
ownerBinding = app~resolveReportColumn("Management Review Selection Item", "TPS Report.User")
call assertEqual "TPSReport.User", ownerBinding, "saved report can traverse owner"
columns = .Array~new
column = .Directory~new
column["LABEL"] = "TPS Number"
column["BINDING"] = binding
columns~append(column)
column = .Directory~new
column["LABEL"] = "Owner"
column["BINDING"] = ownerBinding
columns~append(column)
ignore = app~installReportDefinition("Linked Management TPS", "Management Review Selection Item", columns)
preview = app~reportPreview(app~reportDefinition("Linked Management TPS"))
call assertContains preview, "TPS-2026-101", "dotted report emits linked TPS number"
call assertContains preview, "codex", "dotted report emits linked TPS owner"

/* Prove list projection refreshes immediately after a lifecycle action. */
ui = .MiniNotesCliUi~new(app)
ui~executeCommand("select MCF-0001")
call assertEqual "DRAFT", ui~screen~table~row(ui~screen~table~selected)[2][4], "fixture finding begins draft"
ui~executeCommand("submit management finding projection check")
call assertEqual "PENDING APPROVAL", app~byKey("MCF-0001")~ApprovalStatus, "submit changes document"
call assertEqual "PENDING APPROVAL", ui~screen~table~row(ui~screen~table~selected)[2][4], "visible row refreshes immediately"

ignore = app~persistNow
app2 = .MiniNotesApp~new(root)
call assertEqual "PENDING APPROVAL", app2~byKey("MCF-0001")~ApprovalStatus, "projection-test submission survives restart"
call assertTrue app2~reportDefinition("Linked Management TPS") \== .nil, "dotted report survives restart"
preview2 = app2~reportPreview(app2~reportDefinition("Linked Management TPS"))
call assertContains preview2, "TPS-2026-112", "reloaded dotted report traverses all linked TPS documents"

say "PASS management review fixture / dotted reports / live lifecycle projection"
exit 0

::routine assertEqual
  use strict arg expected, actual, label
  if expected \= actual then raise syntax 93.900 array(label || ": expected=" || expected || " actual=" || actual)
  return

::routine assertTrue
  use strict arg condition, label
  if \condition then raise syntax 93.900 array(label)
  return

::routine assertContains
  use strict arg text, needle, label
  if text~pos(needle) = 0 then raise syntax 93.900 array(label || ": missing=" || needle)
  return

::requires 'src/MiniNotesCliUi.cls'
::requires 'vendor/cliui/rexx/CliUiHeadlessRenderer.cls'
