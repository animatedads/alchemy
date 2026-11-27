/* Randomised stress test for DiplomacyAdjudicator~movement.
   Review tooling by Claude (Opus 5.5). Architecture: Tom Dyer.
   Usage: rexx review/fuzz.rex positions seed
   Generates random legal-looking and illegal positions, resolves each, and checks
   invariants: no exception, unit conservation, insertion-order determinism,
   dislodged provinces reoccupied, successful movers at their destinations,
   successful movers never dislodged. Prints any failing position in fixture
   grammar so it can be pasted into a CASE. */
parse arg fzTotal fzSeed fzMode
if fzMode == '' then fzMode = 'MIXED'
fzMode = fzMode~upper
if fzTotal == '' then fzTotal = 500
if fzSeed == '' then fzSeed = 4711
call random 1, 2, fzSeed
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
powers = .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
armySpots = .array~new
fleetSpots = .array~new
do code over board~nodeCodes
  node = board~node(code)
  if node['KIND'] \== 'split' then if node['KIND'] \== 'sea' then if node['ARMY'] \== '' then armySpots~append(code)
  if node['FLEET'] \== '' then fleetSpots~append(code)
end
coastal = .array~new
do code over board~provinceCodes
  if board~node(code)['KIND'] == 'coast' then coastal~append(code)
end
if fzMode == 'CONVOY' then do
  /* Convoy-dense positions: armies only on coasts, fleets only at sea. */
  armySpots = coastal~copy
  seaSpots = .array~new
  do code over fleetSpots
    if board~node(code)['KIND'] == 'sea' then seaSpots~append(code)
  end
  fleetSpots = seaSpots
end
fzFailures = 0
fzStatus = .directory~new
fzParadox = 0
fzErrors = 0
fzChecks = 0
fzStarted = time('E')
do fzCase = 1 to fzTotal
  units = .directory~new
  target = random(6, 24)
  do attempt = 1 to 200 while units~items < target
    if random(1, 100) <= 50 then do
      spot = armySpots[random(1, armySpots~items)]
      kind = 'A'
    end
    else do
      spot = fleetSpots[random(1, fleetSpots~items)]
      kind = 'F'
    end
    province = board~provinceOf(spot)
    if units~hasIndex(province) then iterate
    units[province] = .DiplomacyUnit~new(powers[random(1, 7)], kind, spot)
  end
  /* Pass 1: holds and moves. */
  plan = .directory~new
  do province over units~allIndexes~sort
    unit = units[province]
    roll = random(1, 100)
    next = board~neighbours(unit~location, unit~unitType)
    if fzMode == 'CONVOY' then if unit~unitType == 'A' then roll = 90
    select
      when roll <= 15 | next~items = 0 then plan[province] = unit~unitType unit~location 'H'
      when roll <= 80 then plan[province] = unit~unitType unit~location '-' next[random(1, next~items)]
      otherwise do
        if unit~unitType == 'A' then plan[province] = 'A' unit~location '-' coastal[random(1, coastal~items)]
        else plan[province] = unit~unitType unit~location 'H'
      end
    end
  end
  /* Pass 2: some units become supporters or convoyers of others' planned orders. */
  others = units~allIndexes~sort
  do province over units~allIndexes~sort
    unit = units[province]
    supportShare = 40
    if fzMode == 'CONVOY' then supportShare = 70
    if random(1, 100) > supportShare then iterate
    pick = others[random(1, others~items)]
    if pick == province then iterate
    parse value plan[pick] with pType pLoc pVerb pDest
    if unit~unitType == 'F' then if board~node(unit~location)['KIND'] == 'sea' then if pType == 'A' then if pVerb == '-' then do
      plan[province] = 'F' unit~location 'C A' pLoc '-' pDest
      iterate
    end
    if pVerb == '-' then plan[province] = unit~unitType unit~location 'S' pType pLoc '-' pDest
    else plan[province] = unit~unitType unit~location 'S' pType pLoc
  end
  orders = .directory~new
  do province over units~allIndexes~sort
    owner = units[province]~owner
    if \orders~hasIndex(owner) then orders[owner] = .array~new
    orders[owner]~append(plan[province])
  end
  first = safeMovement(judge, units, orders)
  if \first~isA(.DiplomacyMovement) then do
    fzErrors += 1
    call report fzCase, 'EXCEPTION' first, units, orders
    iterate
  end
  if first~paradoxes~items > 0 then fzParadox += 1
  second = safeMovement(judge, reversed(units), reversedOrders(orders))
  problems = .array~new
  fzChecks += 1
  if \second~isA(.DiplomacyMovement) then problems~append('exception on reversed input:' second)
  else if fingerprint(first) \== fingerprint(second) then problems~append('insertion-order dependence')
  if first~units~items + first~dislodged~items \= units~items then problems~append('conservation')
  do province over first~dislodged~allIndexes~sort
    if \first~units~hasIndex(province) then problems~append('dislodged province empty:' province)
  end
  index = 0
  do power over orders~allIndexes~sort
    do line over orders[power]
      index += 1
      record = first~published[index]
      statusKey = record[3]~word(1)
      parse var statusKey statusKey ':' .
      if \fzStatus~hasIndex(statusKey) then fzStatus[statusKey] = 0
      fzStatus[statusKey] += 1
      if record[3] \== 'SUCCEEDS' then iterate
      parse var line oType oLoc oVerb oDest .
      if oVerb \== '-' then iterate
      dest = board~provinceOf(oDest)
      if \first~units~hasIndex(dest) then problems~append('mover missing at' dest)
      else if first~units[dest]~owner \== power then problems~append('wrong occupant at' dest)
      if first~dislodged~hasIndex(board~provinceOf(oLoc)) then if first~dislodged[board~provinceOf(oLoc)][1]~owner == power then if first~dislodged[board~provinceOf(oLoc)][1]~location == oLoc then problems~append('successful mover dislodged:' oLoc)
    end
  end
  if problems~items > 0 then do
    fzFailures += 1
    call report fzCase, problems~makeString('L', '; '), units, orders
  end
  if fzCase // 100 = 0 then say 'progress' fzCase'/'fzTotal 'errors' fzErrors 'failures' fzFailures 'elapsed' format(time('E') - fzStarted,,1)'s'
