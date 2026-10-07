parse source . . here
base = filespec("L", here)
workbook = .SpreadsheetReader~open(base || "/fixtures/nasty.xlsx")
env = .SpreadsheetIntentEnvironment~new(workbook)

response = env~input("what sheets are in this workbook")
call assertEq "READY", response~decision~status, "list sheets ready"
call assertEq "LIST_SPREADSHEET_SHEETS", response~decision~registration~id, "list sheets intention"
call assertEq 3, response~data~items, "sheet rows"

response = env~input("describe customers")
call assertEq "READY", response~decision~status, "describe ready"
call assertEq "DESCRIBE_SPREADSHEET_RELATION", response~decision~registration~id, "describe intention"
call assertEq 5, response~data~items, "describe fields"

response = env~input("show customers in Rochdale")
call assertEq "READY", response~decision~status, "search ready"
call assertEq "SEARCH_SPREADSHEET_RECORDS", response~decision~registration~id, "search intention"
call assertEq 2, response~data~items, "value-derived city filter"

response = env~input("show customers named smith")
call assertEq "READY", response~decision~status, "named search ready"
call assertEq 2, response~data~items, "name contains filter"

response = env~input("show customers credit limit > 800")
call assertEq "READY", response~decision~status, "numeric filter ready"
call assertEq 2, response~data~items, "numeric comparator"

response = env~input("count customers by city")
call assertEq "READY", response~decision~status, "group count ready"
call assertEq 2, response~data~at("Rochdale"), "Rochdale count"
call assertEq 1, response~data~at("Manchester"), "Manchester count"

response = env~input("total credit limit customers")
call assertEq "READY", response~decision~status, "sum ready"
call assertEq "SUM_SPREADSHEET_FIELD", response~decision~registration~id, "sum intention"
call assertEq 4250, response~data, "sum result"

response = env~input("find formulas")
call assertEq "READY", response~decision~status, "formula audit ready"
call assertEq 2, response~data~items, "formula count"

response = env~input("find type hazards")
call assertEq "READY", response~decision~status, "type audit ready"
call assertTrue response~data~items >= 3, "hazards returned"

response = env~input("list relationships")
call assertEq "READY", response~decision~status, "relationships ready"
call assertEq "LIST_SPREADSHEET_RELATIONSHIPS", response~decision~registration~id, "relationships intention"
call assertEq 1, response~data~items, "relationships returned"

response = env~input("show orders for customers in Rochdale")
call assertEq "READY", response~decision~status, "related search ready"
call assertEq "SEARCH_RELATED_SPREADSHEET_RECORDS", response~decision~registration~id, "related search intention"
call assertEq 3, response~data~items, "orders for Rochdale customers"

response = env~input("using spreadsheet show customers in Rochdale")
call assertEq "READY", response~decision~status, "explicit sphere ready"
call assertEq 2, response~data~items, "sphere search result"

regionWorkbook = .SpreadsheetReader~open(base || "/fixtures/regions.xlsx")
regionEnv = .SpreadsheetIntentEnvironment~new(regionWorkbook)

response = regionEnv~input("what tables")
call assertEq "READY", response~decision~status, "region catalog ready"
call assertEq "LIST_SPREADSHEET_RELATIONS", response~decision~registration~id, "region catalog intention"
call assertEq 2, response~data~items, "region catalog count"

response = regionEnv~input("show customers in Rochdale")
call assertEq "READY", response~decision~status, "region customer search ready"
call assertEq 2, response~data~items, "region customer search"

response = regionEnv~input("show orders for customers in Rochdale")
call assertEq "READY", response~decision~status, "region related search ready"
call assertEq 3, response~data~items, "region related result"

response = regionEnv~input("find type hazards")
call assertEq "READY", response~decision~status, "region diagnostics ready"
call assertTrue response~data~items >= 3, "region diagnostics include multi-region summaries"

say "PASS test_intentions"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

assertTrue: procedure
  use arg condition, label
  if condition then return
  say "FAIL" label
  exit 1

::requires "SpreadsheetIntentions.cls"
