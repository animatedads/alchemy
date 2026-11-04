/* PiledriverSheet.cls - Piledriver v0.1: error cells in a workbook (XLSX or ODS), and where each one starts.
 *
 * Architecture: Tom Dyer (Piledriver: logs, tables and sheets; in a workbook an error is a value TYPE in a cell,
 * and it spreads along formulas).  Code: Claude (Opus 5.5), 2026-11-02.
 * Reading: SpreadsheetReader from oorexx_spreadsheet_intentions (on REXX_PATH): Piledriver does not read the
 * zip packages itself.
 *
 * Measured on LibreOffice 24.2.7.2 (tests/fixtures/piledriver/errors_book.fods, saved by it as .ods and .xlsx):
 *   XLSX stores an error cell as t="e"; ODS stores it as office:value-type="string" with
 *   calcext:value-type="error" and the text "#DIV/0!".  SpreadsheetReader read only office:value-type, so the
 *   same four errors were ERROR from XLSX and TEXT from ODS; it reads calcext:value-type since 2026-11-02
 *   (oorexx_spreadsheet_intentions, tests/test_ods_errors.rex).  Copies of that reader made before the fix
 *   (notnotes_mini_approval_app's vendor/spreadsheet) still give TEXT.
 * So an error cell is found two ways, and each is named:
 *   STORED    the reader says ERROR
 *   COMPUTED  the cell has a formula, and its value is a spreadsheet error literal (#DIV/0!, #N/A, Err:502 ...):
 *             for a reader that keeps the text only
 * A cell that holds an error literal with NO formula was typed: it is listed apart (TYPED), not as an error.
 *
 * Then the formulas: each error cell's references (B2, Data!C3, $B$2, SUM(Data!B6:C6); ODS [.B2], [$Data.C3],
 * [$Data.B6:.C6]) are read, ranges filled in.  An error cell that references another error cell is PASSED ON
 * from it; an error cell whose references hold no error is a ROOT: where the error starts.  Each passed-on
 * error is traced back to its roots.
 */

::requires 'PiledriverWords.cls'
::requires 'SpreadsheetOpenFormats.cls'

::class PiledriverSheet public
::attribute name unguarded
::attribute format unguarded
::attribute sheetNames unguarded
::attribute errors unguarded
::attribute typed unguarded
::attribute byKey unguarded
::attribute cellCount unguarded
::attribute formulaCount unguarded

::method init
  expose errors typed byKey cellCount formulaCount sheetNames
  errors = .array~new; typed = .array~new; byKey = .directory~new
  cellCount = 0; formulaCount = 0; sheetNames = .array~new

::method readFile
  use strict arg path
  return self~readWorkbook(.SpreadsheetReader~open(path), path, filespec('E', path)~upper)

/* A workbook already in memory (a SpreadsheetWorkbook): LABEL names it, FORMAT says what it was read from. */
::method readWorkbook
  expose name format sheetNames errors typed byKey cellCount formulaCount
  use strict arg wb, label = 'workbook', fmt = 'UNKNOWN'
  name = label
  format = fmt
  sheetNames = wb~sheetNames
  /* every cell, in sheet order, then row, then column */
  do sn over sheetNames
    sh = wb~sheet(sn)
    ordered = .array~new
    do c over sh~cells
      ordered~append(c~row~right(9, '0') || c~column~right(5, '0') || '00'x || c~address)
    end
    ordered = ordered~sort
    do o over ordered
      parse var o . '00'x addr
      c = sh~cell(addr)
      cellCount += 1
      text = c~textValue
      if text == '' then text = c~rawValue
      if c~formula \== '' then formulaCount += 1
      how = ''
      if c~valueType == 'ERROR' then how = 'STORED'
      else if c~formula \== '' then if .PiledriverWords~sheetError(text~strip) then how = 'COMPUTED'
      if how == '' then do
        if c~formula == '' then if .PiledriverWords~sheetError(text~strip) then do
          t = .directory~new
          t['SHEET'] = sn; t['ADDRESS'] = c~address; t['VALUE'] = text~strip
          typed~append(t)
        end
        iterate
      end
      e = .directory~new
      e['SHEET'] = sn; e['ADDRESS'] = c~address; e['KEY'] = sn || '!' || c~address~upper
      e['VALUE'] = text~strip; e['FORMULA'] = c~formula; e['HOW'] = how
      e['REFS'] = self~references(c~formula, sn)
      errors~append(e)
      byKey[e['KEY']] = e
    end
  end
  do e over errors
    from = .array~new
    do ref over e['REFS']
      if byKey~hasIndex(ref) then if from~index(ref) == .nil then from~append(ref)
    end
    e['FROM'] = from
    e['ROOT'] = from~items == 0
  end
  do e over errors
    e['ROOTS'] = self~rootsOf(e['KEY'], .directory~new)
  end
  return self

