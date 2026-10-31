/* PiledriverTable.cls - Piledriver v0.1: read a delimited table; find its header, what each column is, and
 * where its errors are.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-30.
 * Reading: ooRexx's own csvStream.cls (shipped with ooRexx 5.3.0; quoted fields, any delimiter), so
 * Piledriver needs no other package to read a table.
 *
 * In a table an error is DATA, so free text is never searched for error words: "Unable to prosecute
 * suspect" in the police outcomes file is an outcome, not a failure.  Errors come from two places only:
 *   SHEET_ERROR  a cell holding a spreadsheet error literal: #DIV/0!, #N/A, #REF! ... or LibreOffice's Err:502.
 *                A sheet saved as CSV keeps these as text, and so does an ODS error cell read as a string.
 *   STATUS       a column that holds a status: a small set of values (at most 12, 4+ rows per value, 5+ rows)
 *                and either a name that says so (rc, status, code, result, outcome, state, level, severity),
 *                an OK value among its values (0, OK, SUCCESS, PASS), or level words (ERROR, WARN).
 *                Its error rows are the rows not at an OK value; with no OK value but level words, the
 *                ERROR/FATAL rows.  Ties between counts go to the first value in sorted order.
 * A UTF-8 byte order mark and blank lines are dropped before the header is taken.
 * The name and the counts are both asked, and both answers are shown:
 *   ID           the values differ in more than half the rows: an identifier, even when the name says "code"
 *                (lsoa_code: E01000001 ... 35,672 values in 35,672 rows).
 *   CONSTANT     one value in every row.
 *   CATEGORY     a small set with no status evidence.
 *   VALUE        anything else.
 */

::requires 'csvStream.cls'
::requires 'PiledriverWords.cls'
::requires 'PiledriverSource.cls'

::class PiledriverColumn public
::attribute name unguarded
::attribute index unguarded
::attribute filled unguarded
::attribute empty unguarded
::attribute kinds unguarded
::attribute values unguarded
::attribute overflow unguarded
::attribute role unguarded
::attribute evidence unguarded
::attribute okValues unguarded
::method init
  expose name index filled empty kinds values overflow role evidence okValues
  use strict arg name, index
  filled = 0; empty = 0
  kinds = .directory~new; values = .directory~new; overflow = .false
  role = ''; evidence = .array~new; okValues = .array~new
::method add
  expose filled empty kinds values overflow
  use strict arg v
  if v == '' then do
    empty += 1
    return
  end
  filled += 1
  k = .PiledriverTable~kindOf(v)
  if kinds~hasIndex(k) then kinds[k] = kinds[k] + 1
  else kinds[k] = 1
  if values~hasIndex(v) then values[v] = values[v] + 1
  else if values~items < 5000 then values[v] = 1
  else overflow = .true
::method mainKind
  expose kinds
  best = ''; n = 0
  do k over kinds~allIndexes~sort
    if kinds[k] > n then do
      best = k; n = kinds[k]
    end
  end
  return best
::method distinct
  expose values overflow
  if overflow then return '5000+'
  return values~items
::method top
  expose values
  best = ''; n = 0
  do v over values~allIndexes~sort
    if values[v] > n then do
      best = v; n = values[v]
    end
  end
  return .array~of(best, n)

::class PiledriverTable public
::attribute name unguarded
::attribute source unguarded
::attribute header unguarded
::attribute columns unguarded
::attribute rows unguarded
::attribute sheetErrors unguarded
::attribute errorRows unguarded

::method init
  expose columns rows sheetErrors errorRows
  columns = .array~new; rows = .array~new; sheetErrors = .array~new; errorRows = .array~new

::method kindOf class
  use strict arg v
  if .PiledriverWords~sheetError(v) then return 'SHEET_ERROR'
  if datatype(v, 'W') then return 'INT'
  if datatype(v, 'N') then return 'DEC'
  s = .PiledriverWords~shape(v)
  if s~left(7) == '9999-99' then return 'DATE'
  if s~left(10) == '99/99/9999' then return 'DATE'
  if s~left(5) == '99:99' then return 'TIME'
  if wordpos(v~upper, 'TRUE FALSE YES NO') > 0 then return 'BOOL'
  if .PiledriverWords~codeShaped(v) then return 'CODE'
  if .PiledriverWords~hexText(v) \== '' then return 'HEXTEXT'
  return 'TEXT'

/* A1 address of row R (1 is the first line of the file), column C. */
::method address class
  use strict arg r, c
  letters = ''
  n = c
  do while n > 0
    m = (n - 1) // 26
    letters = d2c(65 + m) || letters
    n = (n - 1 - m) % 26
  end
  return letters || r

::method readFile
  expose name source header columns rows
  use strict arg path
  name = path
  source = .PiledriverSource~sniff(path)
  d = source['DELIMITER']
  if d == '' then d = ','
  header = source['HEADER']
  if \.File~new(path)~exists then raise syntax 98.900 array('Piledriver cannot open' path)
  s = .CsvStream~new(path)
  s~delimiter = d
  s~open('read')        /* CsvStream~open returns no result (measured, ooRexx 5.3.0 csvStream.cls) */
  do while s~chars > 0
    row = s~csvLineIn
    if row == .nil then leave
    blank = .true
    do v over row
      if v \== .nil then if v~strip \== '' then blank = .false
    end
    if blank then iterate        /* a blank line is no row (the sniffer skips it too) */
    if rows~items == 0 then if row[1] \== .nil then if row[1]~left(3) == 'EFBBBF'x then row[1] = row[1]~substr(4)
    rows~append(row)
  end
  s~close
  self~profile
  return self

