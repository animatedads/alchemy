/* Test-only random-position exercise of the existing referee.
   Architecture: Tom Dyer. Test author: ChatGPT GPT-6.2.
   No player legal-order interface. This is not Claude's fuzz.rex. */
parse arg count seed mode
if \count~datatype('W') then exit 2
if count < 1 then exit 2
if \seed~datatype('W') then exit 2
if wordpos(mode,'MIXED CONVOY') = 0 then exit 2
randomSeed = random(0,999,seed)
board = .DiplomacyBoard~new('data/standard.source')
judge = .DiplomacyAdjudicator~new(board,'data/rules.conf')
powers = .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
provinces = board~provinceCodes
seas = .array~new
coasts = .array~new
allNodes = board~nodeCodes
armyEdges = .directory~new
fleetEdges = .directory~new
fleetProvinces = .directory~new
fleetPlaces = .directory~new
do code over provinces
  if board~node(code)['KIND'] == 'sea' then seas~append(code)
  if board~node(code)['KIND'] == 'coast' then coasts~append(code)
  fleetPlaces[code] = .array~new
end
do code over allNodes
  armyEdges[code] = board~neighbours(code,'A')
  fleetEdges[code] = board~neighbours(code,'F')
  q = .directory~new
  do dest over fleetEdges[code]
    q[board~provinceOf(dest)] = 1
  end
  fleetProvinces[code] = q
  if fleetEdges[code]~items > 0 then fleetPlaces[board~provinceOf(code)]~append(code)
end
-- Seed each convoy-dense position from a known one- or two-sea route.
-- Construct these only as test inputs from the board adjacency graph.
routes = .array~new
do sea over seas
  do first over fleetEdges[sea]
    origin = board~provinceOf(first)
    if \coasts~hasItem(origin) then iterate
    do last over fleetEdges[sea]
      dest = board~provinceOf(last)
      if \coasts~hasItem(dest) | dest == origin then iterate
      if armyEdges[origin]~hasItem(dest) then iterate
      routes~append(.array~of(origin,dest,sea))
    end
    do second over fleetEdges[sea]
      if \seas~hasItem(second) then iterate
      do last over fleetEdges[second]
        dest = board~provinceOf(last)
        if \coasts~hasItem(dest) | dest == origin then iterate
        if armyEdges[origin]~hasItem(dest) then iterate
        routes~append(.array~of(origin,dest,sea,second))
      end
    end
  end
end
say 'Random-position seed:' seed 'positions:' count 'mode:' mode 'route seeds:' routes~items
do rule over judge~ruleLines
  say rule
