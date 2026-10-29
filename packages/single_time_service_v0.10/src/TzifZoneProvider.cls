/* Read-only native ooRexx TZif v1-v4 provider, RFC 9636.
   POSIX future rules are captured but intentionally NOT expanded.
   Leap-second-bearing TZif data is rejected: the SingleTime core's POSIX
   instants are not a leap-aware timestamp format. */
::requires 'SingleTime.cls'

::class 'TzifZoneProvider' public
::method init
  expose root edition
  use strict arg root, edition = 'UNSPECIFIED'
  if root == '' then raise syntax 93.900 array ('explicit trusted tzdb root required')
  self~root = root
  self~edition = edition
::attribute root
::attribute edition

::method load
  expose root edition
  use strict arg identifier
  /* A zone identifier is not a filesystem path supplied by the caller. */
  if identifier == '' | left(identifier,1) == '/' | right(identifier,1) == '/' then raise syntax 93.900 array ('invalid zone identifier')
  if pos('\',identifier)>0 | pos(':',identifier)>0 | pos(x2c('00'),identifier)>0 then raise syntax 93.900 array ('invalid zone identifier')
  rest = identifier
  do while rest \== ''
    parse var rest part '/' rest
    if part == '' | part == '.' | part == '..' then raise syntax 93.900 array ('unsafe zone identifier')
    if verify(part,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-')>0 then raise syntax 93.900 array ('invalid zone identifier characters')
  end
  path = root
  if right(path,1) \== '/' then path = path || '/'
  return self~loadPath(path || identifier, identifier)

::method loadPath
  expose edition bytes cursor
  use strict arg fileName, identifier
  stream = .stream~new(fileName)
  if stream~open('read') \== 'READY:' then raise syntax 93.900 array ('unable to open TZif file' fileName)
  sz = stream~query('size')
  if \datatype(sz,'W') then do
    stream~close
    raise syntax 93.900 array ('cannot determine TZif byte size')
  end
  if sz < 44 | sz > 16777216 then do
    stream~close
    raise syntax 93.900 array ('TZif file outside size limit')
  end
  inputBytes = stream~charin(,sz)
  stream~close
  if length(inputBytes) \= sz then raise syntax 93.900 array ('truncated TZif read')
  return self~loadBytes(inputBytes,identifier,fileName)

/* Parse exactly the supplied bytes: callers can verify an immutable snapshot
 * first and avoid a second filesystem read between digest and TZif parsing. */
::method loadBytes
  expose edition bytes cursor
  use strict arg inputBytes, identifier, sourceName = 'IN_MEMORY'
  if inputBytes~length < 44 | inputBytes~length > 16777216 then raise syntax 93.900 array ('TZif bytes outside size limit')
  bytes = inputBytes
  cursor = 1
  h = self~readHeader
  select
    when h[1] == x2c('00') then do
      parsed = self~readBlock(h,4)
      tail = ''
    end
    when h[1] == '2' | h[1] == '3' | h[1] == '4' then do
      self~skipBlock(h,4)
      second = self~readHeader
      if second[1] \== h[1] then raise syntax 93.900 array ('TZif version mismatch')
      parsed = self~readBlock(second,8)
      rest = self~read(length(bytes)-cursor+1)
      if length(rest) < 2 | left(rest,1) \== x2c('0a') | right(rest,1) \== x2c('0a') then raise syntax 93.900 array ('TZif footer framing invalid')
      tail = substr(rest,2,length(rest)-2)
      if pos(x2c('0a'),tail) > 0 then raise syntax 93.900 array ('multiple TZif footer lines')
    end
    otherwise raise syntax 93.900 array ('unknown TZif version')
  end
  /* Parsed slots: [1] times, [2] indices, [3] offsets,
     [4] names, [5] leap count. Use type zero before first transition. */
  if parsed[5] \= 0 then raise syntax 93.900 array ('leap-aware TZif unsupported by POSIX instant model')
  changes = parsed[1]; typeIndices = parsed[2]
  offsets = parsed[3]; names = parsed[4]
  rules = .TimeZoneRules~new(identifier)
  rules~addPeriod(-9223372036854775809,offsets[1],names[1])
  do i = 1 to changes~items
    typ = typeIndices[i]
    rules~addPeriod(changes[i],offsets[typ],names[typ])
  end
  horizon = .nil
  /* A simple, fixed POSIX footer is sufficient authority for continuing
     the final offset indefinitely. Recurring DST tails are not yet
     evaluated and must not silently use their final recorded offset. */
  if tail \== '' then do
    finalType = 1
    if changes~items > 0 then finalType = typeIndices[typeIndices~items]
    if \self~isFixedTail(tail,offsets[finalType],names[finalType]) then do
      if changes~items = 0 then raise syntax 93.900 array ('unexpanded POSIX recurrence without transition table')
      horizon = changes[changes~items] + 1
    end
  end
  else do
    if changes~items > 0 then horizon = changes[changes~items] + 1
  end
  rules~setAuthority(edition,sourceName,tail,horizon)
  return rules

::method isFixedTail private
  use strict arg tail, expectedOffset, expectedAbbreviation
  numeric digits 30
  if pos(',',tail) > 0 | pos('/',tail) > 0 then return .false
  if left(tail,1) == '<' then do
    endName = pos('>',tail)
    if endName < 3 then return .false
    name = substr(tail,2,endName-2)
    rest = substr(tail,endName+1)
  end
  else do
    good = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    n=1
    do while n<=length(tail)
      if verify(substr(tail,n,1),good) \= 0 then leave
      n+=1
    end
    name=left(tail,n-1)
    rest=substr(tail,n)
    if length(name)<3 then return .false
  end
  if name \== expectedAbbreviation then return .false
  if rest=='' then return .false
  factor=-1
  select
    when left(rest,1)=='-' then do; factor=1; rest=substr(rest,2); end
    when left(rest,1)=='+' then rest=substr(rest,2)
    otherwise nop
  end
  if rest=='' then return .false
  if verify(rest,'0123456789:')>0 then return .false
  parse var rest hours ':' minutes ':' seconds ':' extra
  if extra \== '' then return .false
  if hours=='' | \datatype(hours,'W') then return .false
  if hours<0 | hours>24 then return .false
  if minutes=='' then minutes=0
  if seconds=='' then seconds=0
  if \datatype(minutes,'W') | \datatype(seconds,'W') then return .false
  if minutes<0 | minutes>59 | seconds<0 | seconds>59 then return .false
  return factor*(hours*3600+minutes*60+seconds) = expectedOffset

::method readHeader private
  head = self~read(44)
  if substr(head,1,4) \== 'TZif' then raise syntax 93.900 array ('missing TZif header')
  h = .array~new
  h[1] = substr(head,5,1)
  do j = 0 to 5
    h[j+2] = self~decodeNumber(substr(head,21+j*4,4),.false)
  end
  /* counts: isutcnt,isstdcnt,leapcnt,timecnt,typecnt,charcnt */
  if h[6] < 1 | h[7] < 1 | h[6] > 256 then raise syntax 93.900 array ('invalid TZif type or char count')
  if h[2] \= 0 & h[2] \= h[6] then raise syntax 93.900 array ('invalid isutcnt')
  if h[3] \= 0 & h[3] \= h[6] then raise syntax 93.900 array ('invalid isstdcnt')
  if h[5] > 1000000 | h[4] > 1000000 | h[7] > 1000000 then raise syntax 93.900 array ('oversize TZif counts')
  return h

::method skipBlock private
  use strict arg h, width
  total = h[5]*width + h[5] + h[6]*6 + h[7] + h[4]*(width+4) + h[3] + h[2]
  ignored = self~read(total)

::method readBlock private
  use strict arg h, width
  numeric digits 30
  changes = .array~new
  do j = 1 to h[5]
    changes~append(self~decodeNumber(self~read(width),.true))
    if j > 1 then do
      if changes[j] <= changes[j-1] then raise syntax 93.900 array ('unsorted TZif transitions')
    end
  end
  types = .array~new
  do j = 1 to h[5]
    t = self~decodeNumber(self~read(1),.false) + 1
    if t > h[6] then raise syntax 93.900 array ('TZif transition type out of range')
    types~append(t)
  end
  offsets = .array~new; nameOffsets = .array~new
  do j = 1 to h[6]
    offsets~append(self~decodeNumber(self~read(4),.true))
    dst = self~decodeNumber(self~read(1),.false)
    if dst > 1 then raise syntax 93.900 array ('invalid DST indicator')
    nameOffset = self~decodeNumber(self~read(1),.false)
    if nameOffset >= h[7] then raise syntax 93.900 array ('TZif designation index out of range')
    nameOffsets~append(nameOffset)
  end
  designations = self~read(h[7])
  names = .array~new
  do j = 1 to h[6]
    first = nameOffsets[j] + 1
    last = pos(x2c('00'),designations,first)
    if last == 0 then raise syntax 93.900 array ('unterminated TZif designation')
    names~append(substr(designations,first,last-first))
  end
  /* Deliberate POSIX-only restriction; do not reinterpret right/ data.
     Consume records to validate framing before rejecting leap-count >0. */
  ignored = self~read(h[4]*(width+4) + h[3] + h[2])
  return .array~of(changes,types,offsets,names,h[4])

::method read private
  expose bytes cursor
  use strict arg count
  if count < 0 | cursor+count-1 > length(bytes) then raise syntax 93.900 array ('TZif truncated or invalid count')
  result = substr(bytes,cursor,count)
  cursor += count
  return result

::method decodeNumber private
  use strict arg value, signed
  numeric digits 30
  result = 0
  do k = 1 to length(value)
    result = result*256 + c2d(substr(value,k,1))
  end
  if signed then do
    if c2d(substr(value,1,1)) >= 128 then result = result - 2**(8*length(value))
  end
  return result
