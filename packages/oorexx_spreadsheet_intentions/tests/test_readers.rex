parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

xlsx = .SpreadsheetReader~open(base || "/fixtures/nasty.xlsx")
call assertEq "XLSX", xlsx~format, "xlsx format"
call assertEq 3, xlsx~sheets~items, "xlsx sheet count"
call assertEq "Alice Morgan", xlsx~sheet("Customers")~cell("B2")~semanticValue, "shared string"
call assertEq "NUMBER", xlsx~sheet("Customers")~cell("D2")~valueType, "currency remains numeric"
call assertEq "$#,##0.00", xlsx~sheet("Customers")~cell("D2")~numberFormatCode, "currency style retained"
call assertEq "$1000", xlsx~sheet("Ledger")~cell("B2")~semanticValue, "currency-looking text remains text"
call assertEq "SUM(A2:A3)", xlsx~sheet("Ledger")~cell("C2")~formula, "xlsx formula retained"
call assertEq "3000", xlsx~sheet("Ledger")~cell("C2")~cachedValue, "xlsx cached formula result retained"

ods = .SpreadsheetReader~open(base || "/fixtures/nasty.ods")
call assertEq "ODS", ods~format, "ods format"
call assertEq 3, ods~sheets~items, "ods sheet count"
call assertEq "Alice Morgan", ods~sheet("Customers")~cell("B2")~semanticValue, "ods text"
call assertEq "NUMBER", ods~sheet("Customers")~cell("D2")~valueType, "ods currency numeric"
call assertEq "$1000", ods~sheet("Ledger")~cell("B2")~semanticValue, "ods currency-looking text remains text"
call assertEq "of:=SUM([.A2:.A3])", ods~sheet("Ledger")~cell("C2")~formula, "ods formula retained"

say "PASS test_readers"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::requires "SpreadsheetOpenFormats.cls"
