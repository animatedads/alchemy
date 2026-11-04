/* test_ods_errors.rex - error cells read the same from ODS and XLSX.
 *
 * Fix and test: Claude (Opus 5.5), 2026-11-02, found by SLAM Piledriver (Architecture: Tom Dyer).
 * Fixtures: tests/fixtures/libreoffice_errors.ods and .xlsx, both written by LibreOffice 24.2.7.2 from one
 * source (packages/oorexx_slam_v0.1/tests/fixtures/piledriver/errors_book.fods).  LibreOffice stores an ODS
 * error cell as office:value-type="string" with calcext:value-type="error"; before the fix the ODS reader
 * gave TEXT for the cells the XLSX reader gives ERROR.
 */
parse source . . here
base = filespec("L", here)
call value "REXX_PATH", base || "/../src:" || value("REXX_PATH", , "ENVIRONMENT"), "ENVIRONMENT"

ods = .SpreadsheetReader~open(base || "/fixtures/libreoffice_errors.ods")
xlsx = .SpreadsheetReader~open(base || "/fixtures/libreoffice_errors.xlsx")
cases = .array~of("B2 #DIV/0!", "B3 #N/A", "B4 #VALUE!", "B5 #NAME?", "C2 #DIV/0!", "C3 #DIV/0!")
loop c over cases
  parse var c addr shown
  call assertEq "ERROR", ods~sheet("Data")~cell(addr)~valueType, "ods" addr "is ERROR"
  call assertEq "ERROR", xlsx~sheet("Data")~cell(addr)~valueType, "xlsx" addr "is ERROR"
  call assertEq shown, ods~sheet("Data")~cell(addr)~rawValue, "ods" addr "value"
  call assertEq shown, ods~sheet("Data")~cell(addr)~semanticValue, "ods" addr "semantic value"
end
call assertEq "ERROR", ods~sheet("Summary")~cell("A2")~valueType, "ods Summary!A2 (error passed to the second sheet) is ERROR"
call assertEq "of:=1/0", ods~sheet("Data")~cell("B2")~formula, "ods error cell keeps its formula"
call assertEq "NUMBER", ods~sheet("Data")~cell("B6")~valueType, "ods clean formula stays NUMBER"
call assertEq "4", ods~sheet("Data")~cell("B6")~rawValue, "ods clean formula value"
call assertEq "TEXT", ods~sheet("Data")~cell("B7")~valueType, "ods typed '#N/A' with no formula stays TEXT"

say "PASS test_ods_errors"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected == actual then return
  say "FAIL" label "expected=" expected "actual=" actual
  exit 1

::requires "SpreadsheetOpenFormats.cls"
