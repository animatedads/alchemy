/* Accounts spreadsheet export over the real management-review linked dataset. */
root = value("MININOTES_DB_ROOT",, "ENVIRONMENT")
if root = "" then raise syntax 93.900 array("MININOTES_DB_ROOT required")
outDir = value("MININOTES_EXPORT_ROOT",, "ENVIRONMENT")
if outDir = "" then outDir = root

app = .MiniNotesApp~new(root)
columns = .Array~new
call addColumn columns, "TPS Number", app~resolveReportColumn("Management Review Selection Item", "TPS Report.TPS Number")
call addColumn columns, "Owner", app~resolveReportColumn("Management Review Selection Item", "TPS Report.User")
call addColumn columns, "Cost", app~resolveReportColumn("Management Review Selection Item", "TPS Report.Cost")
call addColumn columns, "Selection Rationale", app~resolveReportColumn("Management Review Selection Item", "Selection Rationale")
ignore = app~installReportDefinition("Accounts Management TPS", "Management Review Selection Item", columns)

data = app~reportSpreadsheetData("Accounts Management TPS")
call assertTrue data \== .nil, "spreadsheet data created"
call assertEqual 12, data~rowCount, "twelve selected TPS rows exported"
call assertEqual 4, data~columnCount, "accounts projection has four columns"
call assertEqual "MONEY", data~types["Cost"], "cost remains typed money"
call assertTrue data~provenance["SOURCE_APP"] == app, "source app object retained as provenance"
call assertEqual "Management Review Selection Item", data~provenance["SOURCE_DOCUMENT_FORM"], "source form provenance"
call assertEqual "TPS-2026-101", data~rows[1]["TPS Number"], "relationship traversal feeds TPS number"
call assertEqual 1250.50, data~rows[1]["Cost"], "relationship traversal feeds typed cost"

xlsx = outDir || "/accounts-management-tps.xlsx"
csv = outDir || "/accounts-management-tps.csv"
exportResult = app~exportReportSpreadsheet("Accounts Management TPS", xlsx)
call assertEqual "EXPORTED", exportResult["STATUS"], "xlsx export status"
call assertEqual 12, exportResult["COUNT"], "xlsx export count"
exportResult = app~exportReportSpreadsheet("Accounts Management TPS", csv)
call assertEqual "EXPORTED", exportResult["STATUS"], "csv export status"

workbook = .SpreadsheetReader~open(xlsx)
catalog = .SpreadsheetRelationDiscoverer~new~discover(workbook)
relation = catalog~relations[1]
call assertEqual 12, relation~records~items, "xlsx round trip row count"
call assertEqual "TPS-2026-101", relation~records[1]["TPS Number"], "xlsx contains linked TPS number"
call assertEqual "1250.50", relation~records[1]["Cost"]~string, "xlsx contains cost"

ui = .MiniNotesCliUi~new(app)
ui~executeCommand("EXPORT Accounts Management TPS TO " || outDir || "/accounts-from-cli.xlsx")
call assertContains ui~status, "EXPORT: Accounts Management TPS", "CLI export command reports success"
call assertTrue stream(outDir || "/accounts-from-cli.xlsx", "C", "QUERY EXISTS") \== "", "CLI export created workbook"

say "PASS accounts spreadsheet export / linked traversal / typed interchange / XLSX round trip"
exit 0

::routine addColumn
  use strict arg columns, label, binding
  if binding = "" then raise syntax 93.900 array("Could not resolve export binding for " || label)
  column = .Directory~new
  column["LABEL"] = label
  column["BINDING"] = binding
  columns~append(column)
  return

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
