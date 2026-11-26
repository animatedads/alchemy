/* Architecture Tom Dyer; implementation ChatGPT GPT-6.2.
   Movement equations based on Lucas Kruijswijk, The Math of Adjudication,
   chapters 2 and 6. Referee only; no player interface.
   P=path, M=move, S=support, C=convoy availability. A trial uses explicit
   GUESSING decisions; both guesses are evaluated before cycle backup.
   An unresolved/non-conforming cycle fails closed, never publishes a guess. */
::requires 'DiplomacyOrderParser.cls'
::requires 'DiplomacySeason.cls'

::class DiplomacyMovement public
::attribute units get
::attribute dislodged get
::attribute outcomes get
::attribute standoffs get
::attribute paradoxes get
::attribute published get
::method init
  expose units dislodged outcomes standoffs paradoxes published
  use strict arg units, dislodged, outcomes, standoffs, paradoxes, published
::method module_version class
  return '0.1-dev4'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev4'
::method module_lastChanged
  return '2026-11-26'

::class DiplomacyAdjudicator public
::method init
  expose board rules
  use strict arg board, rulePath
  rules = .directory~new
  input = .stream~new(rulePath)
  if input~open('READ') \== 'READY:' then raise syntax 93.900 array('Cannot open rules:' rulePath)
  do while input~lines > 0
    line = input~linein~strip
    if line == '' then iterate
    if line~left(1) == '#' then iterate
    parse var line key '=' val
    if rules~hasIndex(key) then raise syntax 93.900 array('Duplicate rule:' key)
    rules[key] = val
  end
  input~close
  -- Do not silently run a different policy.
  expected = .array~of('RULEBOOK=2000','DATC_VERSION=3','CONVOY_PARADOX=SZYKMAN','MULTI_ROUTE_CONVOY=ALL_ROUTES_DISRUPTED','ADJACENT_ARMY_MOVE=LAND_UNLESS_VIA_CONVOY','COAST_REQUIRED=ALWAYS','SUPPORT_COAST=STRICT','WRONG_UNIT_TYPE=INVALID_HOLD','ABSENT_UNIT=IGNORE_AND_RECORD_INVALID','MISSING_ORDER=HOLD','PHYSICALLY_IMPOSSIBLE_CONVOY=INVALID_HOLD','DUPLICATE_ORDER=LAST_WINS','CIVIL_DISORDER=RULEBOOK_DISTANCE_THEN_FLEETS_THEN_ALPHABETICAL_NAME','BUILD=VACANT_OWNED_HOME','OWNERSHIP_UPDATE=AFTER_FALL_RETREATS','RETREAT_FROM_CONVOY_ATTACKER=ALLOWED','CIVIL_DISTANCE=OWNED_CENTRES_LAND_AND_SEA','ADJUSTMENT_EXCESS=FIRST_LEGAL')
  if rules~items \= expected~items then raise syntax 93.900 array('Unexpected rules count')
  do pair over expected
    parse var pair key '=' val
    if rules[key] \== val then raise syntax 93.900 array('Unsupported rule:' pair)
  end
::method ruleLines
  expose rules
  lines = .array~new
  do key over rules~allIndexes~sort
    lines~append(key'='rules[key])
  end
  return lines
::method retreatOptions
  expose board
  use strict arg movement
  return .DiplomacySeason~new(board)~retreatOptions(movement)
::method retreats
  expose board
  use strict arg movement, submitted
  return .DiplomacySeason~new(board)~retreats(movement,submitted)
::method adjustments
  expose board
  use strict arg units, ownership, submitted
  return .DiplomacySeason~new(board)~adjustments(units,ownership,submitted)
::method initialOwnership
  expose board
  return .DiplomacySeason~new(board)~initialOwnership
::method afterFallRetreats
  expose board
  use strict arg ownership, retreatState
  return .DiplomacySeason~new(board)~afterFallRetreats(ownership,retreatState)
::method movement
  expose board
  use strict arg units, submitted
  -- A new calculation per phase; never mutate the caller's units/orders.
  return .DiplomacyMovementCalculation~new(board,units,submitted)~run
