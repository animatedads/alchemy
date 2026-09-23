/* AudioV9Tsv.cls
 * dev9: Audio V9 TSV boundary on top of stock ooRexx CSVStream.
 * TSV records are arrays. Adjacent TABs retain empty fields; callers never
 * parse a TSV record with LINEIN/PARSE/MAKEARRAY.
 */
::options numeric inherit

::class AudioV9TsvReader public
::method init
  expose csv path header closed hasHeader
  use strict arg pathValue,expectedHeader=.nil,hasHeaderValue=.true
  path=pathValue~string; closed=.false; hasHeader=hasHeaderValue
  csv=.CsvStream~new(path,.false)
  csv~delimiter='09'x
  csv~open('read')
  if csv~state<>'READY' then raise syntax 88.900 array('cannot open TSV for read',path,csv~description)
  header=.nil
  if hasHeader then do
    if csv~chars>0 then header=self~readRow
    if header==.nil then raise syntax 88.900 array('TSV has no header',path)
    if csv~state='ERROR' then raise syntax 88.900 array('invalid TSV header',path,csv~lastDataError)
    if expectedHeader\==.nil then self~requireHeader(expectedHeader)
  end
  else if expectedHeader\==.nil then raise syntax 88.900 array('cannot require header on headerless TSV',path)
::method path
  expose path
  return path
::method header
  expose header
  if header==.nil then return .nil
  return header~copy
::method requireHeader
  expose header path
  use strict arg expected
  if \expected~isA(.Array) then raise syntax 88.900 array('expected TSV header must be Array',path)
  if header~items<>expected~items then raise syntax 88.900 array('unexpected TSV header width',path,header~items,expected~items)
  do i=1 to expected~items
    if header[i]\==expected[i] then raise syntax 88.900 array('unexpected TSV header field',path,i,header[i],expected[i])
  end
  return .true
::method next
  expose csv path closed
  if closed then return .nil
  if csv~chars<=0 then return .nil
  row=self~readRow
  if csv~state='ERROR' then raise syntax 88.900 array('invalid TSV data',path,csv~lastDataError)
  return row
::method readRow private
  expose csv
  row=csv~csvLineIn
  /* Stock r13196 CSVStream omits the final empty field when a record ends
     in a delimiter.  Keep CSVStream as the parser, but restore that one
     structural field from rawText so TSV trailing empties remain arrays. */
  raw=csv~rawText
  if raw~length>0 then if raw~right(1)=='09'x then row~append('')
  return row
::method close
  expose csv closed
  if \closed then do; csv~close; closed=.true; end
  return 0
::method uninit
  expose csv closed
  if symbol('CLOSED')='VAR' then if \closed then csv~close

::class AudioV9TsvWriter public
::method init
  expose csv path closed
  use strict arg pathValue,header=.nil
  path=pathValue~string; closed=.false
  csv=.CsvStream~new(path,.false)
  csv~delimiter='09'x
  csv~open('write replace')
  if csv~state<>'READY' then raise syntax 88.900 array('cannot open TSV for write',path,csv~description)
  if header\==.nil then self~write(header)
::method write
  expose csv path closed
  use strict arg row
  if closed then raise syntax 88.900 array('TSV writer is closed',path)
  if \row~isA(.Array) then raise syntax 88.900 array('TSV row must be Array',path)
  csv~csvLineOut(row)
  if csv~state='ERROR' then raise syntax 88.900 array('cannot write TSV row',path,csv~lastDataError)
  return row~items
::method close
  expose csv closed
  if \closed then do; csv~close; closed=.true; end
  return 0
::method uninit
  expose csv closed
  if symbol('CLOSED')='VAR' then if \closed then csv~close

::requires 'csvStream.cls'