/* The roots behind KEY: itself when it is a root, else the roots of each error it is passed on from. */
::method rootsOf
  expose byKey
  use strict arg key, seen
  out = .array~new
  if seen~hasIndex(key) then return out          /* a cycle: stop */
  seen[key] = .true
  e = byKey[key]
  if e['ROOT'] then do
    out~append(key)
    return out
  end
  do f over e['FROM']
    do r over self~rootsOf(f, seen)
      if out~index(r) == .nil then out~append(r)
    end
  end
  return out

/* The cells a formula references, as SHEET!A1 (upper case), ranges filled in.  XLSX: B2, $B$2, Data!B6,
   'My Sheet'!A1, B6:C6.  ODS (of:=...): [.B2], [$Data.B6], [.B6:.C6], [$Data.B6:.C6].  Text in "quotes" and
   function names (LOG10( ) are not references. */
::method references
  use strict arg formula, sheet
  out = .array~new
  f = formula
  if f~left(3) == 'of:' then do
    /* ODS: references are in [ ] */
    do while f~pos('[') > 0
      a = f~pos('['); b = f~pos(']', a)
      if b == 0 then leave
      inner = f~substr(a + 1, b - a - 1)
      f = f~substr(b + 1)
      parse var inner first ':' second
      s1 = sheet
      c1 = self~odsPart(first, sheet, s1)
      s1 = c1~word(1); a1 = c1~word(2)
      if second == '' then call add s1, a1, a1
      else do
        c2 = self~odsPart(second, s1, s1)
        call add s1, a1, c2~word(2)
      end
    end
    return out
  end
  /* XLSX: scan, outside "strings" */
  i = 1; n = f~length; inQuote = .false
  do while i <= n
    ch = f~substr(i, 1)
    if ch == '"' then do
      inQuote = \inQuote
      i += 1
      iterate
    end
    if inQuote then do
      i += 1
      iterate
    end
    /* a token: a run of name characters, maybe a 'quoted sheet', then !, then a cell, maybe :cell */
    if ch == "'" then do
      q = f~pos("'", i + 1)
      if q == 0 then leave
      if f~substr(q + 1, 1) == '!' then do
        sname = f~substr(i + 1, q - i - 1)
        j = q + 2
        parse value self~cellAt(f, j) with cellA nextJ
        if cellA \== '' then do
          parse value self~rangeEnd(f, nextJ) with cellB nextJ
          if cellB == '-' then cellB = cellA
          call add sname, cellA, cellB
          i = nextJ
          iterate
        end
      end
      i = q + 1
      iterate
    end
    if self~nameChar(ch) then do
      if i > 1 then if self~nameChar(f~substr(i - 1, 1)) then do
        i += 1
        iterate
      end
      j = i
      do while j <= n
        if \self~nameChar(f~substr(j, 1)) then leave
        j += 1
      end
      word = f~substr(i, j - i)
      if f~substr(j, 1) == '!' then do
        parse value self~cellAt(f, j + 1) with cellA nextJ
        if cellA \== '' then do
          parse value self~rangeEnd(f, nextJ) with cellB nextJ
          if cellB == '-' then cellB = cellA
          call add word, cellA, cellB
          i = nextJ
          iterate
        end
      end
      parse value self~cellAt(f, i) with cellA nextJ
      if cellA \== '' then if f~substr(nextJ, 1) \== '(' then do
        parse value self~rangeEnd(f, nextJ) with cellB nextJ
        if cellB == '-' then cellB = cellA
        call add sheet, cellA, cellB
        i = nextJ
        iterate
      end
      i = j
      iterate
    end
    i += 1
  end
  return out

  add:
    use arg s, fromCell, toCell
    s = s~strip('B', "'")~strip('L', '$')
    rc1 = .SpreadsheetAddress~rowColumn(fromCell)
    rc2 = .SpreadsheetAddress~rowColumn(toCell)
    if rc1 == .nil then return
    if rc2 == .nil then return
    r1 = rc1[1]; c1 = rc1[2]; r2 = rc2[1]; c2 = rc2[2]
    if (abs(r2 - r1) + 1) * (abs(c2 - c1) + 1) > 10000 then return
    do rr = min(r1, r2) to max(r1, r2)
      do cc = min(c1, c2) to max(c1, c2)
        k = s || '!' || .SpreadsheetAddress~fromRowColumn(rr, cc)~upper
        if out~index(k) == .nil then out~append(k)
      end
    end
    return

