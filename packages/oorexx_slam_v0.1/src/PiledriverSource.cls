/* PiledriverSource.cls - Piledriver v0.1: what kind of file is this?  Asked once, before any line is judged.
 *
 * Architecture: Tom Dyer.  Code: Claude (Opus 5.5), 2026-10-30.
 *
 * An error means a different thing in each kind of file, so the kind comes first:
 *   XLSX, ODS     a zip package: the error is a value TYPE in a cell (#DIV/0!), and it spreads by formula.
 *                 Read with oorexx_spreadsheet_intentions (SpreadsheetReader).
 *   CSV, TSV, DELIMITED   a table: the error is DATA in a column (a status column, a sheet-error literal).
 *                 Read with PiledriverTable (ooRexx's own csvStream.cls).
 *   LOG           lines that say what a program did: the error is an EVENT.  Read with PiledriverLog.
 *                 PREFIXED when one line in five has a time stamp.
 *   JSON, JSONL   structured: read with ooRexx's json.cls.
 *   BINARY, ZIP, EMPTY   not read.
 *
 * The evidence for the answer is returned with it:
 *   ~sniff(path) -> directory KIND, DELIMITER, HEADER (.true/.false), PREFIXED, EVIDENCE (array of strings)
 */

::requires 'PiledriverWords.cls'

::class PiledriverSource public

::method sniff class
  use strict arg path
  out = .directory~new
  out['KIND'] = 'EMPTY'; out['DELIMITER'] = ''; out['HEADER'] = .false; out['PREFIXED'] = .false
  ev = .array~new
  out['EVIDENCE'] = ev
  s = .stream~new(path)
  if s~open('read') \== 'READY:' then do
    out['KIND'] = 'MISSING'
    ev~append('cannot open')
    return out
  end
  size = s~chars
  head = s~charin(1, min(size, 65536))
  s~close
  if size == 0 then return out
  if head~left(4) == 'PK' || '0304'x then do
    if head~pos('mimetypeapplication/vnd.oasis.opendocument.spreadsheet') > 0 then do
      out['KIND'] = 'ODS'
      ev~append('zip package; mimetype says ODF spreadsheet')
    end
    else if head~pos('xl/workbook.xml') > 0 | head~pos('xl/worksheets/') > 0 then do
      out['KIND'] = 'XLSX'
      ev~append('zip package; holds xl/ parts')
    end
    else do
      out['KIND'] = 'ZIP'
      ev~append('zip package; not a spreadsheet I know')
    end
    return out
  end
  if head~left(3) == 'EFBBBF'x then head = head~substr(4)
  if head~pos('00'x) > 0 then do
    out['KIND'] = 'BINARY'
    ev~append('a NUL byte in the first' head~length 'bytes')
    return out
  end
  /* the sample: up to 200 non-blank lines, the last one cut off when the head was cut */
  text = head~changeStr('0d0a'x, '0a'x)
  sample = .array~new
  do line over text~makeArray('0a'x)
    if line~strip \== '' then sample~append(line)
    if sample~items >= 200 then leave
  end
  if size > 65536 then if sample~items > 1 then sample~delete(sample~items)
  if sample~items == 0 then return out
  first = sample[1]~strip~left(1)
  if first == '{' | first == '[' then do
    jsonl = sample~items >= 2
    do line over sample
      if line~strip~left(1) \== '{' | line~strip~right(1) \== '}' then jsonl = .false
    end
    if jsonl then do
      out['KIND'] = 'JSONL'
      ev~append(sample~items 'lines, each one object')
      return out
    end
    if \self~looksLogged(sample) then do
      out['KIND'] = 'JSON'
      ev~append('starts with' first)
      return out
    end
  end
  stamped = 0
  do line over sample
    if .PiledriverWords~timestampWords(line~subWords) > 0 then stamped += 1
  end
  best = ''; bestShare = 0; bestFields = 0
  do d over .array~of(',', '09'x, ';', '|')
    counts = .directory~new
    do line over sample
      f = self~fieldCount(line, d)
      if counts~hasIndex(f) then counts[f] = counts[f] + 1
      else counts[f] = 1
    end
    mode = 0; modeCount = 0
    do f over counts
      if counts[f] > modeCount then do
        mode = f; modeCount = counts[f]
      end
    end
    if mode < 2 then iterate
    share = modeCount / sample~items
    if share > bestShare then do
      best = d; bestShare = share; bestFields = mode
    end
  end
  delimited = .false
  if best \== '' then if sample~items >= 2 then if bestShare >= 0.9 then delimited = .true
  names = .directory~new; names[',' ] = 'comma'; names['09'x] = 'tab'; names[';'] = 'semicolon'; names['|'] = 'bar'
  if delimited then do
    header = self~headerLike(sample, best)
    ev~append(format(bestShare * 100, , 0) || '% of' sample~items 'lines have' bestFields 'fields by' names[best])
    if header then ev~append('line 1 is a header: every field is text, none repeats in the lines below')
    else ev~append('line 1 is not a header')
    out['DELIMITER'] = best
    out['HEADER'] = header
    if header | stamped * 2 < sample~items then do
      if best == ',' then out['KIND'] = 'CSV'
      else if best == '09'x then out['KIND'] = 'TSV'
      else out['KIND'] = 'DELIMITED'
      return out
    end
  end
  out['KIND'] = 'LOG'
  out['PREFIXED'] = stamped * 5 >= sample~items
  ev~append(stamped 'of' sample~items 'lines start with a time stamp')
  if \delimited then ev~append('no delimiter gives the same field count on 90% of lines')
  return out