::method module_version class
  return '0.1-dev4r3'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev4r3'
::method module_lastChanged
  return '2026-11-26'

::class DiplomacyMovementCalculation public
::method init
  expose board units submitted keys orders incoming moveSupports holdSupports convoyFleets convoyMoves cache forced paradoxes records matched
  use strict arg board, units, submitted
  keys = units~allIndexes~sort
  orders = .directory~new
  incoming = .directory~new
  moveSupports = .directory~new
  holdSupports = .directory~new
  convoyFleets = .directory~new
  convoyMoves = .directory~new
  cache = .directory~new
  forced = .directory~new
  paradoxes = .array~new
  records = .array~new
  matched = .directory~new
  parser = .DiplomacyOrderParser~new(board)
  do province over keys
    unit = units[province]
    if board~provinceOf(unit~location) \== province then raise syntax 93.900 array('Unit key mismatch:' province)
    orders[province] = parser~parseOrder(unit~unitType unit~location 'H')
    incoming[province] = .array~new
    moveSupports[province] = .array~new
    holdSupports[province] = .array~new
    convoyFleets[province] = .array~new
  end
  -- submitted is a power -> raw lines directory, not a trusted order object.
  do power over submitted~allIndexes~sort
    do order over parser~parseOrders(submitted[power],'MOVEMENT',power,units)
      records~append(.array~of(power,order))
      if \order~valid then iterate
      orders[board~provinceOf(order~origin)] = order
    end
  end
  -- DATC 4.E.1 / 6.D.32: a nonexistent physical convoy route is
  -- illegal; an existing fleet route with absent orders is a failed move.
  seaFleets = .array~new
  do province over keys
    if units[province]~unitType == 'F' then if board~node(province)['KIND'] == 'sea' then seaFleets~append(province)
  end
  do province over keys
    order = orders[province]
    if order~action \== 'MOVE' then iterate
    if order~unitType \== 'A' then iterate
    dest = board~provinceOf(order~resolvedDestination)
    if \order~viaConvoy then if board~adjacent(province,dest,'A') then iterate
    if self~route(province,seaFleets) then iterate
    order~reason = 'BAD_CONVOY'
    unit = units[province]
    orders[province] = parser~parseOrder(unit~unitType unit~location 'H')
  end
  do province over keys
    order = orders[province]
    if order~action \== 'MOVE' then iterate
    dest = board~provinceOf(order~resolvedDestination)
    if \incoming~hasIndex(dest) then incoming[dest] = .array~new
    incoming[dest]~append(province)
    if order~unitType == 'A' then do
      if order~viaConvoy | \board~adjacent(province,dest,'A') then convoyMoves[province] = .true
    end
  end
  do province over keys
    order = orders[province]
    if wordpos(order~action,'SUPPORT_MOVE SUPPORT_HOLD CONVOY') = 0 then iterate
    target = board~provinceOf(order~targetOrigin)
    targetOrder = orders[target]
    if order~action == 'SUPPORT_HOLD' then do
      if targetOrder~action \== 'MOVE' then do
        holdSupports[target]~append(province)
        matched[province] = .true
      end
      iterate
    end
    if targetOrder~action \== 'MOVE' then iterate
    if order~destination \== targetOrder~resolvedDestination then iterate
    if order~action == 'SUPPORT_MOVE' then do
      moveSupports[target]~append(province)
      matched[province] = .true
    end
    else if convoyMoves~hasIndex(target) then do
      convoyFleets[target]~append(province)
      matched[province] = .true
    end
  end
::method module_version class
  return '0.1-dev4r3'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev4r3'
::method module_lastChanged
  return '2026-11-26'

::method headToHead
  expose board orders units convoyMoves
  use strict arg province
  order = orders[province]
  if order~action \== 'MOVE' then return ''
  if convoyMoves~hasIndex(province) then return ''
  dest = board~provinceOf(order~resolvedDestination)
  if \units~hasIndex(dest) then return ''
  other = orders[dest]
  if other~action \== 'MOVE' then return ''
  if convoyMoves~hasIndex(dest) then return ''
  if board~provinceOf(other~resolvedDestination) == province then return dest
  return ''

