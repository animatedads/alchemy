/* Architecture Tom Dyer; implementation ChatGPT GPT-6.2.
   Authoritative retreat and winter resolution; no player legal-order API. */
::requires 'DiplomacyOrderParser.cls'

::class DiplomacySeasonResult public
::attribute units get
::attribute published get
::attribute removed get
::attribute outcomes get
::attribute automatic get
::method init
  expose units published removed outcomes automatic
  use strict arg units, published, removed, outcomes, automatic
::method module_version class
  return '0.1-dev4r1'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev4r1'
::method module_lastChanged
  return '2026-11-26'

::class DiplomacySeason public
::method init
  expose board parser
  use strict arg board
  parser = .DiplomacyOrderParser~new(board)
::method module_version class
  return '0.1-dev4r1'
::method module_lastChanged class
  return '2026-11-26'
::method module_version
  return '0.1-dev4r1'
::method module_lastChanged
  return '2026-11-26'
::method retreatOptions
  expose board
  use strict arg movement
  options = .directory~new
  do province over movement~dislodged~allIndexes~sort
    info = movement~dislodged[province]
    unit = info[1]
    choices = .array~new
    do dest over board~neighbours(unit~location,unit~unitType)
      destProvince = board~provinceOf(dest)
      if movement~units~hasIndex(destProvince) then iterate
      if movement~standoffs~hasIndex(destProvince) then iterate
      if destProvince == info[2] then if \info[3] then iterate
      choices~append(dest)
    end
    options[province] = choices
  end
  return options
::method retreats
  expose board parser
  use strict arg movement, submitted
  options = self~retreatOptions(movement)
  displaced = .directory~new
  selected = .directory~new
  records = .array~new
  destinations = .directory~new
  do province over movement~dislodged~allIndexes~sort
    displaced[province] = movement~dislodged[province][1]
  end
  do power over submitted~allIndexes~sort
    do order over parser~parseOrders(submitted[power],'RETREAT',power,displaced,options)
      records~append(.array~of(power,order))
      if \order~valid then iterate
      province = board~provinceOf(order~origin)
      selected[province] = order
      if order~action \== 'RETREAT' then iterate
      dest = board~provinceOf(order~resolvedDestination)
      if \destinations~hasIndex(dest) then destinations[dest] = 0
      destinations[dest] += 1
    end
  end
  nextUnits = movement~units~copy
  removed = .directory~new
  outcomes = .directory~new
  automatic = .array~new
  do province over displaced~allIndexes~sort
    unit = displaced[province]
    if selected~hasIndex(province) then do
      order = selected[province]
      if order~action == 'RETREAT' then do
        dest = board~provinceOf(order~resolvedDestination)
        if destinations[dest] = 1 then do
          nextUnits[dest] = .DiplomacyUnit~new(unit~owner,unit~unitType,order~resolvedDestination)
          outcomes[province] = 'SUCCEEDS'
          iterate
        end
        outcomes[province] = 'FAILS'
      end
      else outcomes[province] = 'SUCCEEDS'
    end
    else do
      outcomes[province] = 'FAILS'
      automatic~append(.array~of(unit~owner,unit~unitType,unit~location,'NO_VALID_RETREAT'))
    end
    removed[province] = unit
  end
  published = .array~new
  do entry over records
    order = entry[2]
    if order~valid then status = outcomes[board~provinceOf(order~origin)]
    else status = 'INVALID:'order~reason
    published~append(.array~of(entry[1],order~raw,status))
  end
  return .DiplomacySeasonResult~new(nextUnits,published,removed,outcomes,automatic)
::method initialOwnership
  expose board
  ownership = .directory~new
  do province over board~supplyCentres
    ownership[province] = board~node(province)['HOME']
  end
  return ownership
::method afterFallRetreats
  expose board
  use strict arg ownership, retreatState
  if \retreatState~isA(.DiplomacySeasonResult) then raise syntax 93.900 array('Fall ownership requires resolved retreat state')
  nextOwnership = ownership~copy
  do province over board~supplyCentres
    if \nextOwnership~hasIndex(province) then nextOwnership[province] = 'N'
    if retreatState~units~hasIndex(province) then nextOwnership[province] = retreatState~units[province]~owner
  end
  return nextOwnership
