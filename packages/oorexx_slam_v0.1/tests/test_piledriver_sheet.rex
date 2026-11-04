/* test_piledriver_sheet.rex - Piledriver v0.1: error cells in workbooks, and where each one starts.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-11-02.
 * REXX_PATH: this package's src and oorexx_spreadsheet_intentions/src.
 *
 * The fixtures: tests/fixtures/piledriver/errors_book.fods (written by hand), saved by LibreOffice 24.2.7.2 as
 * errors_book.ods and errors_book.xlsx (soffice --headless --convert-to ods / xlsx).  So both files are as
 * LibreOffice writes them.  Data!B2..B5 are four errors (=1/0, =NA(), =1+"x", =NOSUCHFUNC(1)); C2 = B2*2 and
 * C3 = C2+1 pass the first one on; Summary!A2 = Data!C3*1 takes it to the second sheet; B6, C6, Summary!A1, A3
 * are clean formulas; B7 is "#N/A" typed with no formula.
 * Section 3 builds a workbook as a reader made before the ODS fix gives it (error cells as TEXT).
 */
signal on syntax name failed
.local['PSPASS'] = 0
.local['PSFAIL'] = 0
dir = 'tests/fixtures/piledriver/'

say '== 1. the two formats store an error cell in two ways (measured)'
wbO = .SpreadsheetReader~open(dir || 'errors_book.ods')
wbX = .SpreadsheetReader~open(dir || 'errors_book.xlsx')
cO = wbO~sheet('Data')~cell('B2'); cX = wbX~sheet('Data')~cell('B2')
say '  ods  Data!B2: valueType' cO~valueType 'value' cO~rawValue 'formula' cO~formula
say '  xlsx Data!B2: valueType' cX~valueType 'value' cX~rawValue 'formula' cX~formula
call check cX~valueType == 'ERROR', 'xlsx: the reader says ERROR (t="e")'
call check cO~valueType == 'ERROR' & cO~rawValue == '#DIV/0!', 'ods: the reader says ERROR "#DIV/0!" (calcext:value-type="error"; TEXT before 2026-11-02)'

do f over .array~of('errors_book.ods', 'errors_book.xlsx')
  say ''
  say '== 2.' f
  s = .PiledriverSheet~new~readFile(dir || f)
  do l over s~report
    say l
  end
  how = 'STORED'
  roots = .array~new; passed = .array~new
  do e over s~errors
    if e['ROOT'] then roots~append(e['KEY'])
    else passed~append(e['KEY'])
  end
  call check s~errors~items == 7, f || ': 7 error cells'
  call check roots~makeString('L', ' ') == 'Data!B2 Data!B3 Data!B4 Data!B5', f || ': roots B2 B3 B4 B5 (' || roots~makeString('L', ' ') || ')'
  call check passed~makeString('L', ' ') == 'Data!C2 Data!C3 Summary!A2', f || ': passed on: C2, C3, Summary!A2'
  call check s~byKey['Summary!A2']['ROOTS']~makeString('L', ' ') == 'Data!B2', f || ': Summary!A2 goes back to Data!B2, through C3 and C2'
  call check s~byKey['Data!C3']['FROM']~makeString('L', ' ') == 'Data!C2', f || ': C3 is passed on from C2'
  allHow = .true
  do e over s~errors
    if e['HOW'] \== how then allHow = .false
  end
  call check allHow, f || ': each error found as' how
  call check s~typed~items == 1 & s~typed[1]['ADDRESS'] == 'B7', f || ': B7 "#N/A" with no formula is typed text, not an error'
  call check s~byKey~hasIndex('Data!B6') == .false & s~byKey~hasIndex('Summary!A3') == .false, f || ': clean formulas (B6, Summary!A3 = SUM over B6:C6) are not errors'
end

say ''
say '== 3. a reader that keeps the text only (a copy made before the ODS fix): COMPUTED'
wb = .SpreadsheetWorkbook~new('old reader', 'ODS')
sh = .SpreadsheetSheet~new('Data')
call put sh, 'B2', 'TEXT', '#DIV/0!', 'of:=1/0'
call put sh, 'C2', 'TEXT', '#DIV/0!', 'of:=[.B2]*2'
call put sh, 'B6', 'NUMBER', '4', 'of:=2+2'
call put sh, 'B7', 'TEXT', '#N/A', ''
wb~addSheet(sh)
s = .PiledriverSheet~new~readWorkbook(wb, 'old reader', 'ODS')
call check s~errors~items == 2 & s~errors[1]['HOW'] == 'COMPUTED', 'TEXT "#DIV/0!" with a formula is an error, found as COMPUTED'
call check s~byKey['Data!C2']['ROOTS']~makeString('L', ' ') == 'Data!B2', 'C2 is passed on from the root B2'
call check s~typed~items == 1, 'TEXT "#N/A" with no formula is typed'

say ''
say '== 4. references'
s = .PiledriverSheet~new
call ref s, 'B2*2', 'HERE!B2'
call ref s, 'SUM(Data!B6:C6)', 'DATA!B6 DATA!C6'
call ref s, "'My Sheet'!A1+$B$2", 'MY SHEET!A1 HERE!B2'
call ref s, 'LOG10(A1)+"B2"', 'HERE!A1'
call ref s, 'of:=SUM([$Data.B6:.C6])', 'DATA!B6 DATA!C6'
call ref s, 'of:=[.C2]+1', 'HERE!C2'

say ''
say 'PILEDRIVER SHEET TEST:' word('PASS FAIL', 1 + (.local['PSFAIL'] > 0)) '(' || .local['PSPASS'] 'passed,' .local['PSFAIL'] 'failed)'
exit .local['PSFAIL'] > 0

put: procedure
  use arg sh, addr, vtype, value, formula
  at = .SpreadsheetAddress~rowColumn(addr)
  c = .SpreadsheetCell~new(addr, at[1], at[2])
  c~valueType = vtype; c~rawValue = value; c~textValue = value; c~formula = formula
  sh~putCell(c)
  return

ref: procedure
  use arg s, formula, want
  got = s~references(formula, 'Here')~makeString('L', ' ')~upper
  call check got == want, formula '->' got
  return

check: procedure
  use arg ok, text
  if ok then do
    .local['PSPASS'] = .local['PSPASS'] + 1
    say 'PASS ' text
  end
  else do
    .local['PSFAIL'] = .local['PSFAIL'] + 1
    say 'FAIL ' text
  end
  return

failed:
  say 'PILEDRIVER SHEET TEST: ERROR' condition('C') 'rc' rc 'line' sigl || ':' condition('D')
  exit 2

::requires 'PiledriverSheet.cls'