end
paradoxCases = 0
convoyPositions = 0
dislodgements = 0
do trialIndex = 1 to count
  units = .directory~new
  fixed = .directory~new
  chosen = .directory~new
  targets = .directory~new
  if mode == 'CONVOY' then do
    route = routes[random(1,routes~items)]
    owner = powers[random(1,powers~items)]
    units[route[1]] = .DiplomacyUnit~new(owner,'A',route[1])
    fixed[route[1]] = 'A' route[1] '-' route[2]
    targets[route[1]] = route[2]
    do i = 3 to route~items
      loc = route[i]
      units[loc] = .DiplomacyUnit~new(powers[random(1,powers~items)],'F',loc)
      fixed[loc] = 'F' loc 'C A' route[1] '-' route[2]
    end
  end
  quota = random(8,32)
  do while units~items < quota
    if mode == 'CONVOY' & random(1,2) == 1 then code = seas[random(1,seas~items)]
    else code = provinces[random(1,provinces~items)]
    if units~hasIndex(code) then iterate
    kind = board~node(code)['KIND']
    typ = 'A'
    loc = code
    if kind == 'sea' | (fleetPlaces[code]~items > 0 & random(1,2) == 1) then do
      typ = 'F'
      loc = fleetPlaces[code][random(1,fleetPlaces[code]~items)]
    end
    units[code] = .DiplomacyUnit~new(powers[random(1,powers~items)],typ,loc)
  end
  keys = units~allIndexes~sort
  do code over keys
    if fixed~hasIndex(code) then do
      chosen[code] = fixed[code]
      iterate
    end
    unit = units[code]
    loc = unit~location
    typ = unit~unitType
    if typ == 'A' then neighbours = armyEdges[loc]
    else neighbours = fleetEdges[loc]
    chosen[code] = typ loc 'H'
    if neighbours~items > 0 then if random(1,10) <= 6 then do
      dest = neighbours[random(1,neighbours~items)]
      chosen[code] = typ loc '-' dest
      targets[code] = dest
    end
  end
  -- Hold candidates may support a genuinely generated move or another hold.
  -- All calculations below are input construction, never oracle decisions.
  do code over keys
    if fixed~hasIndex(code) | targets~hasIndex(code) then iterate
    if random(1,4) == 1 then iterate
    unit = units[code]
    loc = unit~location
    opts = .array~new
    do other over keys
      if other == code then iterate
      assisted = units[other]
      goal = other
      suffix = ''
      if targets~hasIndex(other) then do
        goal = board~provinceOf(targets[other])
        suffix = '-' targets[other]
      end
      reaches = .false
      if unit~unitType == 'A' then reaches = armyEdges[loc]~hasItem(goal)
      else reaches = fleetProvinces[loc]~hasIndex(goal)
      if reaches then opts~append((unit~unitType loc 'S' assisted~unitType assisted~location suffix)~strip)
    end
    if opts~items > 0 then chosen[code] = opts[random(1,opts~items)]
  end
  orders = .directory~new
  do code over keys
    unit = units[code]
    owner = unit~owner
    if \orders~hasIndex(owner) then orders[owner] = .array~new
    -- Missing/duplicate/bad inputs on a small percentage of non-seed orders.
    if \fixed~hasIndex(code) then do
      action = random(1,35)
      if action == 1 then iterate
      if action == 2 then orders[owner]~append(unit~unitType unit~location 'H')
      if action == 3 then orders[owner]~append('INVALID TEST LINE')
    end
    orders[owner]~append(chosen[code])
  end
  before = inputFingerprint(units,orders)
  movement = judge~movement(units,orders)
  repeated = judge~movement(reverseDirectory(units,.false),reverseDirectory(orders,.true))
  call verify inputFingerprint(units,orders) == before,'immutable'
  call verify fingerprint(movement) == fingerprint(repeated),'reverse insertion replay'
  call verify movement~units~items + movement~dislodged~items = units~items,'conservation'
  call verify totals(units,.directory~new) == totals(movement~units,movement~dislodged),'owner and type conservation'
  do province over movement~units~allIndexes~sort
    call verify board~provinceOf(movement~units[province]~location) == province,'occupancy key'
  end
  do province over movement~dislodged~allIndexes~sort
    call verify movement~units~hasIndex(province),'dislodged reoccupied'
    entry = movement~dislodged[province]
    attacker = entry[2]
    call verify units~hasIndex(attacker),'attacker exists'
    call verify movement~units[province]~owner == units[attacker]~owner,'attacker owner'
    call verify movement~units[province]~unitType == units[attacker]~unitType,'attacker type'
    call verify movement~units[province]~owner \== entry[1]~owner,'no self dislodgement'
  end
  do record over movement~published
    if record[3] \== 'SUCCEEDS' then iterate
    raw = record[2]
    parse var raw typ loc verb dest .
    if verb \== '-' then iterate
    province = board~provinceOf(loc)
    goal = board~provinceOf(dest)
    call verify \movement~dislodged~hasIndex(province),'successful mover not dislodged'
    call verify movement~units~hasIndex(goal),'successful mover destination occupied'
    call verify movement~units[goal]~owner == record[1],'successful mover owner'
    call verify movement~units[goal]~location == dest,'successful mover exact location'
  end
  dislodgements += movement~dislodged~items
  if movement~paradoxes~items > 0 then paradoxCases += 1
  if mode == 'CONVOY' then convoyPositions += 1
  if trialIndex // 500 = 0 then say 'Completed:' trialIndex
end
say 'PASS positions:' count 'failures: 0 paradox positions:' paradoxCases 'seeded convoy positions:' convoyPositions 'dislodgements:' dislodgements
exit 0
verify:
  use strict arg good, detail
  if good then return
  say 'FAIL' trialIndex detail
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