/* Every equation is side-effect free except the resolver's dependency bookkeeping. */
::method equation
  expose board units orders incoming convoyMoves convoyFleets holdSupports matched
  use strict arg decision, trial
  parse var decision kind ':' province
  order = orders[province]
  select
    when kind == 'P' then do
      if \convoyMoves~hasIndex(province) then return .true
      if \self~route(province,convoyFleets[province]) then return .false
      available = .array~new
      do fleet over convoyFleets[province]
        if trial~query('C:'fleet) then available~append(fleet)
      end
      return self~route(province,available)
    end
    when kind == 'C' then do
      if \matched~hasIndex(province) then return .false
      do attacker over incoming[province]
        if trial~query('M:'attacker) then return .false
      end
      return .true
    end
    when kind == 'S' then do
      if \matched~hasIndex(province) then return .false
      target = board~provinceOf(order~targetOrigin)
      if order~action == 'SUPPORT_MOVE' then exception = board~provinceOf(order~destination)
      else exception = target
      do attacker over incoming[province]
        if units[attacker]~owner == units[province]~owner then iterate
        if attacker == exception then do
          if trial~query('M:'attacker) then return .false
        end
        else if trial~query('P:'attacker) then return .false
      end
      return .true
    end
    when kind == 'M' then do
      if \trial~query('P:'province) then return .false
      dest = board~provinceOf(order~resolvedDestination)
      opposing = self~headToHead(province)
      defender = ''
      resistance = 0
      if units~hasIndex(dest) then do
        if opposing \== '' then do
          defender = units[dest]~owner
          resistance = self~strength(dest,trial,'')
        end
        else if orders[dest]~action == 'MOVE' then do
          if \trial~query('M:'dest) then do
            defender = units[dest]~owner
            resistance = 1
          end
        end
        else do
          defender = units[dest]~owner
          resistance = 1
          do supporter over holdSupports[dest]
            if trial~query('S:'supporter) then resistance += 1
          end
        end
      end
      if defender == units[province]~owner then return .false
      power = self~strength(province,trial,defender)
      if power <= resistance then return .false
      do competitor over incoming[dest]
        if competitor == province then iterate
        if \trial~query('P:'competitor) then iterate
        other = self~headToHead(competitor)
        if other \== '' then do
          if trial~query('M:'other) then iterate
        end
        if power <= self~strength(competitor,trial,'') then return .false
      end
      return .true
    end
    otherwise raise syntax 93.900 array('Unknown decision:' decision)
  end
::method strength
  expose moveSupports units
  use strict arg province, trial, excluded
  total = 1
  do supporter over moveSupports[province]
    if units[supporter]~owner == excluded then iterate
    if trial~query('S:'supporter) then total += 1
  end
  return total
::method route
  expose board orders
  use strict arg province, available
  dest = board~provinceOf(orders[province]~resolvedDestination)
  openList = .queue~new
  visited = .directory~new
  do fleet over available
    if self~touches(fleet,province) then do
      openList~queue(fleet)
      visited[fleet] = .true
    end
  end
  do while openList~items > 0
    fleet = openList~pull
    if self~touches(fleet,dest) then return .true
    do neighbour over available
      if visited~hasIndex(neighbour) then iterate
      if board~adjacent(fleet,neighbour,'F') then do
        openList~queue(neighbour)
        visited[neighbour] = .true
      end
    end
  end
  return .false
::method touches
  expose board
  use strict arg fleet, province
  do nodeCode over board~neighbours(fleet,'F')
    if board~provinceOf(nodeCode) == province then return .true
  end
  return .false

/* Trial-based Kruijswijk guessing. A query encountering an active decision
   records a cycle and reads an explicit guess. Evaluate both values, reject
   inconsistent guesses, and only apply backup to ambiguous cycles. */
