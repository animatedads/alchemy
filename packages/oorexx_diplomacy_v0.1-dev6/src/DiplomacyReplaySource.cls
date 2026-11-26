/* Replays recorded player calls; never invokes a player or PRNG.
   The host must compare the complete regenerated journal byte-for-byte. */
::requires 'DiplomacyGame.cls'
::class DiplomacyReplaySource public
::attribute seed get
::attribute config get
::method init
  expose seed config calls cursor pressCalls pressCursor
  use strict arg path
  calls = .array~new
  cursor = 1
  pressCalls = .array~new
  pressCursor = 1
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot open replay journal')
  header = input~linein
  if header \== 'DIPLOG|1' & header \== 'DIPLOG|2' then raise syntax 93.900 array('Bad replay header')
  line = input~linein
  parse var line kind '|' seed '|' startYear '|' endYear '|' solo '|' rounds
  if kind \== 'META' then raise syntax 93.900 array('Missing replay meta')
  if header == 'DIPLOG|1' then rounds = 0
  config = .DiplomacyGameConfig~new(startYear,endYear,solo,rounds)
  if header == 'DIPLOG|2' then if rounds <= 0 then raise syntax 93.900 array('Missing press rounds')
  ended = .false
  do while input~lines > 0
    if ended then raise syntax 93.900 array('Trailing journal content')
    line = input~linein
    parse var line kind '|' body
    if kind == 'CALL' then do
      parse var body year '|' phase '|' power '|' status '|' count
      if \count~datatype('W') then raise syntax 93.900 array('Bad replay call count')
      if count < 0 then raise syntax 93.900 array('Bad replay call count')
      if status \== 'OK' then if count \= 0 then raise syntax 93.900 array('Failed call has orders')
      orders = .array~new
      do idx = 1 to count
        if input~lines = 0 then raise syntax 93.900 array('Truncated replay order')
        row = input~linein
        parse var row tag '|' hex
        if tag \== 'ORDER' then raise syntax 93.900 array('Missing replay order')
        if hex \== '' then do
          if \hex~datatype('X') then raise syntax 93.900 array('Invalid replay hex')
          if hex~length // 2 \= 0 then raise syntax 93.900 array('Invalid replay hex length')
        end
        orders~append(hex~x2c)
      end
      calls~append(.array~of(year,phase,power,status,orders))
    end
    else if kind == 'PRESS_CALL' then do
      parse var body year '|' phase '|' round '|' power '|' status '|' hex
      if \.array~of('OK','BAD_RESPONSE','ERROR','TIMEOUT')~hasItem(status) then raise syntax 93.900 array('Unknown press replay status')
      if hex \== '' then do
        if \hex~datatype('X') then raise syntax 93.900 array('Invalid press replay hex')
        if hex~length // 2 \= 0 then raise syntax 93.900 array('Invalid press replay hex length')
      end
      pressCalls~append(.array~of(year,phase,round,power,status,hex~x2c))
    end
    else if kind == 'ORDER' then raise syntax 93.900 array('Orphan replay order')
    else if kind == 'END' then ended = .true
    else if kind == 'ERROR' then raise syntax 93.900 array('Cannot replay a failed game')
  end
  input~close
  if \ended then raise syntax 93.900 array('Incomplete replay')
::method orders
  expose calls cursor
  use strict arg view
  if cursor > calls~items then raise syntax 93.900 array('Replay missing call')
  row = calls[cursor]
  if row[1] \== view['YEAR'] | row[2] \== view['PHASE'] | row[3] \== view['POWER'] then raise syntax 93.900 array('Replay call mismatch')
  cursor += 1
  return .array~of(row[4],row[5]~copy)
::method press
  expose pressCalls pressCursor
  use strict arg view
  if pressCursor > pressCalls~items then raise syntax 93.900 array('Replay missing press call')
  row = pressCalls[pressCursor]
  if row[1] \== view['YEAR'] | row[2] \== view['PHASE'] | row[3] \== view['ROUND'] | row[4] \== view['POWER'] then raise syntax 93.900 array('Replay press call mismatch')
  pressCursor += 1
  return .array~of(row[5],row[6])
::method complete
  expose cursor calls pressCalls pressCursor
  if cursor \= calls~items + 1 then raise syntax 93.900 array('Unconsumed replay calls')
  if pressCursor \= pressCalls~items + 1 then raise syntax 93.900 array('Unconsumed replay press calls')
::method module_version class
  return '0.1-dev6'
::method module_version
  return self~class~module_version
::method module_lastChanged class
  return '2026-11-26'
::method module_lastChanged
  return self~class~module_lastChanged

::routine diplomacySameJournal public
  use strict arg leftPath, rightPath
  lhs = .stream~new(leftPath)
  rhs = .stream~new(rightPath)
  if lhs~open('READ') \== 'READY:' then return .false
  if rhs~open('READ') \== 'READY:' then do
    lhs~close
    return .false
  end
  equal = .true
  do while lhs~chars > 0 | rhs~chars > 0
    if lhs~chars = 0 | rhs~chars = 0 then do
      equal = .false
      leave
    end
    if lhs~charin(,4096) \== rhs~charin(,4096) then do
      equal = .false
      leave
    end
  end
  lhs~close
  rhs~close
  return equal
