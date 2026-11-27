/* Native retreat/adjustment data runner; no LLM or external adjudication. */
parse arg path expectedCases
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
say 'Rules:'
do line over judge~ruleLines
  say line
end
input = .stream~new(path)
if input~open('READ') \== 'READY:' then exit 2
cases = 0
checks = 0
failures = 0
caseId = 'INITIAL'
initial = judge~initialOwnership
call check initial~items = 34,'initial ownership size'
call check initial['BEL'] == 'N','initial neutral'
call check initial['STP'] == 'RUS','initial Russian centre'
call check initial['LON'] == 'ENG','initial English centre'
caseId = ''
seen = .directory~new
do while input~lines > 0
  line = input~linein~strip
  if line == '' then iterate
  if line~left(1) == '#' then iterate
  parse var line command payload
  select
    when command == 'CASE' then do
      if caseId \== '' then exit 2
      parse var payload caseId phase
      if seen~hasIndex(caseId) then exit 2
      seen[caseId] = .true
      units = .directory~new
      ownership = .directory~new
      moves = .directory~new
      orders = .directory~new
      expected = .array~new
    end
    when command == 'UNIT' then do
      parse var payload power unitType location
      province = board~provinceOf(location)
      if units~hasIndex(province) then exit 2
      units[province] = .DiplomacyUnit~new(power,unitType,location)
    end
    when command == 'OWN' then do
      parse var payload province power
      ownership[province] = power
    end
    when command == 'MOVE' then do
      parse var payload power raw
      if \moves~hasIndex(power) then moves[power] = .array~new
      moves[power]~append(raw)
    end
    when command == 'ORDER' then do
      parse var payload power raw
      if \orders~hasIndex(power) then orders[power] = .array~new
      orders[power]~append(raw)
    end
    when command == 'EXPECT' then expected~append(payload)
    when command == 'END' then do
      if expected~items = 0 then exit 2
      call runCase
      caseId = ''
      cases += 1
    end
    otherwise exit 2
  end
end
input~close
if caseId \== '' | cases = 0 then exit 2
if cases \= expectedCases then exit 2
say 'Season cases:' cases 'Checks:' checks 'Failures:' failures
exit (failures > 0)
runCase:
  baseline = unitFingerprint(units)
  otherUnits = reversed(units)
  otherOrders = reversed(orders)
  otherOwnership = reversed(ownership)
  select
    when phase == 'RETREAT' then do
      movement = judge~movement(units,moves)
      resolution = judge~retreats(movement,orders)
      repeated = judge~retreats(judge~movement(otherUnits,reversed(moves)),otherOrders)
      call check resolution~units~items + resolution~removed~items = units~items,'conservation'
      nextOwnership = judge~afterFallRetreats(ownership,resolution)
      call check nextOwnership~items = 34,'34 centres'
    end
    when phase == 'ADJUSTMENT' then do
      resolution = judge~adjustments(units,ownership,orders)
      repeated = judge~adjustments(otherUnits,otherOwnership,otherOrders)
      do power over .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
        balance = 0
        do province over ownership~allIndexes~sort
          if ownership[province] == power then balance += 1
        end
        do province over resolution~units~allIndexes~sort
          if resolution~units[province]~owner == power then balance -= 1
        end
        call check balance >= 0,'adjustment quota' power
      end
    end
    otherwise exit 2
  end
  call check fingerprint(resolution) == fingerprint(repeated),'replay'
  call check unitFingerprint(units) == baseline,'input immutable'
  do assertion over expected
    parse var assertion kind province wanted
    select
      when kind == 'AT' then do
        actual = '-'
        if resolution~units~hasIndex(province) then do
          unit = resolution~units[province]
          actual = unit~owner unit~unitType unit~location
        end
        call check actual == wanted,assertion 'actual:' actual
      end
      when kind == 'REMOVED' then call check resolution~removed~hasIndex(province),assertion
      when kind == 'PUB' then call check resolution~published[province][3] == wanted,assertion 'actual:' resolution~published[province][3]
      when kind == 'COUNT' then call check resolution~units~items = province,assertion 'actual:' resolution~units~items
      when kind == 'AUTOCOUNT' then call check resolution~automatic~items = province,assertion
      when kind == 'OWN' then call check nextOwnership[province] == wanted,assertion
      otherwise exit 2
    end
  end
  say caseId 'complete'
  return
check:
  parse arg good, detail
  checks += 1
  if \good then do
    failures += 1
    say 'FAIL' caseId detail
  end
  return
::routine reversed
  use strict arg entries
  out = .directory~new
  keyList = entries~allIndexes~sort
  do idx = keyList~items to 1 by -1
    out[keyList[idx]] = entries[keyList[idx]]
  end
  return out
::routine unitFingerprint
  use strict arg entries
  buf = .mutablebuffer~new
  do province over entries~allIndexes~sort
    unit = entries[province]
    buf~append(province unit~owner unit~unitType unit~location';')
  end
  return buf~string
::routine fingerprint
  use strict arg resolution
  buf = .mutablebuffer~new
  buf~append(unitFingerprint(resolution~units))
  buf~append(unitFingerprint(resolution~removed))
  do entry over resolution~published
    buf~append(entry~makeString('L','|')';')
  end
  do entry over resolution~automatic
    buf~append(entry~makeString('L','|')';')
  end
  do province over resolution~outcomes~allIndexes~sort
    buf~append(province resolution~outcomes[province]';')
  end
  return buf~string
::requires 'src/DiplomacyAdjudicator.cls'