::method resolve
  expose cache forced paradoxes convoyMoves
  use strict arg decision
  if forced~hasIndex(decision) then return forced[decision]
  if cache~hasIndex(decision) then return cache[decision]
  do attempt = 1 to 35
    pending = .queue~new
    pending~queue(.directory~new)
    solutions = .array~new
    seenSolutions = .directory~new
    involved = .directory~new
    trials = 0
    do while pending~items > 0
      guesses = pending~pull
      trials += 1
      if trials > 4096 then raise syntax 93.900 array('Movement cycle search limit:' decision)
      trial = .DiplomacyGuessTrial~new(self,cache,forced,guesses)
      answer = trial~query(decision)
      if trial~missing~items > 0 then do
        guessKey = trial~missing~allIndexes~sort[1]
        low = guesses~copy
        high = guesses~copy
        low[guessKey] = .false
        high[guessKey] = .true
        pending~queue(low)
        pending~queue(high)
      end
      else do
        consistent = .true
        do guessKey over guesses~allIndexes~sort
          if \trial~values~hasIndex(guessKey) then iterate
          if trial~values[guessKey] \== guesses[guessKey] then consistent = .false
        end
        do cycleKey over trial~cycles~allIndexes~sort
          involved[cycleKey] = .true
        end
        if consistent then do
          signature = ''
          do decisionKey over trial~values~allIndexes~sort
            signature = signature decisionKey'='trial~values[decisionKey]
          end
          if \seenSolutions~hasIndex(signature) then do
            seenSolutions[signature] = .true
            solutions~append(trial~values)
          end
        end
      end
    end
    if solutions~items = 1 then do
      values = solutions[1]
      do decisionKey over values~allIndexes~sort
        cache[decisionKey] = values[decisionKey]
      end
      return cache[decision]
    end
    -- Multiple trials can have identical root values but different temporary
    -- decisions. Resolve the actual cycle rather than commit either trial.
    changed = .false
    do cycleKey over involved~allIndexes~sort
      parse var cycleKey kind ':' province
      if kind \== 'P' then iterate
      if \convoyMoves~hasIndex(province) then iterate
      if forced~hasIndex(cycleKey) then iterate
      forced[cycleKey] = .false
      paradoxes~append(cycleKey)
      changed = .true
    end
    if changed then do
      cache = .directory~new
      iterate
    end
    -- A pure circular movement has two consistent resolutions. Prefer
    -- the one in which every member of the cycle moves. If no such solution
    -- exists, refuse to publish an arbitrary board.
    if solutions~items > 1 then do
      do values over solutions
        preferred = .true
        do cycleKey over involved~allIndexes~sort
          if cycleKey~left(2) \== 'M:' then iterate
          if \values~hasIndex(cycleKey) then do
            preferred = .false
            leave
          end
          if \values[cycleKey] then preferred = .false
        end
        if preferred then do
          do decisionKey over values~allIndexes~sort
            cache[decisionKey] = values[decisionKey]
          end
          return cache[decision]
        end
      end
    end
    raise syntax 93.900 array('Unresolved movement dependency:' decision)
  end
  raise syntax 93.900 array('Movement backup limit:' decision)