/* One side of an ODS reference: ".B2" or "$Data.B6" or "Data.B6".  Returns "SHEET A1". */
::method odsPart
  use strict arg part, defaultSheet, previous
  p = part~strip
  dot = p~lastPos('.')
  s = previous
  if dot > 1 then s = p~left(dot - 1)~strip('L', '$')~strip('B', "'")
  cellRef = p~substr(dot + 1)~changeStr('$', '')
  return s cellRef~upper

/* A cell at position J of F: [$]letters[$]digits not followed by a name character.  Returns "A1 nextJ" or "". */
::method cellAt
  use strict arg f, j
  n = f~length
  k = j
  if f~substr(k, 1) == '$' then k += 1
  ls = k
  do while k <= n
    if verify(f~substr(k, 1), xrange('A', 'Z') || xrange('a', 'z')) \== 0 then leave
    k += 1
  end
  letters = f~substr(ls, k - ls)
  if letters == '' then return ''
  if letters~length > 3 then return ''
  if f~substr(k, 1) == '$' then k += 1
  ds = k
  do while k <= n
    if verify(f~substr(k, 1), '0123456789') \== 0 then leave
    k += 1
  end
  digits = f~substr(ds, k - ds)
  if digits == '' then return ''
  if k <= n then if self~nameChar(f~substr(k, 1)) then return ''
  return (letters || digits)~upper k

/* After a cell at J: ":B9" gives "B9 nextJ"; nothing gives "- J" (a word, so PARSE keeps the position). */
::method rangeEnd
  use strict arg f, j
  if f~substr(j, 1) \== ':' then return '-' j
  parse value self~cellAt(f, j + 1) with cellB nextJ
  if cellB == '' then return '-' j
  return cellB nextJ

::method nameChar
  use strict arg ch
  return verify(ch, xrange('A', 'Z') || xrange('a', 'z') || '0123456789_.$') == 0

::method report
  expose name format sheetNames errors typed cellCount formulaCount
  out = .array~new
  roots = 0
  do e over errors
    if e['ROOT'] then roots += 1
  end
  out~append('piledriver workbook:' name)
  out~append('  format' format '  sheets' sheetNames~items '(' || sheetNames~makeString('L', ', ') || ')  cells' cellCount '  formulas' formulaCount)
  out~append('  error cells' errors~items '  roots' roots '  passed on' errors~items - roots '  typed error text' typed~items)
  if errors~items > 0 then do
    out~append('roots (where an error starts):')
    do e over errors
      if \e['ROOT'] then iterate
      out~append('  ' e['KEY']~left(14) e['VALUE']~left(9) e['HOW']~left(9) e['FORMULA'])
    end
    if errors~items > roots then do
      out~append('passed on (from -> back to the roots):')
      do e over errors
        if e['ROOT'] then iterate
        out~append('  ' e['KEY']~left(14) e['VALUE']~left(9) 'from' e['FROM']~makeString('L', ',')~left(12) 'roots' e['ROOTS']~makeString('L', ','))
      end
    end
  end
  if typed~items > 0 then do
    out~append('typed error text (no formula: a value someone wrote, not an error):')
    do t over typed
      out~append('  ' (t['SHEET'] || '!' || t['ADDRESS'])~left(14) t['VALUE'])
    end
  end
  return out