::method profile
  expose header columns rows sheetErrors errorRows
  width = 0
  do row over rows
    width = max(width, row~last)
  end
  start = 1
  do c = 1 to width
    colName = 'column' c
    if header then if rows~items > 0 then do
      v = rows[1][c]
      if v \== .nil then colName = v
    end
    columns~append(.PiledriverColumn~new(colName, c))
  end
  if header then start = 2
  do r = start to rows~items
    row = rows[r]
    do c = 1 to width
      v = row[c]
      if v == .nil then v = ''
      v = v~strip
      columns[c]~add(v)
      if v \== '' then if .PiledriverWords~sheetError(v) then sheetErrors~append(.array~of(.PiledriverTable~address(r, c), v, columns[c]~name))
    end
  end
  do col over columns
    self~decideRole(col)
  end
  do col over columns
    if col~role \== 'STATUS' then iterate
    do r = start to rows~items
      v = rows[r][col~index]
      if v == .nil then v = ''
      v = v~strip
      if v == '' then iterate
      bad = .false
      if col~okValues~items > 0 then bad = col~okValues~index(v~upper) == .nil
      else bad = wordpos(.PiledriverWords~level(v~upper), 'FATAL ERROR') > 0
      if bad then errorRows~append(.array~of(r, col~name, v))
    end
  end

::method decideRole
  use strict arg col
  ev = col~evidence
  n = col~filled
  dist = col~distinct
  nameWords = col~name~lower~translate('  ', '_-')~subWords
  nameSays = .false
  do w over nameWords
    if .PiledriverWords~isCodeKey(w) then nameSays = .true
    if wordpos(w, 'result outcome state level severity') > 0 then nameSays = .true
  end
  if nameSays then ev~append('the name says status or code')
  if n == 0 then do
    col~role = 'EMPTY'
    return
  end
  if dist == '5000+' then do
    col~role = 'ID'
    ev~append('more than 5000 values in' n 'rows')
    if nameSays then ev~append('the name and the values do not agree: the values decide')
    return
  end
  if n >= 5 then if dist == 1 then do
    col~role = 'CONSTANT'
    ev~append('one value in' n 'rows')
    return
  end
  if n >= 5 then if dist * 2 > n then if wordpos(col~mainKind, 'INT CODE TEXT HEXTEXT') > 0 then do
    col~role = 'ID'
    ev~append(dist 'values in' n 'rows: the values say identifier')
    if nameSays then ev~append('the name and the values do not agree: the values decide')
    return
  end
  small = .false
  if n >= 5 then if dist <= 12 then if dist * 4 <= n then small = .true
  if \small then do
    col~role = 'VALUE'
    return
  end
  ev~append(dist 'values in' n 'rows: a small set')
  oks = .array~new; levelWords = 0
  do v over col~values~allIndexes~sort
    if .PiledriverWords~okValue(col~name, v) then oks~append(v~upper)
    if .PiledriverWords~level(v~upper) \== '' then levelWords += 1
  end
  if oks~items > 0 then do
    col~role = 'STATUS'
    col~okValues = oks
    ev~append('OK value' oks~makeString('L', ',') 'is among the values: other rows are errors')
    return
  end
  if levelWords * 2 >= dist then do
    col~role = 'STATUS'
    ev~append('the values are level words: ERROR and FATAL rows are errors')
    return
  end
  if nameSays then do
    top = col~top
    col~role = 'STATUS'
    col~okValues = .array~of(top[1]~upper)
    ev~append('no OK value; the most used value,' top[1] || ', is taken as normal')
    return
  end
  col~role = 'CATEGORY'

::method report
  expose name source header columns rows sheetErrors errorRows
  use strict arg most = 10
  out = .array~new
  dataRows = rows~items
  if header then dataRows -= 1
  out~append('piledriver table:' name)
  yesNo = 'no'
  if header then yesNo = 'yes'
  out~append('  kind' source['KIND'] '  rows' dataRows '  columns' columns~items '  header' yesNo)
  do e over source['EVIDENCE']
    out~append('    ' e)
  end
  do col over columns
    text = '  ' || col~name~left(24) col~role~left(9) col~mainKind~left(11) 'distinct' col~distinct
    if col~evidence~items > 0 then text = text ' [' || col~evidence~makeString('L', '; ') || ']'
    out~append(text)
    if col~mainKind == 'HEXTEXT' then if col~role \== 'ID' then do
      decoded = .array~new
      do v over col~values~allIndexes~sort
        decoded~append(.PiledriverWords~hexText(v) || 'x' || col~values[v])
        if decoded~items >= 8 then leave
      end
      more = ''
      if col~values~items > 8 then more = '...'
      out~append('      hex-encoded text:' decoded~makeString('L', ' ') more)
    end
  end
  if sheetErrors~items > 0 then do
    out~append('sheet error values:' sheetErrors~items)
    do i = 1 to min(most, sheetErrors~items)
      e = sheetErrors[i]
      out~append('  ' e[1] e[2] '(' || e[3] || ')')
    end
  end
  if errorRows~items > 0 then do
    out~append('status error rows:' errorRows~items)
    do i = 1 to min(most, errorRows~items)
      e = errorRows[i]
      out~append('  row' e[1] e[2] || '=' || e[3])
    end
  end
  return out