end
fzLine = 'Order statuses:'
do statusKey over fzStatus~allIndexes~sort
  fzLine = fzLine statusKey'='fzStatus[statusKey]
end
say fzLine
say 'Positions with a Szykman paradox:' fzParadox
say 'Fuzz positions:' fzTotal 'seed' fzSeed 'checked' fzChecks 'exceptions' fzErrors 'invariant failures' fzFailures
exit (fzErrors + fzFailures > 0)

report:
  use arg rpCase, rpWhat, rpUnits, rpOrders
  say 'FUZZ FAIL position' rpCase':' rpWhat
  say 'CASE FUZZ-'fzSeed'-'rpCase
  do rpProvince over rpUnits~allIndexes~sort
    say 'UNIT' rpUnits[rpProvince]~owner rpUnits[rpProvince]~unitType rpUnits[rpProvince]~location
  end
  do rpPower over rpOrders~allIndexes~sort
    do rpLine over rpOrders[rpPower]
      say 'ORDER' rpPower rpLine
    end
  end
  say 'END'
  return

::routine safeMovement
  use strict arg judge, units, orders
  signal on syntax name smTrapped
  return judge~movement(units, orders)
smTrapped:
  say 'Trapped: rc' rc 'sigl' sigl condition('C') condition('D')
  return 'SYNTAX' condition('O')['MESSAGE']

::routine reversed
  use strict arg entries
  out = .directory~new
  keyList = entries~allIndexes~sort
  do idx = keyList~items to 1 by -1
    out[keyList[idx]] = entries[keyList[idx]]
  end
  return out

::routine reversedOrders
  use strict arg entries
  out = .directory~new
  keyList = entries~allIndexes~sort
  do idx = keyList~items to 1 by -1
    out[keyList[idx]] = entries[keyList[idx]]~copy
  end
  return out

::routine fingerprint
  use strict arg movement
  buf = .mutablebuffer~new
  do province over movement~units~allIndexes~sort
    unit = movement~units[province]
    buf~append(province unit~owner unit~unitType unit~location';')
  end
  do province over movement~dislodged~allIndexes~sort
    buf~append('D' province movement~dislodged[province][2]';')
  end
  do record over movement~published
    buf~append(record~makeString('L','|')';')
  end
  return buf~string

::requires 'src/DiplomacyAdjudicator.cls'