/* "[0] ...", "[INFO] ...": lines that open with a bracket but are a log, not JSON: a level or a stamp, or a
   bracketed tag with words after it (not a comma, as in a JSON array of arrays). */
::method looksLogged class
  use strict arg sample
  hits = 0
  do line over sample
    w = line~strip~word(1)
    s = line~strip
    if .PiledriverWords~level(w) \== '' then hits += 1
    else if .PiledriverWords~timestampWords(line~subWords) > 0 then hits += 1
    else if s~left(1) == '[' then if s~pos(']') > 2 then if s~substr(s~pos(']') + 1)~strip \== '' then if s~substr(s~pos(']') + 1)~strip~left(1) \== ',' then hits += 1
  end
  return hits * 2 >= sample~items

/* Fields in LINE by D, with "quoted, fields" kept whole. */
::method fieldCount class
  use strict arg line, d
  n = 1; inQuote = .false
  do i = 1 to line~length
    c = line~substr(i, 1)
    if c == '"' then inQuote = \inQuote
    else if c == d then if \inQuote then n += 1
  end
  return n

/* A header: every field of line 1 is non-empty text (no number), the fields differ, and none of them
   appears again in its column in the sample. */
::method headerLike class
  use strict arg sample, d
  if sample~items < 2 then return .false
  first = self~fields(sample[1], d)
  seenNames = .directory~new
  do f over first
    v = f~strip
    if v == '' then return .false
    if datatype(v, 'N') then return .false
    if seenNames~hasIndex(v) then return .false
    seenNames[v] = .true
  end
  do i = 2 to sample~items
    row = self~fields(sample[i], d)
    do j = 1 to min(row~items, first~items)
      if row[j]~strip == first[j]~strip then return .false
    end
  end
  return .true

::method fields class
  use strict arg line, d
  out = .array~new; cur = ''; inQuote = .false
  do i = 1 to line~length
    c = line~substr(i, 1)
    if c == '"' then do
      inQuote = \inQuote
      iterate
    end
    if c == d then if \inQuote then do
      out~append(cur)
      cur = ''
      iterate
    end
    cur = cur || c
  end
  out~append(cur)
  return out