::method run
  expose board units keys orders incoming cache forced paradoxes records convoyMoves
  -- Stabilise after backup invalidates previous cached calculations.
  do pass = 1 to 35
    before = forced~items
    do province over keys
      order = orders[province]
      select
        when order~action == 'MOVE' then do
          answer = self~resolve('M:'province)
          answer = self~resolve('P:'province)
        end
        when wordpos(order~action,'SUPPORT_MOVE SUPPORT_HOLD') > 0 then answer = self~resolve('S:'province)
        when order~action == 'CONVOY' then answer = self~resolve('C:'province)
        otherwise nop
      end
    end
    if forced~items = before then leave
  end
  if pass > 35 then raise syntax 93.900 array('Movement did not stabilise')
  -- Verify every cached, non-overridden equation against the final decisions.
  -- No temporary trial/guess may escape to the returned movement state.
  verification = .DiplomacyGuessTrial~new(self,cache,forced,.directory~new)
  do decisionKey over cache~allIndexes~sort
    if forced~hasIndex(decisionKey) then iterate
    if self~equation(decisionKey,verification) \== cache[decisionKey] then raise syntax 93.900 array('Inconsistent final decision:' decisionKey)
  end
  if verification~missing~items > 0 then raise syntax 93.900 array('Unresolved final dependency')
  nextUnits = .directory~new
  dislodged = .directory~new
  outcomes = .directory~new
  standoffs = .directory~new
  do province over keys
    order = orders[province]
    unit = units[province]
    if order~action == 'MOVE' then do
      if self~resolve('M:'province) then do
        dest = board~provinceOf(order~resolvedDestination)
        if nextUnits~hasIndex(dest) then raise syntax 93.900 array('Double occupation:' dest)
        nextUnits[dest] = .DiplomacyUnit~new(unit~owner,unit~unitType,order~resolvedDestination)
        outcomes[province] = 'SUCCEEDS'
        iterate
      end
      outcomes[province] = 'FAILS'
    end
    else if wordpos(order~action,'SUPPORT_MOVE SUPPORT_HOLD') > 0 then do
      if self~resolve('S:'province) then outcomes[province] = 'SUCCEEDS'
      else outcomes[province] = 'FAILS'
    end
    else if order~action == 'CONVOY' then do
      if self~resolve('C:'province) then outcomes[province] = 'SUCCEEDS'
      else outcomes[province] = 'FAILS'
    end
    else outcomes[province] = 'SUCCEEDS'
    do attacker over incoming[province]
      if self~resolve('M:'attacker) then do
        dislodged[province] = .array~of(unit,attacker,convoyMoves~hasIndex(attacker))
        outcomes[province] = 'DISLODGED'
        leave
      end
    end
    if dislodged~hasIndex(province) then iterate
    if nextUnits~hasIndex(province) then raise syntax 93.900 array('Double occupation:' province)
    nextUnits[province] = unit
  end
  -- Standoff classification: an empty province with a tie of highest
  -- preventing strengths. A failed single attack is not a standoff.
  do dest over incoming~allIndexes~sort
    if nextUnits~hasIndex(dest) then iterate
    best = 0
    tied = 0
    trial = .DiplomacyGuessTrial~new(self,cache,forced,.directory~new)
    do attacker over incoming[dest]
      if \self~resolve('P:'attacker) then iterate
      opposing = self~headToHead(attacker)
      if opposing \== '' then if self~resolve('M:'opposing) then iterate
      power = self~strength(attacker,trial,'')
      if power > best then do
        best = power
        tied = 1
      end
      else if power = best then tied += 1
    end
    if tied > 1 then standoffs[dest] = .true
  end
  published = .array~new
  do entry over records
    order = entry[2]
    if order~valid then status = outcomes[board~provinceOf(order~origin)]
    else status = 'INVALID:'order~reason
    published~append(.array~of(entry[1],order~raw,status))
  end
  return .DiplomacyMovement~new(nextUnits,dislodged,outcomes,standoffs,paradoxes~copy,published)

::class DiplomacyGuessTrial public
::attribute values get
::attribute missing get
::attribute cycles get
::method init
  expose calculation cache forced guesses states values missing cycles stack
  use strict arg calculation, cache, forced, guesses
  states = .directory~new
  values = .directory~new
  missing = .directory~new
  cycles = .directory~new
  stack = .array~new
::method query
  expose calculation cache forced guesses states values missing cycles stack
  use strict arg decision
  if forced~hasIndex(decision) then return forced[decision]
  if cache~hasIndex(decision) then return cache[decision]
  if states[decision] == 'RESOLVED' then return values[decision]
  if states[decision] == 'GUESSING' then do
    start = stack~index(decision)
    do i = start to stack~items
      cycles[stack[i]] = .true
    end
    if guesses~hasIndex(decision) then return guesses[decision]
    missing[decision] = .true
    return .false
  end
  states[decision] = 'GUESSING'
  stack~append(decision)
  answer = calculation~equation(decision,self)
  stack~delete(stack~items)
  states[decision] = 'RESOLVED'
  values[decision] = answer
  return answer
::method module_version class
  return '0.1-dev4'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev4'
::method module_lastChanged
  return '2026-11-26'