::method distanceMap
  expose board
  use strict arg ownership, power
  -- DATC v3 preferred distance: both land and sea, to any owned centre.
  -- Province graph merges coasts for distance only, not for actual moves.
  graph = .directory~new
  do province over board~provinceCodes
    graph[province] = .directory~new
  end
  do nodeCode over board~nodeCodes
    province = board~provinceOf(nodeCode)
    do unitType over .array~of('A','F')
      do neighbour over board~neighbours(nodeCode,unitType)
        dest = board~provinceOf(neighbour)
        graph[province][dest] = .true
        graph[dest][province] = .true
      end
    end
  end
  distances = .directory~new
  queue = .queue~new
  do province over ownership~allIndexes~sort
    if ownership[province] \== power then iterate
    if \graph~hasIndex(province) then iterate
    distances[province] = 0
    queue~queue(province)
  end
  do while queue~items > 0
    province = queue~pull
    do dest over graph[province]~allIndexes~sort
      if distances~hasIndex(dest) then iterate
      distances[dest] = distances[province] + 1
      queue~queue(dest)
    end
  end
  return distances
::method automaticChoice
  expose board
  use strict arg units, power, distances
  chosen = ''
  bestDistance = -1
  bestFleet = -1
  -- DATC 4.D.8: compare English province names, not codes, for the last tie.
  byName = .array~new
  do code over units~allIndexes
    byName~append(board~node(code)['NAME']~upper'|'code)
  end
  do entry over byName~sort
    parse var entry . '|' province
    unit = units[province]
    if unit~owner \== power then iterate
    distance = 999
    if distances~hasIndex(province) then distance = distances[province]
    isFleet = (unit~unitType == 'F')
    if distance > bestDistance | (distance = bestDistance & isFleet > bestFleet) then do
      chosen = province
      bestDistance = distance
      bestFleet = isFleet
    end
  end
  return chosen
::method adjustments
  expose board parser
  use strict arg units, ownership, submitted
  nextUnits = units~copy
  removed = .directory~new
  outcomes = .directory~new
  automatic = .array~new
  published = .array~new
  powers = .array~of('AUS','ENG','FRA','GER','ITA','RUS','TUR')
  do power over powers
    balance = 0
    do province over board~supplyCentres
      if ownership[province] == power then balance += 1
    end
    do province over units~allIndexes~sort
      if units[province]~owner == power then balance -= 1
    end
    lines = .array~new
    if submitted~hasIndex(power) then lines = submitted[power]
    do order over parser~parseOrders(lines,'ADJUSTMENT',power,units,.directory~new,ownership)
      status = 'FAILS'
      province = board~provinceOf(order~origin)
      if \order~valid then status = 'INVALID:'order~reason
      else select
        when order~action == 'BUILD' then do
          if balance > 0 then do
            if nextUnits~hasIndex(province) then status = 'INVALID:BAD_BUILD'
            else do
              nextUnits[province] = .DiplomacyUnit~new(power,order~unitType,order~resolvedDestination)
              balance -= 1
              status = 'SUCCEEDS'
              outcomes[province] = status
            end
          end
        end
        when order~action == 'WAIVE' then do
          if balance > 0 then do
            balance -= 1
            status = 'SUCCEEDS'
          end
        end
        when order~action == 'DISBAND' then do
          if balance < 0 then if nextUnits~hasIndex(province) then do
            removed[province] = nextUnits~remove(province)
            balance += 1
            status = 'SUCCEEDS'
            outcomes[province] = status
          end
        end
        otherwise nop
      end
      published~append(.array~of(power,order~raw,status))
    end
    if balance < 0 then do
      distances = self~distanceMap(ownership,power)
      do while balance < 0
        province = self~automaticChoice(nextUnits,power,distances)
        if province == '' then raise syntax 93.900 array('Insufficient units for mandatory disband:' power)
        unit = nextUnits~remove(province)
        removed[province] = unit
        automatic~append(.array~of(power,unit~unitType,unit~location,'CIVIL_DISORDER'))
        outcomes[province] = 'DISLODGED'
        balance += 1
      end
    end
  end
  return .DiplomacySeasonResult~new(nextUnits,published,removed,outcomes,automatic)
