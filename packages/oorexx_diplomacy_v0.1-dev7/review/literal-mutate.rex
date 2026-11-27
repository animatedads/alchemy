/* Test-only qualification harness for a supplied, unchanged referee release.
   Architecture: Tom Dyer. Test author: ChatGPT GPT-6.2.
   Deterministic mutations of the release's own fixture corpus. */
parse arg count seed mode fixture prefix
if \count~datatype('W') then exit 2
if count < 1 then exit 2
if \seed~datatype('W') then exit 2
if wordpos(mode,'MIXED CONVOY') = 0 then exit 2
randomSeed = random(0,999,seed)
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
say 'Audit seed:' seed 'positions:' count 'mode:' mode
do rule over judge~ruleLines
  say rule
end
cases = .array~new
paths = .array~of('data/datc-v3-movement.txt','data/movement-fixtures.txt','review/datc-v3.4-additions-movement.txt','review/datc-v3.4-strict-support-coast.txt','review/datc-v3.4-sixth-order.txt')
if fixture \== '' then paths = .array~of(fixture)
say 'Fixture filter:' fixture prefix
do path over paths
  input = .stream~new(path)
  if input~open('READ') \== 'READY:' then exit 2
  caseId = ''
  do while input~lines > 0
    line = input~linein~strip
    parse var line command payload
    select
      when command == 'CASE' then do
        caseId = payload
        units = .directory~new
        orders = .directory~new
        convoyCount = 0
      end
      when command == 'UNIT' then do
        parse var payload power unitType location
        units[board~provinceOf(location)] = .DiplomacyUnit~new(power,unitType,location)
      end
      when command == 'ORDER' then do
        parse var payload power raw
        if \orders~hasIndex(power) then orders[power] = .array~new
        orders[power]~append(raw)
        if wordpos('C',raw) > 0 then convoyCount += 1
      end
      when command == 'END' then do
        if prefix == '' | caseId~left(prefix~length) == prefix then do
          if mode == 'MIXED' | convoyCount > 0 then cases~append(.array~of(caseId,units,orders))
        end
        caseId = ''
      end
      otherwise nop
    end
  end
  input~close
  if caseId \== '' then exit 2
end
if cases~items = 0 then exit 2
say 'Source fixture count:' cases~items
paradoxCases = 0
do trialIndex = 1 to count
  selected = cases[random(1,cases~items)]
  units = selected[2]
  orders = .directory~new
  do power over selected[3]~allIndexes~sort
    orders[power] = .array~new
    do raw over selected[3][power]
      action = random(1,12)
      if action = 1 then iterate
      if action = 2 then do
        orders[power]~append(raw~lower)
        iterate
      end
      if action = 3 then do
        orders[power]~append(raw)
        orders[power]~append(raw)
        iterate
      end
      orders[power]~append(raw)
    end
  end
  -- Exercise last-order semantics with deterministic insertion of a hold or invalid line.
  if random(1,4) = 1 then do
    provinces = units~allIndexes~sort
    unit = units[provinces[random(1,provinces~items)]]
    power = unit~owner
    if \orders~hasIndex(power) then orders[power] = .array~new
    orders[power]~append(unit~unitType unit~location 'H')
  end
  if random(1,5) = 1 then do
    powers = orders~allIndexes~sort
    if powers~items > 0 then orders[powers[random(1,powers~items)]]~append('INVALID TEST LINE')
  end
  before = inputFingerprint(units,orders)
  movement = judge~movement(units,orders)
  otherUnits = reverseDirectory(units,.false)
  otherOrders = reverseDirectory(orders,.true)
  repeated = judge~movement(otherUnits,otherOrders)
  call verify inputFingerprint(units,orders) == before,'immutable'
  call verify fingerprint(movement) == fingerprint(repeated),'reverse insertion replay'
  call verify movement~units~items + movement~dislodged~items = units~items,'conservation'
  call verify totals(units,.directory~new) == totals(movement~units,movement~dislodged),'owner and type conservation'
  do province over movement~units~allIndexes~sort
    call verify board~provinceOf(movement~units[province]~location) == province,'occupancy key'
  end
  do province over movement~dislodged~allIndexes~sort
    call verify movement~units~hasIndex(province),'dislodged province reoccupied'
    call verify units~hasIndex(province),'original displaced unit present'
    entry = movement~dislodged[province]
    attacker = entry[2]
    call verify units~hasIndex(attacker),'attacker origin exists'
    call verify movement~units[province]~owner == units[attacker]~owner,'attacker owner'
    call verify movement~units[province]~unitType == units[attacker]~unitType,'attacker type'
    call verify movement~units[province]~owner \== entry[1]~owner,'no self dislodgement'
  end
  if movement~paradoxes~items > 0 then paradoxCases += 1
  if trialIndex // 500 = 0 then say 'Completed:' trialIndex
end
say 'PASS positions:' count 'failures: 0 paradox positions:' paradoxCases
exit 0

verify:
  use strict arg good, detail
  if good then return
  say 'FAIL' trialIndex 'source:' selected[1] detail
  say before
  exit 1

::routine reverseDirectory
  use strict arg entries, copyArrays
  out = .directory~new
  keyList = entries~allIndexes~sort
  do idx = keyList~items to 1 by -1
    key = keyList[idx]
    if copyArrays then out[key] = entries[key]~copy
    else out[key] = entries[key]
  end
  return out
::routine inputFingerprint
  use strict arg units, orders
  buf = .mutablebuffer~new
  do province over units~allIndexes~sort
    unit = units[province]
    buf~append(province unit~owner unit~unitType unit~location';')
  end
  do power over orders~allIndexes~sort
    do raw over orders[power]
      buf~append(power raw';')
    end
  end
  return buf~string
::routine fingerprint
  use strict arg movement
  buf = .mutablebuffer~new
  do province over movement~units~allIndexes~sort
    unit = movement~units[province]
    buf~append(province unit~owner unit~unitType unit~location';')
  end
  do province over movement~dislodged~allIndexes~sort
    entry = movement~dislodged[province]
    unit = entry[1]
    buf~append('D' province unit~owner unit~unitType unit~location entry[2] entry[3]';')
  end
  do province over movement~outcomes~allIndexes~sort
    buf~append('O' province movement~outcomes[province]';')
  end
  do province over movement~standoffs~allIndexes~sort
    buf~append('S' province';')
  end
  do nodeKey over movement~paradoxes
    buf~append('P' nodeKey';')
  end
  do record over movement~published
    buf~append(record~makeString('L','|')';')
  end
  return buf~string
::routine totals
  use strict arg units, displaced
  counts = .directory~new
  do unit over units~allItems
    key = unit~owner unit~unitType
    if \counts~hasIndex(key) then counts[key] = 0
    counts[key] += 1
  end
  do entry over displaced~allItems
    unit = entry[1]
    key = unit~owner unit~unitType
    if \counts~hasIndex(key) then counts[key] = 0
    counts[key] += 1
  end
  buf = .mutablebuffer~new
  do key over counts~allIndexes~sort
    buf~append(key counts[key]';')
  end
  return buf~string
::requires 'DiplomacyAdjudicator.cls'
