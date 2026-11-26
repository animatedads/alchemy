/* Data-driven movement test runner. Fixtures are deliberately separate from code. */
parse arg path expectedCases
if path == '' then path = 'data/movement-fixtures.txt'
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
caseId = ''
caseIds = .directory~new
do while input~lines > 0
  line = input~linein~strip
  if line == '' then iterate
  if line~left(1) == '#' then iterate
  parse var line command payload
  select
    when command == 'CASE' then do
      if caseId \== '' then exit 2
      caseId = payload
      if caseIds~hasIndex(caseId) then exit 2
      caseIds[caseId] = .true
      units = .directory~new
      orders = .directory~new
      expected = .array~new
    end
    when command == 'UNIT' then do
      parse var payload power unitType location
      province = board~provinceOf(location)
      if units~hasIndex(province) then exit 2
      units[province] = .DiplomacyUnit~new(power,unitType,location)
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
    otherwise do
      say 'Bad fixture command:' command
      exit 2
    end
  end
end
input~close
if caseId \== '' | cases = 0 then exit 2
if expectedCases \== '' then if cases \= expectedCases then exit 2
say 'Movement cases:' cases 'Checks:' checks 'Failures:' failures
exit (failures > 0)

runCase:
  resolution = judge~movement(units,orders)
  -- Insertion-order independence: reconstruct every input in reverse key order.
  otherUnits = .directory~new
  otherOrders = .directory~new
  keyList = units~allIndexes~sort
  do idx = keyList~items to 1 by -1
    otherUnits[keyList[idx]] = units[keyList[idx]]
  end
  keyList = orders~allIndexes~sort
  do idx = keyList~items to 1 by -1
    otherOrders[keyList[idx]] = orders[keyList[idx]]~copy
  end
  repeated = judge~movement(otherUnits,otherOrders)
  call check fingerprint(resolution) == fingerprint(repeated), 'replay'
  call check resolution~units~items + resolution~dislodged~items = units~items, 'conservation'
  do assertion over expected
    parse var assertion kind province wanted
    select
      when kind == 'AT' then do
        actual = '-'
        if resolution~units~hasIndex(province) then do
          unit = resolution~units[province]
          actual = unit~owner unit~unitType unit~location
        end
        call check actual == wanted, assertion 'actual:' actual
      end
      when kind == 'OUTCOME' then call check resolution~outcomes[province] == wanted, assertion 'actual:' resolution~outcomes[province]
      when kind == 'DISLODGED' then do
        actual = '-'
        if resolution~dislodged~hasIndex(province) then actual = resolution~dislodged[province][2]
        call check actual == wanted, assertion 'actual:' actual
      end
      when kind == 'RETREAT_OPTIONS' then do
        options = judge~retreatOptions(resolution)
        actual = '-'
        if options~hasIndex(province) then do
          choices = options[province]~copy~sort
          if choices~items > 0 then actual = choices~makeString('L',' ')
        end
        call check options~hasIndex(province), assertion 'not dislodged'
        call check actual == wanted, assertion 'actual:' actual
      end
      when kind == 'STANDOFF' then call check resolution~standoffs~hasIndex(province) == wanted, assertion
      when kind == 'PARADOX' then call check resolution~paradoxes~hasItem('P:'province) == wanted, assertion
      when kind == 'SUCCESS' then call check (resolution~published[province][3] == 'SUCCEEDS') == wanted, assertion 'actual:' resolution~published[province][3]
      when kind == 'PUBLISHED' then call check resolution~published[province][3] == wanted, assertion 'actual:' resolution~published[province][3]
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
::routine fingerprint
  use strict arg movement
  buf = .mutablebuffer~new
  do province over movement~units~allIndexes~sort
    unit = movement~units[province]
    buf~append(province unit~owner unit~unitType unit~location';')
  end
  do province over movement~dislodged~allIndexes~sort
    buf~append('D' province movement~dislodged[province][2] movement~dislodged[province][3]';')
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
::requires 'src/DiplomacyAdjudicator.cls'
